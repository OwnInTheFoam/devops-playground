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
LH_VER=1.5.1 # helm search hub --max-col-width 80 longhorn | grep "/longhorn/longhorn"
# VARIABLE DEFINES
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
REQUIRED_CMDS="flux kustomize git yq openssl"
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

echo "[CHECK] Longhorn check requirements script"
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/scripts/environment_check.sh | sudo bash
echo -e "    \nPress ENTER to proceed with installation, Ctrl-C otherwise..."
read wait

echo "[TASK] Create the helm source"
sudo flux create source helm longhorn \
  --url="https://charts.longhorn.io" \
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

echo "[TASK] longhorn values file"
# helm show values longhorn/longhorn --version ${LH_VER} > ${HOME}/${K8S_CONTEXT}/envs/longohrn-values.yaml
cat>${HOME}/${K8S_CONTEXT}/envs/longhorn-values.yaml<<EOF
EOF

echo "[TASK] Create helmrelease"
mkdir -p ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
EOF

sudo flux create helmrelease longhorn \
  --interval=2h \
  --release-name=longhorn \
  --source=HelmRepository/longhorn \
  --chart-version=${LH_VER} \
  --chart=longhorn \
  --namespace=flux-system \
  --target-namespace=longhorn-system \
  --create-target-namespace \
  --values=/${HOME}/${K8S_CONTEXT}/envs/longhorn-values.yaml \
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

# TODO STORAGE CLASS?!

# Uncomment if you want to use another storage class as default
#echo "[TASK] Longhorn configuration - patch storage class"
#sudo kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
#sudo kubectl patch storageclass oci -p '{"metadata": {"annotations":{"storageclass.beta.kubernetes.io/is-default-class":"false"}}}'

#echo "[TASK] Longhorn configuration - Create backup access key"
#sudo kubectl create secret generic "aws-s3-backup" \
#  --namespace longhorn-system \
#  --from-literal=AWS_ACCESS_KEY_ID="${LH_S3_BACKUP_ACCESS_KEY}" \
#  --from-literal=AWS_SECRET_ACCESS_KEY="${LH_S3_BACKUP_SECRET_KEY}" \
#  --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
#  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"
#sudo kubectl apply -f "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/aws-s3-backup-credentials-sealed.yaml"

echo "[TASK] Longhorn configuration - User credentials"
read -s -p "Enter your longhorn username: " longhornUser
read -s -p "Enter your longhorn password: " longhornPass
echo -n "longhorn-user: " >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo "${longhornUser}" >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo -n "longhorn-pass: " >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
echo "${longhornPass}" >> /${HOME}/${K8S_CONTEXT}/k8s-secrets
mkdir -p ${HOME}/${K8S_CONTEXT}/tmp/auth
echo "${longhornUser}:$(openssl passwd -stdin -apr1 <<< ${longhornPass})" >> /${HOME}/${K8S_CONTEXT}/tmp/auth
sudo kubectl -n longhorn-system create secret generic basic-auth --from-file=/${HOME}/${K8S_CONTEXT}/tmp/auth
sudo kubectl -n longhorn-system get secret basic-auth -o yaml > /${HOME}/${K8S_CONTEXT}/longhorn-basic-auth.yaml

echo "[TASK] Add longhorn frontend ingress"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: /lh(/|$)(.*)
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF

#echo "[TASK] Setup recurring longhorn backup"
#cat>>"/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/longhorn-system/longhorn/longhorn-daily-backup.yaml"<<EOF
#apiVersion: longhorn.io/v1beta1
#kind: RecurringJob
#metadata:
#  name: backup-daily-4-7
#  namespace: longhorn-system
#spec:
#  cron: "7 4 * * ?"
#  task: "backup"
#  groups:
#  - default
#  retain: 30
#  concurrency: 2
#EOF

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
git commit -am "longhorn ingress deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
