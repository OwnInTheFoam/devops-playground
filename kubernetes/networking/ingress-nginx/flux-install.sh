#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# metalLB

# DEFINES
IN_VER="4.7.1" # helm search hub --max-col-width 80 ingress-nginx | grep "ingress-nginx/ingress-nginx"
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
    VERSION=$("$CMD" -v 2>/dev/null)
    if [ -n "$VERSION" ]; then
      echo "  - $CMD is installed. Version: $VERSION"
    else
      VERSION=$("$CMD" --version 2>/dev/null)
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
sudo flux create source helm ingress-nginx \
  --url=https://kubernetes.github.io/ingress-nginx \
  --interval=1h \
  --export > "${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/ingress-nginx.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "ingress-nginx create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Configure values file"
mkdir -p ${HOME}/${K8S_CONTEXT}/envs
cat>${HOME}/${K8S_CONTEXT}/envs/nginx_values.yaml<<EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/oci-load-balancer-shape: flexible
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: 10
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: 10
  config:
    use-proxy-protocol: "false"
    server-tokens: "false"
    enable-brotli: "true"
    use-forwarded-headers: "true"
  admissionWebhooks:
    timeoutSeconds: 30
  publishService:
    enabled: true
  extraArgs:
    update-status-on-shutdown: "false"
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  ingressClassResource:
    enabled: true
    default: true
  replicaCount: 2
  metrics:
    enabled: false
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: prometheus
    prometheusRule:
      enabled: true
      additionalLabels:
        release: prometheus
      rules:
        - alert: Ingress-NGINXConfigFailed
          expr: count(nginx_ingress_controller_config_last_reload_successful == 0) > 0
          for: 1s
          labels:
            severity: critical
          annotations:
            description: bad ingress config - nginx config test failed
            summary: uninstall the latest ingress changes to allow config reloads to resume
  resources:
    limits:
      cpu: 1
      memory: 1024Mi
    requests:
      cpu: 100m
      memory: 128Mi
EOF

echo "[TASK] Create helmrelease"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx
sudo flux create helmrelease ingress-nginx \
  --interval=2h \
  --release-name=ingress-nginx \
  --source=HelmRepository/ingress-nginx \
  --chart-version=${IN_VER} \
  --chart=ingress-nginx \
  --namespace=flux-system \
  --target-namespace=ingress-nginx \
  --create-target-namespace \
  --values=${HOME}/${K8S_CONTEXT}/envs/nginx_values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx/ingress-nginx.yaml

echo "[TASK] Update kustomize"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "ingress-nginx deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
