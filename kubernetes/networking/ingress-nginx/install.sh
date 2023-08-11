#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
nginxVer=1.5.1
nginxChartVer=4.4.2
# VARIABLE DEFINES
logFile="${HOME}/ingress-nginx/install.log"
#logFile="/dev/null"

mkdir -p /${HOME}/ingress-nginx

echo "[TASK] Add ingress-nginx helm repo"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >>${logFile} 2>&1
helm repo update >>${logFile} 2>&1

echo "[TASK] Get ingress-nginx values and alter"
#helm search repo ingress-nginx/ingress-nginx --versions
helm show values ingress-nginx/ingress-nginx --version ${nginxChartVer} > /${HOME}/nginx-ingress/values.yaml
#yq -i '.spec.install.remediation.retries = 3' /${HOME}/ingress-nginx/values.yaml
#yq -i '.spec.upgrade.remediation.retries = 3' /${HOME}/ingress-nginx/values.yaml

echo "[TASK] Install ingress-nginx with helm"
helm install ingress-nginx ingress-nginx/ingress-nginx --version ${certmanagerChartVer} --values /${HOME}/ingress-nginx/values.yaml -n ingress-nginx --create-namespace >>${logFile} 2>&1

echo "COMPLETE"
