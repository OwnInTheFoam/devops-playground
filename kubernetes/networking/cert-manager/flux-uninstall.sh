#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[TASK] Delete secret"
kubectl delete secret "cloudflare-token-secret"

echo "[TASK] Remove cert-manager manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager

echo "[TASK] Revert kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Delete helmrelease"
sudo flux delete helmrelease cert-manager

echo "[TASK] Delete the helm source"
sudo flux delete source helm cert-manager

echo "[TASK] Delete namespace"
sudo kubectl delete namespace cert-manager

echo "[TASK] Remove cert-manager source"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/cert-manager.yaml

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert-manager delete"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
