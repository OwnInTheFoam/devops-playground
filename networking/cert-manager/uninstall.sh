#!/bin/bash
# chmod u+x uninstall.sh

# REQUIREMENTS
# - traefik
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
certmanagerVer=1.10.1
certmanagerChartVer=1.10.1
# VARIABLE DEFINES
logFile="${HOME}/cert-manager/uninstall.log"
#logFile="/dev/null"

echo "[TASK] Remove tls for traefik dashboard"
kubectl apply -f /${HOME}/traefik/traefik-dashboard.yaml >>${logFile} 2>&1

echo "[TASK] Delete certificates for traefik"
kubectl delete -f /${HOME}/cert-manager/traefik-certificate-production.yaml >>${logFile} 2>&1
kubectl delete -f /${HOME}/cert-manager/traefik-certificate-staging.yaml >>${logFile} 2>&1

echo "[TASK] Replace traefik.local.domain from hosts"
sed -i 's/traefik.local[^ ]*/traefik.local/g' /etc/hosts

echo "[TASK] Delete certificates for default"
kubectl delete -f /${HOME}/cert-manager/certificate-production.yaml >>${logFile} 2>&1
kubectl delete -f /${HOME}/cert-manager/certificate-staging.yaml >>${logFile} 2>&1

echo "[TASK] Delete cluster issuers production"
kubectl delete -f /${HOME}/cert-manager/clusterissuer-production.yaml >>${logFile} 2>&1
kubectl delete -f /${HOME}/cert-manager/clusterissuer-staging.yaml >>${logFile} 2>&1

echo "[TASK] Delete cloudflare token secret"
kubectl delete -f /${HOME}/cert-manager/cloudflare-token-secret.yaml >>${logFile} 2>&1

echo "[TASK] Uninstall cert-manager helm chart"
helm uninstall cert-manager -n cert-manager >>${logFile} 2>&1

echo "[TASK] Delete cert-manager CRD"
kubectl delete -f /${HOME}/cert-manager/cert-manager-crds.yaml >>${logFile} 2>&1

echo "[TASK] Remove jetstack helm repo"
helm repo remove jetstack >>${logFile} 2>&1

echo "[TASK] Delete cert-manager namespace"
kubectl delete namespace cert-manager >>${logFile} 2>&1

echo "[TASK] Revert traefik"
helm upgrade -n traefik -f /${HOME}/traefik/traefik-values.yaml traefik traefik/traefik >>${logFile} 2>&1

echo "COMPLETE"
