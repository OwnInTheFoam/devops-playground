#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# git package
# kustomize package

# DEFINES
GITHUB_USER=yourUser
GITHUB_EMAIL=yourEmail
CLUSTER_REPO=gitops
# Setup ssh keypair with your git account and the cluster master.

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[CHECK] Required environment variables"
REQUIRED_VARS=("K8S_CONTEXT")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "  - $VAR is not set! Exiting..."
    exit
  else
    echo "  - $VAR is set. Value: ${!VAR}"
  fi
done

echo "[CHECK] Required packages installed"
REQUIRED_CMDS="kustomize git"
for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "  - $CMD could not be found! Exiting..."
      exit
  else
    # Get package version
    VERSION=$("$CMD" --version 2>/dev/null)
    if [ -n "$VERSION" ]; then
      echo "  - $CMD is installed. Version: $VERSION"
    else
      VERSION=$("$CMD" -v 2>/dev/null)
      if [ -n "$VERSION" ]; then
        echo "  - $CMD is installed. Version: $VERSION"
      else
        VERSION=$("$CMD" version 2>/dev/null)
        if [ -n "$VERSION" ]; then
          echo "  - $CMD is installed. Version: $VERSION"
        else
          echo "  - $CMD is installed but version could not be determined."
        fi
      fi
    fi
  fi
done

echo "[CHECK] Installation of flux"
if ! command -v flux &> /dev/null; then
  echo "  No flux. Setting up flux."
  curl -s https://fluxcd.io/install.sh | sudo bash
  echo "  Enabling global flux bash completion"
  cat>>${HOME}/.bashrc<<EOF
command -v flux >/dev/null && . <(flux completion bash)
EOF
else
  FLUX_VERSION=$(flux -v 2>/dev/null)
  if [ -n "$FLUX_VERSION" ]; then
    echo "  Flux is installed. Version: $FLUX_VERSION"
  else
    echo "  Flux is installed but version could not be determined."
  fi
fi

echo "[TASK 1] Running flux check pre install"
sudo flux check --pre
echo -e "    \nPress ENTER to proceed with flux installation, Ctrl-C otherwise..."
read wait

echo "[TASK 2] Flux bootstrap"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
# flux bootstrap should query for token
#read -s -p "Enter your github personal token: " GITHUB_TOKEN
#export GITHUB_TOKEN=${GITHUB_TOKEN}
sudo flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=${GITHUB_USER} \
  --repository=${CLUSTER_REPO} \
  --branch=master \
  --path=clusters/cluster0 \
  --token-auth \
  --personal=true \
  --private=true \
  --read-write-key

echo -e "    \nPress ENTER if flux successfully installed and continue, Ctrl-C otherwise..."
read wait

echo "[TASK 3] Clone flux repository"
git clone git@github.com:${GITHUB_USER}/${CLUSTER_REPO}.git /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}

echo "[TASK 4] Set git user configuration"
git config user.name "$GITHUB_USER"
git config user.email "$GITHUB_EMAIL"

echo "[TASK 5] Creating manifests"
echo "         - common.yaml"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/common.yaml<<EOF
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

echo "         - common/kustomization.yaml"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - sources
EOF

echo "         - sources/kustomization.yaml"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - chartmuseum.yaml
EOF

echo "         - sources/chartmuseum.yaml"
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/chartmuseum.yaml<<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: chartmuseum
  namespace: flux-system
spec:
  interval: 30m
  url: https://helm.wso2.com
EOF

echo "         - apps.yaml"
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/apps.yaml<<EOF
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

echo "         - apps/kustomization.yaml"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/kustomization.yaml<<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources: []
EOF

echo "[TASK 6] Adding to git repository"
git add -A
git status
git commit -am "Initial deployment"
git push

echo "[TASK 7] Trigger flux reconcile git repository"
sudo flux reconcile source git flux-system

echo "COMPLETE"
