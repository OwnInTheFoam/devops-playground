#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
HELM_VER="3.14.2"

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[TASK] Fetch Helm binaries"
wget --no-verbose https://get.helm.sh/helm-v$HELM_VER-linux-amd64.tar.gz

echo "[TASK] Extract Helm binaries"
tar -zxvf helm-v$HELM_VER-linux-amd64.tar.gz

echo "[TASK] Install Helm binaries"
sudo mv linux-amd64/helm /usr/local/bin/helm

helm version
echo "COMPLETE"
