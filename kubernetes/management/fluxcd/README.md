# Flux
This guide with use [flux with github](https://fluxcd.io/flux/cmd/flux_bootstrap_github/)

## [Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli)
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```
To allow this session to generate bash completions
```bash
. <(flux completion bash)
```
To load bash completions for each session
```bash
cat>>${HOME}/.bashrc<<EOF
command -v flux >/dev/null && . <(flux completion bash)
EOF
```

## Steps
```bash
export GITHUB_TOKEN=ghp_xyz
export GITHUB_USER=yourUser
export CLUSTER_REPO=gitops
flux check --pre
```

By default it uses ssh key authenitication. `--token-auth` may be passed to use access token instead.
```bash
flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=${GITHUB_USER} \
  --repository=${CLUSTER_REPO} \
  --branch=master \
  --path=clusters/cluster0 \
  --token-auth \
  --personal=true \
  --private=true \
  --read-write-key

kubectl get namespaces
kubectl -n flux-system get pods
```

Clone the flux repository
```bash
git clone git@github.com:${GITHUB_USER}/${CLUSTER_REPO}.git /${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
```

Create GitRepository manifest
```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/common.yaml<<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: common
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infra/common
  prune: true
  validation: client
EOF
```

Create common kustomize manifest
```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sources
EOF
```

```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - chartmuseum.yaml
EOF
```

```bash
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/chartmuseum.yaml<<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: chartmuseum
  namespace: flux-system
spec:
  interval: 30m
  url: https://helm.wso2.com
EOF
```

```bash
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/apps.yaml<<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infra/apps
  prune: true
  validation: client
EOF
```

```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps
cat>${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF
```

Add changes to git repository
```bash
git add -A
git status
git commit -am "Initial deployment"
git push
```

Trigger flux reconcile of git repository
```bash
flux reconcile source git flux-system
```

## Usage
Watch helm release for changes
```bash
flux get hr -A -w
```


## [Uninstall](https://fluxcd.io/flux/cmd/flux_uninstall/)
```bash
flux uninstall
```