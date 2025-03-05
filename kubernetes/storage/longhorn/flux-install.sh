#!/bin/bash
# chmod u+x flux-install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# yq
# openssl
# ingress-nginx

# DEFINES - versions
LH_VER=1.6.0 # helm search hub --max-col-width 80 longhorn | grep "/longhorn/longhorn"
# VARIABLE DEFINES
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
REQUIRED_CMDS="flux kustomize git yq openssl"
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

echo "[CHECK] Longhorn check requirements script"
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v${LH_VER}/scripts/environment_check.sh | sudo bash
echo -e "    \nPress ENTER to proceed with installation, Ctrl-C otherwise..."
read wait

echo "[TASK] Create the helm source"
sudo flux create source helm longhorn \
  --url="https://charts.longhorn.io" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/longhorn.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn
helm repo add longhorn https://charts.longhorn.io
helm repo update
# helm search repo longhorn/longhorn --versions
helm show values longhorn/longhorn --version ${LH_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
helm repo remove longhorn

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn helm default values"
git push

echo "[TASK] Configure values file"
# empty todo setup backups

mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn

echo "[TASK] Create namespace"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease longhorn \
  --interval=2h \
  --release-name=longhorn \
  --source=HelmRepository/longhorn \
  --chart-version=${LH_VER} \
  --chart=longhorn \
  --namespace=flux-system \
  --target-namespace=longhorn-system \
  --create-target-namespace \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn.yaml

echo "[TASK] Update namespace of longhorn chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Longhorn configuration - User credentials"
read -s -p "Enter your longhorn username: " longhornUser
read -s -p "Enter your longhorn password: " longhornPass
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp
echo "${longhornUser}:$(openssl passwd -stdin -apr1 <<< ${longhornPass})" >> /${HOME}/${K8S_CONTEXT}/tmp/longhorn-auth
sudo kubectl create secret generic "longhorn-secret" \
  --namespace "longhorn-system" \
  --from-file=/${HOME}/${K8S_CONTEXT}/tmp/longhorn-auth \
  --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/auth-secret.yaml"

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn secrets"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

#echo "[TASK] Add longhorn frontend ingress"
#cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn-ingress.yaml<<EOF
#apiVersion: networking.k8s.io/v1
#kind: Ingress
#metadata:
#  name: longhorn-ingress
#  namespace: longhorn-system
#  annotations:
#    kubernetes.io/ingress.class: "nginx"
#    nginx.ingress.kubernetes.io/auth-type: basic
#    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
#    nginx.ingress.kubernetes.io/auth-secret: basic-auth
#    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
#    nginx.ingress.kubernetes.io/rewrite-target: /\$2
#spec:
#  rules:
#  - http:
#      paths:
#      - pathType: Prefix
#        path: /lh(/|$)(.*)
#        backend:
#          service:
#            name: longhorn-frontend
#            port:
#              number: 80
#EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
git add -A
git status
git commit -am "longhorn deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
