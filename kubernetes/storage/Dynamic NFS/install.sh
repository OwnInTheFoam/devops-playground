#!/bin/bash
# chmod u+x install.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
nfsVer=4.0.17
# VARIABLE DEFINES
logFile="${HOME}/storage/install.log"
#logFile="/dev/null"

mkdir -p /${HOME}/storage

echo "[TASK]"

echo "COMPLETE"
