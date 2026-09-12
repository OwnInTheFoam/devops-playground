#!/bin/bash
# chmod u+x install.sh

# REQUIREMENTS
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
TRA_VER=40.2.0 # helm search hub --max-col-width 80 traefik | grep "traefik/traefik"
# VARIABLE DEFINES
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/flux-install.log"
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
REQUIRED_CMDS="flux kustomize git yq kubectl helm"
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
sudo flux create source helm traefik \
  --url=https://helm.traefik.io/traefik \
  --interval=1h \
  --export > "${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/traefik.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "traefik create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
# helm search repo traefik/traefik --versions
helm show values traefik/traefik --version ${TRA_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
helm repo remove traefik

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "traefik helm default values"
git push

echo "[TASK] Configure values file"
#yq -i '.globalArguments[0]="--global.checknewversion=false" | .globalArguments.[] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
#yq -i '.globalArguments[1]="--global.sendanonymoususage=false" | .globalArguments.[] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
#yq -i '.ingressRoute.dashboard.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
#yq -i '.additionalArguments += "--serversTransport.insecureSkipVerify=true" | .additionalArguments.[] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
#yq -i '.additionalArguments += "--log.level=INFO" | .additionalArguments.[] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
#yq -i '.ports.web.redirectTo="websecure"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml
##yq -i '.service.spec.loadBalancerIP="192.168.0.240"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml

mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik/traefik

#echo "[TASK] Create namespace manifest"
#cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik/namespace.yaml<<EOF
#apiVersion: v1
#kind: Namespace
#metadata:
#  name: traefik
#EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease traefik \
  --interval=2h \
  --release-name=traefik \
  --source=HelmRepository/traefik \
  --chart-version=${TRA_VER} \
  --chart=traefik \
  --namespace=flux-system \
  --target-namespace=traefik \
  --create-target-namespace \
  --values=${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik/traefik-values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik/traefik/traefik.yaml

echo "[TASK] Update namespace of traefik chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik/traefik/traefik.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik/traefik
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "traefik helm release"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Wait for traefik deployment and pod running"
sudo kubectl -n traefik wait \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/name=traefik \
  --timeout=300s

echo "COMPLETE"
