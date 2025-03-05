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
kubectl delete secret "kube-prometheus-credentials"

echo "[TASK] Remove cert-manager manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack

echo "[TASK] Revert kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Delete helmrelease"
sudo flux delete helmrelease kube-prometheus-stack 

echo "[TASK] Delete the helm source"
sudo flux delete source helm prometheus-community

echo "[TASK] Remove cert-manager source"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/prometheus-community.yaml

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Remove prometheus-community manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kube-prometheus-stack delete"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
