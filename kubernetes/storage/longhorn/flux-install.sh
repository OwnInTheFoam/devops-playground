#!/bin/bash
# chmod u+x flux-install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# yq
# openssl
# ingress-nginx

# DEFINES - versions
LH_VER=1.11.2 # helm search hub --max-col-width 80 longhorn | grep "/longhorn/longhorn"
# VARIABLE DEFINES
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/flux-install.log"
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

KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config}"
if [[ ! -f "${KUBECONFIG_PATH}" ]]; then
  echo "  - kubeconfig not found at ${KUBECONFIG_PATH}. Exiting..."
  exit
fi

echo "[CHECK] Required packages installed"
REQUIRED_CMDS="flux kustomize git yq openssl curl helm kubectl kubeseal"
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

#kubectl describe node server2 | grep -i taint
#kubectl describe node server3 | grep -i taint
#kubectl describe node server4 | grep -i taint
#kubectl taint nodes server2 node-role.kubernetes.io/control-plane:NoSchedule-
#kubectl taint nodes server3 node-role.kubernetes.io/control-plane:NoSchedule-
#kubectl taint nodes server4 node-role.kubernetes.io/control-plane:NoSchedule-

echo "[CHECK] Longhorn preflight requirements"
if command -v longhornctl &> /dev/null; then
  LONGHORNCTL=$(command -v longhornctl)
else
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64)
      LH_CTL_ARCH="amd64"
      ;;
    aarch64|arm64)
      LH_CTL_ARCH="arm64"
      ;;
    *)
      echo "  - Unsupported architecture for longhornctl: ${ARCH}. Exiting..."
      exit
      ;;
  esac
  LONGHORNCTL="/usr/local/bin/longhornctl"
  sudo curl -sSfL -o "${LONGHORNCTL}" "https://github.com/longhorn/cli/releases/download/v${LH_VER}/longhornctl-linux-${LH_CTL_ARCH}"
  sudo chmod +x "${LONGHORNCTL}"
fi
sudo "${LONGHORNCTL}" --kubeconfig="${KUBECONFIG_PATH}" check preflight
echo -e "    \nPress ENTER to proceed with installation, Ctrl-C otherwise..."
read wait

echo "[TASK] Create the helm source"
sudo flux create source helm longhorn \
  --url="https://charts.longhorn.io" \
  --namespace="flux-system" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/longhorn.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn
helm repo add longhorn https://charts.longhorn.io
helm repo update
# helm search repo longhorn/longhorn --versions
helm show values longhorn/longhorn --version ${LH_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
helm repo remove longhorn

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn helm default values"
git push

echo "[TASK] Configure values file"
# >>> lightweight
# Four nodes at home, not a datacenter. The CSI sidecars are leader-elected --
# only one of each is ever active and the Deployment reschedules it if its node
# dies -- so three copies apiece is 8 idle pods. The UI is stateless.
yq -i '.csi.attacherReplicaCount=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
yq -i '.csi.provisionerReplicaCount=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
yq -i '.csi.resizerReplicaCount=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
yq -i '.csi.snapshotterReplicaCount=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
yq -i '.longhornUI.replicas=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
# Data replicas: 2 copies, not 3. Every write fans out to each replica over
# 1GbE, so this roughly halves Longhorn's replication traffic. Two knobs:
# defaultClassReplicaCount is what the `longhorn` StorageClass stamps on every
# PVC (the one that matters), defaultReplicaCount covers volumes made outside
# it. Existing volumes keep their own spec.numberOfReplicas -- change those
# per volume. Not 1: nodes have died here, and 1 replica is no redundancy.
yq -i '.persistence.defaultClassReplicaCount=2' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
yq -i '.defaultSettings.defaultReplicaCount=2' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml
# <<< lightweight
# todo setup backups

mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn

echo "[TASK] Create namespace"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease longhorn \
  --interval=2h \
  --release-name=longhorn \
  --source=HelmRepository/longhorn \
  --chart-version=${LH_VER} \
  --chart=longhorn \
  --namespace=flux-system \
  --target-namespace=longhorn-system \
  --create-target-namespace \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/longhorn/longhorn-values.yaml \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn.yaml

echo "[TASK] Update namespace of longhorn chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Longhorn configuration - User credentials"
read -s -p "Enter your longhorn username: " longhornUser
read -s -p "Enter your longhorn password: " longhornPass
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp
echo "${longhornUser}:$(openssl passwd -stdin -apr1 <<< ${longhornPass})" >> /${HOME}/${K8S_CONTEXT}/tmp/longhorn-auth
sudo kubectl create secret generic "longhorn-secret" \
  --namespace "longhorn-system" \
  --from-file=/${HOME}/${K8S_CONTEXT}/tmp/longhorn-auth \
  --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/auth-secret.yaml"

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "longhorn secrets"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

# >>> basicauth
echo "[TASK] Add longhorn frontend ingress with basic auth"
# The Longhorn UI has no authentication of its own and can delete volumes, so
# it is never published without a login in front of it. The credentials are the
# ones read above; `longhorn-secret` keeps the old nginx-format copy, this is
# the `users` key Traefik's middleware reads.
#
# cert-manager Certificates are namespace scoped, so this namespace needs its
# own wildcard; letsencrypt-dns is the only issuer that can satisfy one.
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-certificate.yaml<<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: longhorn-wildcard
  namespace: longhorn-system
spec:
  secretName: longhorn-wildcard-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
    - "*.<REDACTED>"
    - <REDACTED>
EOF

# Traefik's basicAuth middleware reads an htpasswd list from the `users` key.
# openssl's apr1 output is one of the formats Traefik accepts. Capture it into
# a variable first: the hash contains `$` and would be expanded by the shell if
# written inline inside double quotes.
BASICAUTH_USERS="${longhornUser}:$(openssl passwd -apr1 "${longhornPass}")"
sudo kubectl create secret generic "longhorn-system-basicauth" \
  --namespace "longhorn-system" \
  --from-literal=users="${BASICAUTH_USERS}" \
  --dry-run=client -o yaml \
  | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-system-basicauth.yaml.tmp" \
  && mv "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-system-basicauth.yaml.tmp" "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-system-basicauth.yaml"
if [ ! -s "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-system-basicauth.yaml" ]; then
  echo "  - FAILED to seal longhorn-system-basicauth! Exiting before commit..."
  rm -f "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-system-basicauth.yaml.tmp"
  exit 1
fi

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/basicauth-middleware.yaml<<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basicauth
  namespace: longhorn-system
spec:
  basicAuth:
    secret: longhorn-system-basicauth
    removeHeader: true
EOF

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn
  namespace: longhorn-system
  annotations:
    # Middleware refs are <namespace>-<name>@kubernetescrd. Cross-namespace
    # references are off in the Traefik values, so the middleware lives here.
    traefik.ingress.kubernetes.io/router.middlewares: longhorn-system-basicauth@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
    - host: longhorn.<REDACTED>
      http:
        paths:
          - backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - longhorn.<REDACTED>
      secretName: longhorn-wildcard-tls
EOF
# <<< basicauth

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
git add -A
git status
git commit -am "longhorn deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
