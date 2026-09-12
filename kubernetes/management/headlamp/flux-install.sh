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
# Certificate manager (headlamp)

# DEFINES
HL_VER="0.42.0" #helm search hub --max-col-width 80 headlamp | grep "/headlamp/headlamp"
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
sudo flux create source helm headlamp \
  --url="https://kubernetes-sigs.github.io/headlamp/" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/headlamp.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
# helm search repo headlamp/headlamp --versions
helm show values headlamp/headlamp --version ${HL_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
helm repo remove headlamp

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.ingress.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.ingressClassName="traefik"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.ingressClassName style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].host="headlamp.<REDACTED>"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].host style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].paths[0].path="/"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].paths[0].path style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].paths[0].type="Prefix"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.hosts[0].paths[0].type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.tls[0].hosts[0]="headlamp.<REDACTED>"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.tls[0].hosts[0] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.tls[0].secretName="headlamp-wildcard-tls"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml
yq -i '.ingress.tls[0].secretName style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp

echo "[TASK] Configure namespace"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: headlamp
EOF

echo "[TASK] Create helmrelease"
sudo flux create helmrelease headlamp \
  --interval=2h \
  --release-name=headlamp \
  --source=HelmRepository/headlamp \
  --chart-version=${HL_VER} \
  --chart=headlamp \
  --namespace=flux-system \
  --target-namespace=headlamp \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/headlamp/headlamp-values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp.yaml

echo "[TASK] Update namespace of headlamp chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp.yaml

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Configure certificate"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp-certificate.yaml"<<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: headlamp-wildcard
  namespace: headlamp
spec:
  secretName: headlamp-wildcard-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
    - "*.<REDACTED>"
    - <REDACTED>
EOF

echo "[TASK] Configure ServiceAccount and RoleBinding"
cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp-service-account.yaml"<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: headlamp-admin
    namespace: headlamp
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp service account"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Create long lived bearer token secret"
# No token goes into this manifest, and it is not sealed, on purpose.
#
# A Secret of type kubernetes.io/service-account-token that carries the
# service-account annotation and NO token key is filled in by the token
# controller with a token that never expires. Every earlier version of this
# step sealed in the output of `kubectl create token`, which is a one-hour
# TokenRequest token -- and because the key was then already present, the
# controller left it alone. The result was a committed credential that was dead
# an hour after every install.
#
# Nothing here is secret before the controller fills it in, so there is nothing
# for kubeseal to protect; the token only ever exists in the cluster.
rm -f "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp-admin-secret.yaml"
cat>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp/headlamp-admin-token.yaml"<<EOF
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-token-secret
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp-admin
type: kubernetes.io/service-account-token
EOF

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/headlamp/headlamp
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "headlamp account secret"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
 echo "System not ready yet, waiting anoher 10 seconds"
 sleep 10
done

echo "COMPLETE"
