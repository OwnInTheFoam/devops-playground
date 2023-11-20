# Longhorn

## Requirements
- containerd v1.3.7+
- Kubernetes >= v1.21
- open-iscsi is installed on all the nodes. `apt-get install open-iscsi`
- Each node has a NFSv4 client installed.
- The host filesystem supports ext4 or XFS `apt-get install nfs-common`
- bash, curl, findmnt, grep, awk, blkid, lsblk must be installed.
- Mount propagation must be enabled.

To ensure longhorn can be installed run;
`curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.0/scripts/environment_check.sh | sudo bash`

jq install:
```bash
sudo apt update
sudo apt -y install jq
```
iscsi install onto clients:
```bash
sudo apt update
sudo apt -y install open-iscsi
```
nfs-common install onto clients:
```bash
sudo apt update
sudo apt -y install nfs-common
```

## FluxCD
See [tigase scripts](https://github.com/tigase/k8s-scripts)

### Requirements
- An ingress controller (traefik, ingress-nginx etc)

### Installation

Use FluxCD to create the helm repository manifest file and update the repository.
```bash
sudo flux create source helm longhorn \
  --url="https://charts.longhorn.io" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/longhorn.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops
git add -A
git status
git commit -am "longhorn create helm source"
git push

sudo flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn

cat >/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
EOF

flux create helmrelease longhorn \
	--interval=2h \
	--release-name=longhorn \
	--source=HelmRepository/longhorn \
	--chart-version=1.5.1 \
	--chart=longhorn \
	--namespace=flux-system \
	--target-namespace=longhorn-system \
  --values=/${HOME}/${K8S_CONTEXT}/envs/longhorn-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \ 
  --export > /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn.yaml
```

Update kustomize manifests
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn.yaml

git add -A
git status
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

/*
#Patch default-class - May not need this
#```bash
#kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.#kubernetes.io/is-default-class":"false"}}}'
#kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.beta.#kubernetes.io/is-default-class":"false"}}}'
#```
*/

Create longhorn backup access key - Optional
```bash
export LH_S3_BACKUP_ACCESS_KEY=yourbackupkey
kubectl create secret generic "aws-s3-backup" \
  --namespace longhorn \
  --from-literal=AWS_ACCESS_KEY_ID="${LH_S3_BACKUP_ACCESS_KEY}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${LH_S3_BACKUP_SECRET_KEY}" \
  --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"

kubectl apply -f "/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"
```

Gernerate username and password
```bash
echo -n "longhorn-user: " >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo "longhornUser" >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo -n "longhorn-pass: " >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo "longhornPass" >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
```

```bash
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp/auth
echo "longhornUser:$(openssl passwd -stdin -apr1 <<< longhornPass)" >> /${HOME}/${K8S_CONTEXT}/tmp/auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=/${HOME}/${K8S_CONTEXT}/tmp/auth
kubectl -n longhorn-system get secret basic-auth -o yaml > /${HOME}/${K8S_CONTEXT}/longhorn-basic-auth.yaml
```

Add longhorn frontend ingress
```bash
cat>/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: /lh(/|$)(.*)
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF
```

```bash
cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git status
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

Setup recurring longhorn backup - Optional
```bash
cat >>"/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn-daily-backup.yaml"<<EOF
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: backup-daily-4-7
  namespace: longhorn-system
spec:
  cron: "7 4 * * ?"
  task: "backup"
  groups:
  - default
  retain: 30
  concurrency: 2
EOF

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

#### Helm
```bash
kubectl get node -o wide
# want to not provision on master for some reason
ssh worker1
dpkg  -l | grep iscsi
systemctl status iscsi
dpkg -l | grep nfs-common
apt install -y nfs-common
# next worker node
ssh worker2
apt install -y nfs-common
exit
# add helm repo
repo add longhorn https://charts.longhorn.io
helm repo update
helm search repo longhorn
helm show values longhorn/longhorn> /tmp/longhorn-values.yaml
helm install longhorn longhorn/longhorn --values /tmp/longhorn-values.yaml -n longhorn-storage --create-namespace
kubectl -n longhorn-storage get all
# longhorn ui
# port forward
kubectl -n longhorn-storage port-forward svc/longhorn-frontend 8080:80
curl localhost:8080
# loadbalancer via metalLB
nano /tmp/longhorn-values.yaml
service:
  ui:
    type: LoadBalancer
    nodePort: null
helm upgrade --install longhorn longhorn/onghorn --values /tmp/longhorn-values.yaml -n longhorn-storage
kubectl -n longhorn-storage get svc
nano /etc/hosts
svc-ip-address longhorn
curl longhorn
# create volume - ui
kubectl get volumes -A
# storage class - longhorn should create as default
kubectl get storageclass -A
cat>/tmp/pvc.yaml<
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-volv-pvc
spec:
  accessModes:
    - ReadWriteOnce
#  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF
kubectl apply -f /tmp/pvc.yaml
kubectl get pvc 
kubectl get pv # should be create automatically
kubectl get volumes -A
# create pod
cat>/tmp/pod.yaml<
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
  namespace: default
spec:
  containers:
  - name: volume-test
    image: nginx:stable-alpine
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: volv
      mountPath: /data
    ports:
    - containerPort: 80
  volumes:
  - name: volv
    persistentVolumeClaim:
      claimName: longhorn-volv-pvc
EOF
kubectl apply -f /tmp/pod.yaml
kubectl get pods -o wide
kubectl exec -it volume-test -- bash
cd /data
ls
touch file # create a file
exit

```

### [Testing](https://longhorn.io/docs/1.5.2/volumes-and-nodes/create-volumes/)
```bash
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.2/examples/pod_with_pvc.yaml

```

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-volv-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
  namespace: default
spec:
  containers:
  - name: volume-test
    image: nginx:stable-alpine
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: volv
      mountPath: /data
    ports:
    - containerPort: 80
  volumes:
  - name: volv
    persistentVolumeClaim:
      claimName: longhorn-volv-pvc
```

### Longhorn web UI
```bash
sudo kubectl proxy --port 8001
http://localhost:8001/api/v1/namespaces/longhorn-system/services/http:longhorn-frontend:80/proxy/
```

### Uninstallation
Remove the service config and manifest files
```bash
rm -rf /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
rm -r /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/longhorn.yaml
sed -i '/longhorn/d' /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
sed -i '/longhorn/d' /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Apply changes to git repository
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "longhorn uninstall"
git push
```
Reconcile cluster
```bash
flux reconcile source git flux-system
kubectl get all -A | grep longhorn
```
