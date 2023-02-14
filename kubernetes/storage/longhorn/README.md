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
`curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.0/scripts/environment_check.sh | bash`

## FluxCD
See [tigase scripts](https://github.com/tigase/k8s-scripts)

### Installation

Use FluxCD to create the helm repository manifest file and update the repository.
```
flux create source helm longhorn \
  --url="https://charts.longhorn.io" \
  --interval=2h \
  --export > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/longhorn.yaml"

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

Gernerate username and password
```
echo -n "longhorn-user: " >> /${HOME}/tigase/${K8S_CONTEXT}/k8s-secrets
echo "longhornUser" >> /${HOME}/tigase/${K8S_CONTEXT}/k8s-secrets
echo -n "longhorn-pass: " >> /${HOME}/tigase/${K8S_CONTEXT}/k8s-secrets
echo "longhornPass" >> /${HOME}/tigase/${K8S_CONTEXT}/k8s-secrets
```

Create helm release
```
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn

cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
EOF

flux create helmrelease longhorn \
	--interval=2h \
	--release-name=longhorn \
	--source=HelmRepository/longhorn \
	--chart-version=1.4.0 \
	--chart=longhorn \
	--namespace=flux-system \
	--target-namespace=longhorn-system \
  --values=/${HOME}/tigase/${K8S_CONTEXT}/envs/longhorn-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \ 
  --export > /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn.yaml
```

Update kustomize manifests
```
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd -

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn.yaml

git add -A
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

Patch default-class - May not need this
```
kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.beta.kubernetes.io/is-default-class":"false"}}}'
```

Create longhorn backup access key - Optional
```
kubectl create secret generic "aws-s3-backup" \
  --namespace longhorn \
  --from-literal=AWS_ACCESS_KEY_ID="${LH_S3_BACKUP_ACCESS_KEY}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${LH_S3_BACKUP_SECRET_KEY}" \
  --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
  --format=yaml > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"

kubectl apply -f "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"
```

```
echo "longhornUser:$(openssl passwd -stdin -apr1 <<< longhornPass)" >> /${HOME}/tigase/${K8S_CONTEXT}/tmp/auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=/${HOME}/tigase/${K8S_CONTEXT}/tmp/auth
kubectl -n longhorn-system get secret basic-auth -o yaml > /${HOME}/tigase/${K8S_CONTEXT}/longhorn-basic-auth.yaml
```

Add longhorn frontend ingress
```
cat >>/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn-ingress.yaml<<EOF
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

```
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

Setup recurring longhorn backup - Optional
```
cat >>"/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn/longhorn-daily-backup.yaml"<<EOF
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

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am "longhorn deployment"
git push
flux reconcile source git "flux-system"
```

### Longhorn web UI
```
kubectl proxy --port 8001
http://localhost:8001/api/v1/namespaces/longhorn-system/services/http:longhorn-frontend:80/proxy/
```

### Uninstallation
Via script with
```
/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-longhorn.sh --remove
```

Remove the service config and manifest files
```
rm -rf /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/longhorn.yaml
sed -i '/longhorn/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
sed -i '/longhorn/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Apply changes to git repository
```
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "longhorn uninstall"
git push
```
Reconcile cluster
```
flux reconcile source git flux-system
kubectl get all -A | grep longhorn
```
