#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
Ver=2.9.6
# VARIABLE DEFINES
logFile="${HOME}/kube-prometheus-stack/uninstall.log"
#logFile="/dev/null"

echo "[TASK] Delete grafana dashboard ingress route"
kubectl delete -f /${HOME}/kube-prometheus-stack/grafana-dashboard.yaml >>${logFile} 2>&1

echo "[TASK] Uninstall helm chart"
helm uninstall prometheus -n monitoring >>${logFile} 2>&1

echo "[TASK] Delete grafana secret"
kubectl delete -f /${HOME}/kube-prometheus-stack/secret.yaml >>${logFile} 2>&1

echo "[TASK] Remove prometheus helm repo"
helm repo remove prometheus-community >>${logFile} 2>&1

echo "[TASK] Remove monitoring namespace"
kubectl delete namespace monitoring >>${logFile} 2>&1

echo "COMPLETE"
