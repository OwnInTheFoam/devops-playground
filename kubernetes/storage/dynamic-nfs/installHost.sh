#!/bin/bash
# chmod u+x install.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
nfsVer=4.0.17
# VARIABLE DEFINES
logFile="${HOME}/nfs/install.log"
#logFile="/dev/null"
networkIPAddress=192.168.0.0
hostIPAddress=192.168.0.215

mkdir -p /${HOME}/nfs

echo "[TASK] Firewall allow local IP for nfs"
ufw allow from ${networkIPAddress}/24 >>${logFile} 2>&1

echo "[TASK] Install NFS server on Host"
apt update >>${logFile} 2>&1
apt -y install nfs-kernel-server >>${logFile} 2>&1

echo "[TASK] Create share directory"
mkdir -p /srv/nfs/kubedata
chown nobody:nogroup /srv/nfs/kubedata >>${logFile} 2>&1

echo "[TASK] Configure NFS exports"
cat >>/etc/exports<<EOF
/srv/nfs/kubedata     *(rw,sync,no_subtree_check,no_root_squash,no_all_squash)
EOF

echo "[TASK] Restart NFS server"
systemctl restart nfs-kernel-server >>${logFile} 2>&1
systemctl enable --now nfs-kernel-server >>${logFile} 2>&1
exportfs -rav >>${logFile} 2>&1

read -p "[INPUT] Please run installClient.sh on other nodes then press any key to continue... " -n1 -s
echo ""

echo "[TASK] Apply RBAC manifest"
cat >/${HOME}/nfs/rbac.yaml<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl apply -f /${HOME}/nfs/rbac.yaml >>${logFile} 2>&1

echo "[TASK] Apply StorageClass manifest"
cat >/${HOME}/nfs/storage-class.yaml<<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
EOF
kubectl apply -f /${HOME}/nfs/storage-class.yaml >>${logFile} 2>&1

echo "[TASK] Apply Deployment manifest"
cat >/${HOME}/nfs/deployment.yaml<<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: ${hostIPAddress} # change to server ip
            - name: NFS_PATH
              value: /srv/nfs/kubedata # change to nfs directory
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${hostIPAddress} # change to server ip
            path: /srv/nfs/kubedata # change to nfs directory
EOF
kubectl apply -f /${HOME}/nfs/deployment.yaml >>${logFile} 2>&1

echo "[TASK] Test persistant volume claim"
cat >/${HOME}/nfs/example-pvc.yaml<<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs-pv1
spec:
  storageClassName: managed-nfs-storage # if default then no need to specify
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
EOF
kubectl apply -f /${HOME}/nfs/example-pvc.yaml >>${logFile} 2>&1

echo "[TASK] Wait for pvc bound..."
# Wait for a metallb-system pod named controller
# kubectl get pods --selector "app.kubernetes.io/name=" --output=name
while [[ $(kubectl get pvc -o=name | grep pvc-nfs-pv1) == "" ]]; do
   sleep 1
done
# Wait for nfs pvc to be Bound
while [[ $(kubectl get $(kubectl get pvc -o=name | grep pvc-nfs-pv1) -o 'jsonpath={..status.phase}') != "Bound" ]]; do
   sleep 1
done
#ls /srv/nfs/kubedata
#read -p "[INPUT] Please check above contains a valid pvc then press any key to continue... " -n1 -s
#echo ""
kubectl delete -f /${HOME}/nfs/example-pvc.yaml >>${logFile} 2>&1

echo "COMPLETE"
