#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
TRA_VER=40.2.0
# VARIABLE DEFINES
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/flux-uninstall.log"
#logFile="/dev/null"

echo "[TASK] Remove traefik manifest directory"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/traefik

echo "[TASK] Revert kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Delete helmrelease"
sudo flux delete helmrelease traefik

echo "[TASK] Delete the helm source"
sudo flux delete source helm traefik

#echo "[TASK] Delete namespace"
#sudo kubectl delete namespace traefik

echo "[TASK] Remove traefik source"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/traefik.yaml

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Delete helm charts"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/traefik

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "traefik delete"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
