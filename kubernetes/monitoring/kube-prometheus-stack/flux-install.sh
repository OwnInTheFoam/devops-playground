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

# DEFINES
PM_VER="56.19.0" # helm search hub --max-col-width 80 prometheus-community | grep "/prometheus-community/kube-prometheus-stack"
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
REQUIRED_CMDS="flux kustomize git"
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
sudo flux create source helm prometheus-community \
  --url="https://prometheus-community.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/prometheus-community.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "prometheus-community create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done


echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# helm search repo prometheus-community/prometheus-community --versions
helm show values prometheus-community/kube-prometheus-stack --version ${PM_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
helm repo remove prometheus-community

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kube-prometheus-stack helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.alertmanager.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.create=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.etcd=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.kubeScheduler=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.kubeEtcd.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.kubeScheduler.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].name="loki-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].selector.matchLabels.app="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].selector.matchLabels.release="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].namespaceSelector.matchNames[0]="monitoring"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].endpoints[0].port="http-metrics"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].endpoints[0].port style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].name="promtail-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].selector.matchLabels.app="promtail"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].selector.matchLabels.release="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].namespaceSelector.matchNames[0]="monitoring"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].endpoints[0].port="http-metrics"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].endpoints[0].port style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.volumeClaimTemplate.spec.accessModes[0]="ReadWriteOnce"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.volumeClaimTemplate.spec.resources.requests.storage="5Gi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.volumeClaimTemplate.spec.storageClassName="longhorn"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheusOperator.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack

echo "[TASK] Create namespace"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

echo "[TASK] Create the grafana secret and update the manifest"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
read -s -p "Enter your grafana user: " GRAFANA_ADMIN_USER
read -s -p "Enter your grafana password: " GRAFANA_ADMIN_PASSWORD

sudo kubectl create secret generic "kube-prometheus-credentials" \
 --namespace "monitoring" \
 --from-literal=grafana_admin_user="${GRAFANA_ADMIN_USER}" \
 --from-literal=grafana_admin_password="${GRAFANA_ADMIN_PASSWORD}" \
 --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
 --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-credentials-sealed.yaml"

yq e -i '.grafana.admin.existingSecret = "kube-prometheus-credentials"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq e -i '.grafana.admin.userKey = "grafana_admin_user"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq e -i '.grafana.admin.passwordKey = "grafana_admin_password"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml

echo "[TASK] Create helmrelease"
sudo flux create helmrelease kube-prometheus-stack \
  --interval=2h \
  --release-name=kube-prometheus-stack \
  --source=HelmRepository/prometheus-community \
  --chart-version=${PM_VER} \
  --chart=kube-prometheus-stack \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml

echo "[TASK] Update namespace of prometheus community chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kube-prometheus-stack deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
