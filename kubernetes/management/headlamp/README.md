# [Headlamp](https://headlamp.dev/)

[Headlamp documentation](https://headlamp.dev/docs/latest/)
[Headlamp GitHub](https://github.com/kubernetes-sigs/headlamp)

## Resources
[Headlamp Helm Install](https://artifacthub.io/packages/helm/headlamp/headlamp)

## Installation

### Manifest
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml
```

### [Helm](https://artifacthub.io/packages/helm/headlamp/headlamp)
```bash
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm upgrade --install headlamp headlamp/headlamp --create-namespace --namespace headlamp
```

### FluxCD
```sh
HL_VER="0.42.0" # helm search hub --max-col-width 80 headlamp | grep "/headlamp/headlamp"
HL_URL="https://kubernetes-sigs.github.io/headlamp/"
HL_NAME="headlamp"
HL_S_NAME="${HL_NAME}"
HL_RNAME="headlamp"
HL_NAMESPACE="${FLUX_NS}"
HL_TARGET_NAMESPACE="${HL_NAME}"
HL_SOURCE="HelmRepository/${HL_S_NAME}"
HL_VALUES="--values=${CONFIG}/envs/headlamp-values.yaml"
```

Create helm repository manifest file and update the repository.
```bash
sudo flux create source helm headlamp \
  --url="https://kubernetes-sigs.github.io/headlamp/" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/headlamp.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp deployment"
git push

flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: headlamp
EOF

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp-service-account.yaml"<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: headlamp-admin
    namespace: headlamp
EOF

sudo flux create helmrelease headlamp \
	--interval=2h \
	--release-name=headlamp \
	--source=HelmRepository/headlamp \
	--chart-version=${HL_VER} \
	--chart=headlamp \
	--namespace=flux-system \
	--target-namespace=headlamp \
  --values=/${HOME}/${K8S_CONTEXT}/envs/headlamp_values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp.yaml
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp.yaml
```

TODO DO WE NEED THE FOLLOWING:
```bash
HL_TOKEN=`kubectl -n ${HL_TARGET_NAMESPACE} get secret \
  $(kubectl -n ${HL_TARGET_NAMESPACE} get sa/${HL_USER} -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"`

update_k8s_secrets "headlamp-token" "${HL_TOKEN}"
```

Update kustomize manifests
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

```bash
git add -A
git status
git commit -am "headlamp deployment"
git push

flux reconcile source git "flux-system"
```

## Uninstallation

## FluxCD
Remove manifest files from repository
```bash
rm -r /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp
rm -r /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/headlamp.yaml
sed -i '/headlamp/d' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kustomization.yaml
sed -i '/headlamp/d' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kustomization.yaml
```
Update the repository
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "headlamp uninstallation"
git push
```
Reconcile the cluster
```bash
flux reconcile source git "flux-system"
```
Delete secret
```bash
kubectl delete secret "headlamp-token-secret" --namespace headlamp
```

## [Access](https://headlamp.dev/docs/latest/installation/in-cluster/)

**Port forwarding**
```bash
kubectl -n headlamp port-forward svc/headlamp 8080:80
```
You'll be able to access it at
```bash
http://localhost:8080
```

**Bearer token**
```bash
kubectl -n headlamp create token headlamp-token-secret
kubectl -n headlamp get secret headlamp-token-secret -o jsonpath='{.data.token}' | base64 -d
```

Alternative with remote access:
```bash
kubectl -n headlamp port-forward svc/headlamp 8080:80
ssh -f -N -L 8080:localhost:8080 -p 22004 server4@IPAddress #if you need to port forward from remote machine
http://localhost:8080
ps aux | grep ssh # see ports forwarded
```
