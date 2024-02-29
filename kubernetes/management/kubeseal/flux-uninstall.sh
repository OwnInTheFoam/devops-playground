#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
SS_VER="2.15.0" #helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
SS_BINARY_VER="0.26.0" #https://github.com/bitnami-labs/sealed-secrets/releases
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[TASK] Remove sealed secrets manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/

echo "[TASK] Revert kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Delete helmrelease"
sudo flux delete helmrelease sealed-secrets

echo "[TASK] Delete the helm source"
sudo flux delete source helm sealed-secrets

echo "[TASK] Remove sealed-secrets source"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/sealed-secrets.yaml

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Remove sealed secrets manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/sealed-secrets

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "sealed-secrets delete"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Delete kubeseal executable"
sudo rm -rf /usr/local/bin/kubeseal
rm -rf ${HOME}/${K8S_CONTEXT}/tmp/*kubeseal*

echo "COMPLETE"
