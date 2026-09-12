#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# sealed secrets
# helm
# yq
# kube-prometheus-stack (for the ServiceMonitor CRD)
# tempo (Beyla exports traces to it)

# DEFINES
BE_VER="1.16.11" # helm search repo grafana/beyla --versions
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
sudo flux create source helm beyla \
  --url="https://grafana.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/beyla.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "beyla create source helm"
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
# helm search repo grafana/beyla --versions
helm show values grafana/beyla --version ${BE_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
helm repo remove grafana

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "beyla helm default values"
git push

echo "[TASK] Configure values file"
# Most services on this cluster carry no instrumentation of their own, so Beyla
# is where their RED metrics and traces come from. 'application' is the chart
# default preset; set it explicitly so the intent is visible.
yq -i '.preset="application"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
yq -i '.preset style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
# The ServiceMonitor template is gated on service.enabled too, which is off by
# default -- without it Beyla exports metrics that nothing ever scrapes.
yq -i '.service.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
yq -i '.serviceMonitor.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
# Ship the spans Beyla derives to Tempo.
yq -i '.config.data.otel_traces_export.endpoint="http://tempo.monitoring.svc.cluster.local:4318"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
yq -i '.config.data.otel_traces_export.endpoint style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml
# privileged + hostNetwork DNS stay at the chart defaults: eBPF requires them.

echo "[TASK] Create monitoring namespace"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

echo "[TASK] Create helmrelease"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/beyla/
sudo flux create helmrelease beyla \
  --interval=2h \
  --release-name=beyla \
  --source=HelmRepository/beyla \
  --chart-version=${BE_VER} \
  --chart=beyla \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/grafana/beyla-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/beyla/beyla.yaml

echo "[TASK] Update namespace of grafana chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/beyla/beyla.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/beyla/
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
git commit -am "beyla deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
