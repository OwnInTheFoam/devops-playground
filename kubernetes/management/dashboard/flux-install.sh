#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# kubeseal
# Load balancer (ingress-nginx)
# Certificate manager (cert-manager)

# DEFINES
DA_VER="7.0.3" # helm search hub --max-col-width 80 kubernetes-dashboard | grep "/k8s-dashboard/kubernetes-dashboard"
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
sudo flux create source helm kubernetes-dashboard \
  --url="https://kubernetes.github.io/dashboard/" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/k8s-dashboard.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "k8s dashboard create source helm"
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
cat>${HOME}/${K8S_CONTEXT}/envs/k8s-dashboard_values.yaml<<EOF
## Optional Cert Manager sub-chart configuration
## Enable this if you don't already have cert-manager enabled on your cluster.
cert-manager:
  enabled: false
## Optional Nginx Ingress sub-chart configuration
## Enable this if you don't already have nginx-ingress enabled on your cluster.
nginx:
  enabled: false
EOF

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard

echo "[TASK] Configure namespace"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: k8s-dashboard
EOF

echo "[TASK] Configure ServiceAccount and RoleBinding"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/dashboard-service-account.yaml"<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: k8s-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: dashboard-admin
    namespace: k8s-dashboard
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease kubernetes-dashboard \
  --interval=2h \
  --release-name=k8s-dashboard \
  --source=HelmRepository/kubernetes-dashboard \
  --chart-version=${DA_VER} \
  --chart=kubernetes-dashboard \
  --namespace=flux-system \
  --target-namespace=k8s-dashboard \
  --values=/${HOME}/${K8S_CONTEXT}/envs/k8s-dashboard_values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/k8s-dashboard.yaml

echo "[TASK] Update namespace of k8s-dashboard chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard/k8s-dashboard.yaml

cat><EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubernetes-dashboard-stg
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/secure-backends: "true"
spec:
  tls:
  - hosts:
    - your.awesome.host
    secretName: certificate-stg-dashboard
  rules:
  - host: your.awesome.host
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard/k8s-dashboard
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/k8s-dashboard
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "k8s-dashboard deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

#echo "[TASK]  secrets"
#DA_TOKEN=`kubectl -n ${DA_TARGET_NAMESPACE} get secret \
#  $(kubectl -n ${DA_TARGET_NAMESPACE} get sa/${DA_USER} -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"`
#update_k8s_secrets "dashboard-token" "${DA_TOKEN}"
#
#sudo kubectl create secret generic "cloudflare-token-secret" \
#  --namespace "cert-manager" \
#  --from-literal=cloudflare-token="${CLOUDFLARE_SECRET_KEY}" \
#  --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-cluster0.pem" \
#  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/cloudflare-solver-secret.yaml"
#
#echo "[TASK] Update kustomize"
#cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager
#rm -f kustomization.yaml
#kustomize create --autodetect --recursive
#
#echo "[TASK] Update git repository"
#cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
#git add -A
#git status
#git commit -am "k8s-dashboard deployment"
#git push
#
#echo "[TASK] Flux reconcile"
#sudo flux reconcile source git "flux-system"
#sleep 10
#while sudo flux get all -A | grep -q "Unknown" ; do
#  echo "System not ready yet, waiting anoher 10 seconds"
#  sleep 10
#done

echo "COMPLETE"
