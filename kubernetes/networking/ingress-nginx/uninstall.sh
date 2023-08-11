#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)

# DEFINES - versions
nginxVer=1.5.1
nginxChartVer=4.4.2
# VARIABLE DEFINES
logFile="${HOME}/ingress-nginx/install.log"
#logFile="/dev/null"

echo "[TASK] Uninstall ingress-nginx helm chart"
helm uninstall ingress-nginx -n ingress-nginx >>${logFile} 2>&1

echo "[TASK] Remove ingress-nginx helm repo"
helm repo remove ingress-nginx >>${logFile} 2>&1

echo "[TASK] Remove namespace"
kubectl delete namespace ingress-nginx >>${logFile} 2>&1

echo "COMPLETE"