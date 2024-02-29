#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# sealed secrets
# Persistant storage (longhorn)
# helm
# yq

# DEFINES
LO_VER="5.36.3" # helm search hub --max-col-width 80 loki | grep "/grafana/"
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[CHECK] Required environment variables"
REQUIRED_VARS=("K8S_CONTEXT")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "  - $VAR is not set! Exiting..."
    exit
  else
    echo "  - $VAR is set. Value: ${!VAR}"
  fi
done

echo "[CHECK] Required packages installed"
REQUIRED_CMDS="flux kustomize git helm yq"
for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "  - $CMD could not be found! Exiting..."
      exit
  else
    # Get package version
    VERSION=$("$CMD" --version 2>/dev/null)
    if [ -n "$VERSION" ]; then
      echo "  - $CMD is installed. Version: $VERSION"
    else
      VERSION=$("$CMD" -v 2>/dev/null)
      if [ -n "$VERSION" ]; then
        echo "  - $CMD is installed. Version: $VERSION"
      else
        VERSION=$("$CMD" version 2>/dev/null)
        if [ -n "$VERSION" ]; then
          echo "  - $CMD is installed. Version: $VERSION"
        else
          echo "  - $CMD is installed but version could not be determined."
        fi
      fi
    fi
  fi
done

echo "[TASK] Create the helm source"
sudo flux create source helm loki \
  --url="https://grafana.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/loki.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "loki create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/

echo "[TASK] Retrieve helm values"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
# helm search repo grafana/loki --versions
helm show values grafana/loki --version ${LO_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
helm repo remove grafana

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "loki helm default values"
git push

echo "[TASK] Retrieve helm values"
yq -i '.monitoring.promtail.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.serviceMonitor.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.serviceMonitor.additionalLabels.release="prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.pipelineStages[0].docker={}' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.pipelineStages[1].drop.source="namespace"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.pipelineStages[1].drop.expression="kube-.*" | .monitoring.pipelineStages[1].drop.expression style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.prometheus.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.fluent-bit.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.grafana.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.loki.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.persistence.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.persistence.size="10Gi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.config.chunk_store_config.max_look_back_period="672h"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.config.table_manager.retention_deletes_enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml
yq -i '.monitoring.config.table_manager.retention_period="672h"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml

# echo "[TASK] Configure values file"
# mkdir -p ${HOME}/${K8S_CONTEXT}/envs
# cat>/${HOME}/${K8S_CONTEXT}/envs/loki-values.yaml<<EOF
#     promtail:
#       enabled: true
#     serviceMonitor:
#       enabled: true
#       additionalLabels:
#         release: prometheus
#     pipelineStages:
#       - docker: {}
#       - drop:
#           source: namespace
#           expression: "kube-.*"
#     prometheus:
#       enabled: false
#     fluent-bit:
#       enabled: false
#     grafana:
#       enabled: false
#     loki:
#       enabled: true
#     # Configure for 28 day retention on persistent volume
#     persistence:
#       enabled: true
#       size: 10Gi
#     config:
#       chunk_store_config:
#         max_look_back_period: 672h
#       table_manager:
#         retention_deletes_enabled: true
#         retention_period: 672h
# EOF

echo "[TASK] Create monitoring namespace"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

echo "[TASK] Create helmrelease"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/
sudo flux create helmrelease loki \
  --interval=2h \
  --release-name=loki \
  --source=HelmRepository/loki \
  --chart-version=${LO_VER} \
  --chart=loki \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values-file=${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/loki-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/loki.yaml
  ##--values=/${HOME}/${K8S_CONTEXT}/envs/loki-values.yaml \

echo "[TASK] Update namespace of prometheus community chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/loki.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "loki deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
