#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
SS_VER="2.7.4"
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[TASK] Remove sealed secrets manifest directory"
rm -rf ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/
git commit -am "Removing sealed-secrets"
git push

echo "[TASK] Reconcile flux"
flux reconcile source git flux-system

echo "COMPLETE"
