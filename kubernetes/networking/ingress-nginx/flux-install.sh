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
IN_VER="4.9.1" # helm search hub --max-col-width 80 ingress-nginx | grep "ingress-nginx/ingress-nginx"
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
REQUIRED_CMDS="flux kustomize git yq"
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

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# helm search repo ingress-nginx/ingress-nginx --versions
helm show values ingress-nginx/ingress-nginx --version ${IN_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
helm repo remove ingress-nginx

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "ingress-nginx helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.controller.service.annotations."service.beta.kubernetes.io/oci-load-balancer-shape"="flexible"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.service.annotations."service.beta.kubernetes.io/oci-load-balancer-shape-flex-min"=10' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.service.annotations."service.beta.kubernetes.io/oci-load-balancer-shape-flex-max"=10' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.config.use-proxy-protocol="false"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.config.server-tokens="false"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.config.enable-brotli="true"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.config.use-forwarded-headers="true"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.admissionWebhooks.timeoutSeconds=30' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.publishService.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.extraArgs.update-status-on-shutdown="false"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.updateStrategy.rollingUpdate.maxUnavailable=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.updateStrategy.type="RollingUpdate"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.ingressClassResource.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.ingressClassResource.default=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.replicaCount=2' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.serviceMonitor.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.serviceMonitor.additionalLabels.release="prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.additionalLabels.release="prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].alert="Ingress-NGINXConfigFailed"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].expr="count(nginx_ingress_controller_config_last_reload_successful == 0) > 0"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].for="1s"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].labels.severity="critical"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].annotations.description="bad ingress config - nginx config test failed"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.metrics.prometheusRule.rules[0].annotations.summary="uninstall the latest ingress changes to allow config reloads to resume"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.resources.limits.cpu=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.resources.limits.memory="1024Mi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.resources.requests.cpu="100m"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml
yq -i '.controller.resources.requests.memory="128Mi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml

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
  --values=${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/ingress-nginx/ingress-nginx-values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx/ingress-nginx.yaml

echo "[TASK] Update namespace of ingress-nginx chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx/ingress-nginx.yaml

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
