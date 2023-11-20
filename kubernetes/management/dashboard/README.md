# [Kubernetes dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

[Creating a user account](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)
[Accessing dashboard](https://github.com/kubernetes/dashboard/blob/v3.0.0-alpha0/docs/user/accessing-dashboard/README.md)

## Resources
[Kubernetes Dashboard Helm Install](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard)

## Installation

### Manifest
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml
```

### [Helm](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard)
```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

### FluxCD
```sh
DA_VER="7.0.3" # helm search hub --max-col-width 80 kubernetes-dashboard | grep "/k8s-dashboard/kubernetes-dashboard"
DA_URL="https://kubernetes.github.io/dashboard/"
DA_NAME="k8s-dash"
DA_S_NAME="${DA_NAME}"
DA_RNAME="kubernetes-dashboard"
DA_NAMESPACE="${FLUX_NS}"
DA_TARGET_NAMESPACE="${DA_NAME}"
DA_SOURCE="HelmRepository/${DA_S_NAME}"
DA_VALUES="--values=${CONFIG}/envs/k8s-dashboard-values.yaml"
```

Create helm repository manifest file and update the repository.
```bash
sudo flux create source helm kubernetes-dashboard \
  --url="https://kubernetes.github.io/dashboard/" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/k8s-dashboard.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "k8s-dashboard deployment"
git push

flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: k8s-dashboard
EOF

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/dashboard-service-account.yaml"<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: k8s-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: dashboard-admin
    namespace: k8s-dashboard
EOF

sudo flux create helmrelease kubernetes-dashboard \
	--interval=2h \
	--release-name=k8s-dashboard \
	--source=HelmRepository/kubernetes-dashboard \
	--chart-version=${DA_VER} \
	--chart=kubernetes-dashboard \
	--namespace=flux-system \
	--target-namespace=k8s-dashboard \
  --values=/${HOME}/${K8S_CONTEXT}/envs/k8s-dashboard_values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --set=nginx.enabled=false \
  --set=cert-manager.enabled=false \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/k8s-dashboard.yaml
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/k8s-dashboard.yaml
```

TODO DO WE NEED THE FOLLOWING:
```bash
DA_TOKEN=`kubectl -n ${DA_TARGET_NAMESPACE} get secret \
  $(kubectl -n ${DA_TARGET_NAMESPACE} get sa/${DA_USER} -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"`

update_k8s_secrets "dashboard-token" "${DA_TOKEN}"
```

Update kustomize manifests
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

```bash
git add -A
git status
git commit -am "k8s-dashboard deployment"
git push

flux reconcile source git "flux-system"
```

## Uninstallation

## FluxCD
Remove manifest files from repository
```bash
rm -r /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager
rm -r /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/cert-manager.yaml
sed -i '/cert-manager/d' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kustomization.yaml
sed -i '/cert-manager/d' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kustomization.yaml
```
Update the repository
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "cert-manager uninstallation"
git push
```
Reconcile the cluster
```bash
flux reconcile source git "flux-system"
```
Delete secret
```bash
kubectl delete secret "route53-secret"
```

## [Access](https://github.com/kubernetes/dashboard/blob/v3.0.0-alpha0/docs/user/accessing-dashboard/README.md)

**Service URL**
Ensure you use the correct namespace, service name & service port!
```bash
http://localhost:8001/api/v1/namespaces/k8s-dashboard/services/https:kubernetes-dashboard:https/proxy/
```

**Port forwarding**
```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-nginx-controller 8443:443
```
You'll be able to access it at
```bash
https://localhost:8443
```

