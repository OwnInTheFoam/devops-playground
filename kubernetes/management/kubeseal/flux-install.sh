#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# kubectl

# DEFINES
export SS_VER="2.15.0" #helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
export SS_BINARY_VER="0.26.0" #https://github.com/bitnami-labs/sealed-secrets/releases
export CLUSTER_REPO=gitops
export CLUSTER_NAME=cluster0

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
REQUIRED_CMDS="flux kustomize git kubectl"
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

echo "[TASK] Create the helm source"
sudo flux create source helm sealed-secrets \
  --url=https://bitnami-labs.github.io/sealed-secrets \
  --interval=1h \
  --export > "${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/sealed-secrets.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "sealed-secrets create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/sealed-secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
# helm search repo sealed-secrets/sealed-secrets --versions
helm show values sealed-secrets/sealed-secrets --version ${SS_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/sealed-secrets/sealed-secrets-values.yaml
helm repo remove sealed-secrets

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "sealed-secrets helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.ingress.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/sealed-secrets/sealed-secrets-values.yaml

echo "[TASK] Create helmrelease"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
sudo flux create helmrelease sealed-secrets \
  --interval=2h \
  --release-name=sealed-secrets-controller \
  --source=HelmRepository/sealed-secrets \
  --chart-version=${SS_VER} \
  --chart=sealed-secrets \
  --namespace=flux-system \
  --target-namespace=flux-system \
  --values=${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/sealed-secrets/sealed-secrets-values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/sealed-secrets.yaml

echo "[TASK] Update namespace of prometheus community chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/sealed-secrets.yaml

echo "[TASK] Update kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "sealed-secrets helmrelease"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Generate the sealed secrets public key"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
sudo kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system &
sleep 10
curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-${CLUSTER_NAME}.pem
sudo killall kubectl

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "public-key deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Install kubeseal command line tool"
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp
cd ${HOME}/${K8S_CONTEXT}/tmp/
wget --no-verbose "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${SS_BINARY_VER}/kubeseal-${SS_BINARY_VER}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${SS_BINARY_VER}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
sudo kubeseal --version

echo "COMPLETE"
