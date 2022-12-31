#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
traefikVer=2.9.6
traefikChartVer=20.8.0
# VARIABLE DEFINES
logFile="${HOME}/traefik/uninstall.log"
#logFile="/dev/null"

echo "[TASK] Remove traefik.local from hosts"
sed -i '/traefik.local/d' /etc/hosts

echo "[TASK] Delete traefik dashboard ingress route"
kubectl delete -f /${HOME}/traefik/traefik-dashboard.yaml >>${logFile} 2>&1

echo "[TASK] Uninstall helm chart"
helm uninstall traefik -n traefik >>${logFile} 2>&1

echo "[TASK] Remove traefik helm repo"
helm repo remove traefik >>${logFile} 2>&1

echo "[TASK] Remove traefik namespace"
kubectl delete namespace traefik >>${logFile} 2>&1

echo "COMPLETE"
