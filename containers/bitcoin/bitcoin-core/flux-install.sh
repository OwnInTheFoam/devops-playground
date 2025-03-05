#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# kubeseal
# Load balancer (ingress-nginx)

# DEFINES
BTC_VER="1.1.13" # helm search hub --max-col-width 80 bitcoind | grep "/bitcoind/bitcoind"
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
REQUIRED_CMDS="flux kustomize git"
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
sudo flux create source helm kubernetes-dashboard \
  --url="https://kubernetes.github.io/dashboard/" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kubernetes-dashboard.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kubernetes dashboard create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard
helm repo update
# helm search repo kubernetes-dashboard/kubernetes-dashboard --versions
helm show values kubernetes-dashboard/kubernetes-dashboard --version ${DA_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml
helm repo remove kubernetes-dashboard

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kubernetes-dashboard helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.cert-manager.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml
yq -i '.nginx.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml
yq -i '.ingress.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard

echo "[TASK] Configure namespace"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease kubernetes-dashboard \
  --interval=2h \
  --release-name=kubernetes-dashboard \
  --source=HelmRepository/kubernetes-dashboard \
  --chart-version=${DA_VER} \
  --chart=kubernetes-dashboard \
  --namespace=flux-system \
  --target-namespace=kubernetes-dashboard \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/kubernetes-dashboard.yaml

echo "[TASK] Update namespace of kubernetes-dashboard chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/kubernetes-dashboard.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kubernetes-dashboard deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Configure ServiceAccount and RoleBinding"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/dashboard-service-account.yaml"<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: kubernetes-dashboard
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
    namespace: kubernetes-dashboard
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kubernetes-dashboard service account"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Create long lived bearer token secret"
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp/dashboard
sudo kubectl -n kubernetes-dashboard create token dashboard-admin  >> /${HOME}/${K8S_CONTEXT}/tmp/dashboard/token
sudo kubectl create secret generic "dashboard-token-secret" \
  --namespace "kubernetes-dashboard" \
  --type="kubernetes.io/service-account-token" \
  --from-file=/${HOME}/${K8S_CONTEXT}/tmp/dashboard/token \
  --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard/dashboard-admin-secret.yaml"
#  --annotations='kubernetes.io/service-account.name: "dashboard-admin"' \

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kubernetes-dashboard/kubernetes-dashboard
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kubernetes-dashboard account secret"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
 echo "System not ready yet, waiting anoher 10 seconds"
 sleep 10
done

echo "COMPLETE"
