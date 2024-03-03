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
# Persistant storage (longhorn)

# DEFINES
CM_VER="1.14.3" # helm search hub --max-col-width 80 cert-manager | grep "/cert-manager/cert-manager"
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
REQUIRED_CMDS="flux kustomize git kubeseal yq"
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

echo "[TASK] Install cmctl (cm command line tool)"
cd ${HOME}/${K8S_CONTEXT}
if ! command -v "cmctl" &> /dev/null; then
  echo "  - cmctl could not be found! Installing..."
  curl -fsSL -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/latest/download/cmctl-linux-amd64.tar.gz
  tar xzf cmctl.tar.gz
  sudo mv cmctl /usr/local/bin
  rm -r cmctl.tar.gz
  rm -r LICENSE
fi
echo "  - cmctl version: $(sudo cmctl version --short)"

echo "[TASK] Create the helm source"
sudo flux create source helm cert-manager \
  --url="https://charts.jetstack.io" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/cert-manager.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert-manager create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/cert-manager
helm repo add cert-manager https://charts.jetstack.io
helm repo update
# helm search repo cert-manager/cert-manager --versions
helm show values cert-manager/cert-manager --version ${CM_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/cert-manager/cert-manager-values.yaml
helm repo remove cert-manager

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert-manager helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.installCRDs=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/cert-manager/cert-manager-values.yaml
yq -i '.prometheus.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/cert-manager/cert-manager-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager

echo "[TASK] Create namespace"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease cert-manager \
  --interval=2h \
  --release-name=cert-manager \
  --source=HelmRepository/cert-manager \
  --chart-version=${CM_VER} \
  --chart=cert-manager \
  --namespace=flux-system \
  --target-namespace=cert-manager \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/cert-manager/cert-manager-values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/cert-manager.yaml

echo "[TASK] Update namespace of cert-manager chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/cert-manager.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert-manager deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Cert Manager Configuration"
read -s -p "Enter your SSL (cloudflare) email: " SSL_EMAIL
read -s -p "Enter your cloudflare domain: " CLOUDFLARE_DOMAIN
read -s -p "Enter your cloudflare secret key: " CLOUDFLARE_SECRET_KEY

export SSL_EMAIL=bookity.au@protonmail.com
export CLOUDFLARE_DOMAIN=bookity.au
export CLOUDFLARE_SECRET_KEY=EaOkqozWacVdCfluiNwM0pFZyfVGuTDJaX7br1We

echo "[TASK]   - http01 issuer's"
cat>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/issuer-staging.yaml"<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
cat>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/issuer-production.yaml"<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: default
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo "[TASK]   - dns01 issuer's"
cat>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/issuer-staging-dns.yaml"<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging-dns
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-dns
    solvers:
      - dns01:
          cloudflare:
            email: ${SSL_EMAIL}
            apiTokenSecretRef:
              name: cloudflare-token-secret
              key: cloudflare-token
        selector:
          dnsZones:
            - "${CLOUDFLARE_DOMAIN}"
EOF
cat>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/issuer-production-dns.yaml"<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
  namespace: default
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-dns
    solvers:
      - dns01:
          cloudflare:
            email: ${SSL_EMAIL}
            apiTokenSecretRef:
              name: cloudflare-token-secret
              key: cloudflare-token
        selector:
          dnsZones:
            - "${CLOUDFLARE_DOMAIN}"
EOF

echo "[TASK]  - dns solver secrets"
sudo kubectl create secret generic "cloudflare-token-secret" \
  --namespace "cert-manager" \
  --from-literal=cloudflare-token="${CLOUDFLARE_SECRET_KEY}" \
  --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/cloudflare-solver-secret.yaml"

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert manager deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[CHECK] Successful setup output:"
echo "  - clusterissuer:"
sudo kubectl get clusterissuer -A
echo "  - SealedSecret:"
sudo kubectl get SealedSecret -n cert-manager
echo "  - pods:"
sudo kubectl get pods -n cert-manager
echo "  - cmctl check api:"
sudo cmctl check api

echo -e "    \nPress ENTER to proceed with installation, Ctrl-C otherwise..."
read wait

echo "[TASK] Adding domain certificates"
echo "  - Staging"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/certificate-staging-${CLOUDFLARE_DOMAIN}.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-staging-${CLOUDFLARE_DOMAIN}
  namespace: default
spec:
  secretName: ${CLOUDFLARE_DOMAIN}-staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: "*.local.${CLOUDFLARE_DOMAIN}"
  dnsNames:
  - "local.${CLOUDFLARE_DOMAIN}"
  - "*.local.${CLOUDFLARE_DOMAIN}"
EOF
echo "  - Production"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager/certificate-${CLOUDFLARE_DOMAIN}.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-${CLOUDFLARE_DOMAIN}
  namespace: default
spec:
  secretName: ${CLOUDFLARE_DOMAIN}-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  commonName: "*.${CLOUDFLARE_DOMAIN}"
  dnsNames:
  - "${CLOUDFLARE_DOMAIN}"
  - "*.${CLOUDFLARE_DOMAIN}"
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/cert-manager/cert-manager
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "cert manager configuration"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[CHECK] Successful setup certificates ():"
sudo kubectl get certificates -A -w
sudo kubectl get order -A -w

echo "COMPLETE"
