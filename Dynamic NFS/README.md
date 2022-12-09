# Dynamic persistant volume
NFS subdir external provisioner is an automatic provisioner that use your existing and already configured NFS server to support dynamic provisioning of Kubernetes Persistent Volumes via Persistent Volume Claims.

## Tutorial One
[nfs-subdir-external-provisioner v4.0.17](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
by [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)
[Video](https://www.youtube.com/watch?v=DF3v2P8ENEg)

### Requirements
- An existing NFS server
- Sudo user

### Steps

#### Create a sudo user 

**Ensure nfs user created with sudo permissions**
```
sudo adduser nfsuser
sudo adduser nfsuser sudo
id nfsuser
su - nfsuser
```

#### Create a NFS server

1. **Setup NFS server on Host**

    ```
    sudo apt update
    sudo apt -y install nfs-kernel-server
    ```

2. **Create share directories on Host**

    Export a gerneral purpose mount that uses the default NFS behaviour to restrict a root user on the client machine to interact with the host with superuser privileges. 
    ```
    sudo mkdir /srv/nfs/kubedata -p
    ```

    NFS will translate any root operations on the client to the nobody:nogroup credentials. Therefore, update the directory ownership to match those credentials.
    ```
    ls -la /srv/nfs/kubedata
    sudo chown nobody:nogroup /srv/nfs/kubedata
    ```

3. **Configure NFS exports on Host**

    Add an entry to the exports file for the share directory.
    ```
    sudo nano /etc/exports
    ```
    [Configuration options](https://web.mit.edu/rhel-doc/5/RHEL-5-manual/Deployment_Guide-en-US/s1-nfs-server-config-exports.html):
    * rw: Gives the client both read and write access to the volume.
    * sync: Forces NFS to write changes to disk before replying. This results in a more stable and consistent environment since the reply reflects the actual state of the remote volume. However, it also reduces the speed of file operations.
    * no_subtree_check: Prevents subtree checking, which is a process where the host must check whether the file is actually still available in the exported tree for every request. This can cause many problems when a file is renamed while the client has it opened. In almost all cases, it is better to disable subtree checking.
    * no_root_squash: By default, NFS translates requests from a root user remotely into a non-privileged user on the server. This was intended as security feature to prevent a root account on the client from using the file system of the host as root. no_root_squash disables this behavior for certain shares.
    * no_all_squash:
    * insecure

    Example:
    ```
    /srv/nfs/kubedata     client-ip(rw,sync,no_subtree_check)
    /srv/nfs/kubedata     *(rw,sync,no_subtree_check)
    ```
    Then restart the service
    ```
    sudo systemctl restart nfs-kernel-server

    sudo systemctl enable --now nfs-kernel-server
    sudo exportfs -rav
    sudo showmount -e localhost
    ```

4. **Adjust the firewall on Host**

    ```
    sudo ufw allow from client-ip to any port nfs
    sudo ufw status
    ```

5. **Setup NFS client on Client**

    ```
    sudo apt update
    sudo apt -y install nfs-common
    ```

6. **Create mount points and directories on Client**

    ```
    sudo mkdir -p /mnt
    sudo mount host-ip:/srv/nfs/kubedata /mnt
    mount | grep kubedata
    df -h
    du -sh /mnt
    ```

7. **Test NFS access**

    ```
    sudo nano /mnt/test.txt
    ls -l /mnt/test.txt
    ```

8. **OPTIONAL - Mount remote NFS on boot**

    This is done by adding an entry to the fstab file on the client.
    ```
    sudo anno /etc/fstab
    ```
    Example:
    ```
    host-ip:/srv/nfs/kubedata   /mnt   nfs  auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
    ```

9. **Unmounting the NFS**

    ```
    sudo umount /mnt
    df -h
    ```

#### Setup dynamic NFS provision

1. **Apply the [rbac](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/blob/nfs-subdir-external-provisioner-4.0.17/deploy/rbac.yaml) manifest**

    ```
    cat >rbac.yaml<<EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: nfs-client-provisioner
      # replace with namespace where provisioner is deployed
      namespace: default
    ---
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
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
    kind: ClusterRoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
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
    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: leader-locking-nfs-client-provisioner
      # replace with namespace where provisioner is deployed
      namespace: default
    rules:
      - apiGroups: [""]
        resources: ["endpoints"]
        verbs: ["get", "list", "watch", "create", "update", "patch"]
    ---
    kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
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

    kubectl apply -f rbac.yaml
    ```

2. **Apply the [class](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/blob/nfs-subdir-external-provisioner-4.0.17/deploy/class.yaml)**

    ```
    cat >default-sc.yaml<<EOF
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

    kubectl apply -f default-sc.yaml
    ```

3. **Apply the [deployment](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/blob/nfs-subdir-external-provisioner-4.0.17/deploy/deployment.yaml)**

    ```
    cat >deployment.yaml<<EOF
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
                  value: 10.3.243.101 # change to server ip
                - name: NFS_PATH
                  value: /srv/nfs/kubedata # change to nfs directory
          volumes:
            - name: nfs-client-root
              nfs:
                server: 10.3.243.101 # change to server ip
                path: /srv/nfs/kubedata # change to nfs directory
    EOF
    
    kubectl apply -f deployment.yaml
    kubectl get pods
    ```

4. **Test by creating a persistant volume claim**

    ```
    kubectl get storageclass

    cat >pvc-nfs.yaml<<EOF
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

    kubectl apply -f pvc-nfs.yaml
    kubectl get pv,pvc
    ls /srv/nfs/kubedata
    ```
    Incase you need to debug logs
    ```
    kubectl get pods
    kubectl logs nfs-client-provisioner-XXXXXXXXX
    ```
    Incase you need to delete pvc
    ```
    kubectl delete -f pvc-nfs.yaml
    ```