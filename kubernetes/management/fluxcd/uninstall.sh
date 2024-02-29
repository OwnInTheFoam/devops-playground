#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/uninstall.log"
#logFile="/dev/null"

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}

echo "[TASK 1] Removing manifests"
echo "         - common.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/common.yaml

echo "         - common/kustomization.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/kustomization.yaml

echo "         - sources/kustomization.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/kustomization.yaml

echo "         - sources/chartmuseum.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/chartmuseum.yaml

echo "         - apps.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/clusters/cluster0/apps.yaml

echo "         - apps/kustomization.yaml"
rm -rf ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/kustomization.yaml

echo "[TASK 2] Removing manifest files from git repository"
git add -A
git status
git commit -am "Remove initial deployment"
git push

echo "[TASK 3] Trigger flux reconcile git repository"
sudo flux reconcile source git flux-system

echo "[TASK 4] Flux uninstall"
sudo flux uninstall

echo "[TASK 5] Clone flux repository"
cd /${HOME}/${K8S_CONTEXT}/projects
rm -rf /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}

echo "COMPLETE"
