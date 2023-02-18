# kubeseal

## Installation

### Binary
```bash
wget --no-verbose https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.5/kubeseal-0.19.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.19.5-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
kubeseal --version

rm -r kubeseal
rm -r kubeseal-0.19.5-linux-amd64.tar.gz
```

### FluxCD
Get the latest helm chart version
```bash
helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
export SS_VER="2.7.4"
export CLUSTER_REPO=gitops
```

Create the helm source
```bash
flux create source helm sealed-secrets \
  --url=https://bitnami-labs.github.io/sealed-secrets \
  --interval=1h \
  --export > "${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/sealed-secrets.yaml"
```
Regenerate the kustomize manifest
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive
```
Update the git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "sealed-secrets deployment"
git push
```
Reconcile flux system
```bash
flux reconcile source git "flux-system"
```

Configure values file
```bash
cat>${HOME}/tigase/${K8S_CONTEXT}/envs/ss_values.yaml<<EOF
    ingress:
      enabled: false
EOF
```

Create helmrelease
```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
flux create helmrelease sealed-secrets \
	--interval=2h \
	--release-name=sealed-secrets-controller \
	--source=HelmRepository/sealed-secrets \
	--chart-version=${SS_VER} \
	--chart=sealed-secrets \
	--namespace=flux-system \
	--target-namespace=flux-system \
  --values=${HOME}/tigase/${K8S_CONTEXT}/envs/ss_values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/sealed-secrets.yaml
```
Update kustomize
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```
Update git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "sealed-secrets deployment"
git push
```
Flux reconcile
```bash
flux reconcile source git "flux-system"
```

Generate the sealed secrets public key
```bash
kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-${CLUSTER_NAME}.pem
```
Update git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "public-key deployment"
git push
```
Flux reconcile
```bash
flux reconcile source git "flux-system"
```

## Uninstall
```bash
rm -rf infra/common/sealed-secrets/
git commit -am "Removing sealed-secrets"
git push
flux reconcile source git flux-system
```
