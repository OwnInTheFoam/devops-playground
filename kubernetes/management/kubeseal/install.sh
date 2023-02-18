#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# DEFINES
SS_VER="2.7.4"
CLUSTER_REPO=gitops
CLUSTER_NAME=cluster0

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

echo "[TASK] Create the helm source"
flux create source helm sealed-secrets \
  --url=https://bitnami-labs.github.io/sealed-secrets \
  --interval=1h \
  --export > "${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/sealed-secrets.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "sealed-secrets source helm"
git push

echo "[TASK] Reconcile flux system"
flux reconcile source git "flux-system"
sleep 10
while flux get all -A | grep -q "Unknown" ; do 
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Configure values file"
cat>${HOME}/tigase/${K8S_CONTEXT}/envs/ss_values.yaml<<EOF
    ingress:
      enabled: false
EOF

echo "[TASK] Create helmrelease"
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
flux create helmrelease sealed-secrets \
	--interval=2h \
	--release-name=sealed-secrets-controller \
	--source=HelmRepository/sealed-secrets \
	--chart-version=${SS_VER} \
	--chart=sealed-secrets \
	--namespace=flux-system \
	--target-namespace=flux-system \
  --values=${HOME}/tigase/${K8S_CONTEXT}/envs/ss_values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets/sealed-secrets.yaml

echo "[TASK] Update kustomize"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sealed-secrets
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "sealed-secrets helmrelease"
git push

echo "[TASK] Flux reconcile"
flux reconcile source git "flux-system"
sleep 10
while flux get all -A | grep -q "Unknown" ; do 
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "[TASK] Generate the sealed secrets public key"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system &
sleep 10
curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-${CLUSTER_NAME}.pem
killall kubectl

echo "[TASK] Update git repository"
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "public-key deployment"
git push

echo "[TASK] Flux reconcile"
flux reconcile source git "flux-system"

echo "COMPLETE"
