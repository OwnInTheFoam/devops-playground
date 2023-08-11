#!/bin/bash
# chmod u+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# yq

# DEFINES - versions
metallbVer=0.13.10 # helm search hub --max-col-width 80 metallb | grep "metallb/metallb"
# VARIABLE DEFINES
startingIP="192.168.0.240"
endingIP="192.168.0.250"
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

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
REQUIRED_CMDS="flux kustomize git yq"
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

echo "[TASK] Editing kube-proxy config"
cd "${HOME}/${K8S_CONTEXT}"
sudo kubectl get configmap kube-proxy -n kube-system -o yaml > configmap.yaml
yq eval '.data."config.conf" = (.data."config.conf" | sub("mode: \".*\"", "mode: \"ipvs\""))' -i ${HOME}/${K8S_CONTEXT}/configmap.yaml
yq eval '.data."config.conf" = (.data."config.conf" | sub("strictARP: false", "strictARP: true"))' -i ${HOME}/${K8S_CONTEXT}/configmap.yaml
sudo kubectl apply -f /${HOME}/${K8S_CONTEXT}/configmap.yaml -n kube-system

echo "[TASK] Create the helm source"
sudo flux create source helm metallb \
  --url=https://metallb.github.io/metallb \
  --interval=1h \
  --export > "${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/metallb.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "metallb create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] metallb values file"
cat>${HOME}/${K8S_CONTEXT}/envs/metallb-values.yaml<<EOF
EOF
# helm show values ingress-nginx/ingress-nginx --version ${nginxChartVer} > /${HOME}/nginx-ingress/values.yaml

echo "[TASK] Create helmrelease"
# TODO this should actually be /metallb-system/metallb
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
EOF

sudo flux create helmrelease metallb \
  --interval=2h \
  --release-name=metallb \
  --source=HelmRepository/metallb \
  --chart-version=${metallbVer} \
  --chart=metallb \
  --namespace=flux-system \
  --target-namespace=metallb-system \
  --create-target-namespace \
  --values=${HOME}/${K8S_CONTEXT}/envs/metallb-values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/metallb.yaml

echo "[TASK] Update namespace of metallb chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/metallb.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "metallb deployment"
git push

echo "[TASK] Create configuration manifests"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/config
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/config/IPAddressPool.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${startingIP}-${endingIP}
EOF
cat>${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/config/L2Advertisement.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/config
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/metallb/metallb/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
git add -A
git status
git commit -am "metallb deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Wait for metallb deployment running"
# Wait for a metallb-system pod named controller
while [[ $(sudo kubectl -n metallb-system get pods -o=name | grep controller) == "" ]]; do
   sleep 1
done
# Wait for metallb-system controller pod to be running
while [[ $(sudo kubectl -n metallb-system get $(sudo kubectl -n metallb-system get pods -o=name | grep controller) -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

echo "COMPLETE"
