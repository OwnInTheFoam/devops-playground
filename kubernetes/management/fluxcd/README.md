# Flux
This guide with use [flux with github](https://fluxcd.io/flux/cmd/flux_bootstrap_github/)

## [Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli)
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```
To allow this session to generate bash completions
```
. <(flux completion bash)
```
To load bash completions for each session
```
# ~/.bashrc or ~/.profile
command -v flux >/dev/null && . <(flux completion bash)
```

## Steps
```
export GITHUB_TOKEN=ghp_xxxxx
export GITHUB_USER=gitUser
flux check --pre
```

By default it uses ssh key authenitication. `--token-auth` may be passed to use access token instead.
```
flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=${gitUser} \
  --repository=gitops \
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
```
git clone git@github.com:${gitUser}/${gitRepo}.git /${HOME}/{$gitRepo}
```

Create GitRepository manifest
```
cat >>/${HOME}/{$gitRepo}/clusters/clustor0/common.yaml<<EOF
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
```
cat >>/${HOME}/{$gitRepo}/infra/common/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sources
EOF
```

```
mkdir -p /${HOME}/{$gitRepo}/infra/common//sources
cat >>/${HOME}/{$gitRepo}/infra/common/sources/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - chartmuseum.yaml
EOF
```

```
cat >>/${HOME}/{$gitRepo}/infra/common/sources/chartmuseum.yaml<<EOF
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

```
cat >>/${HOME}/{$gitRepo}/clusters/clustor0/apps.yaml<<EOF
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

```
mkdir -p /${HOME}/{$gitRepo}/infra/appss
cat >>/${HOME}/{$gitRepo}/infra/apps/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF
```

Add changes to git repository
```
git add -A
git status
git commit -am "Initial deployment"
git push
```

Trigger flux reconcile of git repository
```
flux reconcile source git flux-system
```

## Usage
Watch helm release for changes
```
flux get hr -A -w
```


## [Uninstall](https://fluxcd.io/flux/cmd/flux_uninstall/)
```
flux uninstall
```