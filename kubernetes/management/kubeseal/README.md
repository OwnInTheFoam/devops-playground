# kubeseal

## Installation

### Binary
```bash
wget --no-verbose https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.4/kubeseal-0.19.4-linux-amd64.tar.gz
tar -xvzf kubeseal-0.19.4-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
kubeseal --version
```

### Helm chart for cluster
```
helm search hub sealed-secrets
```

cd ${HOME}/gitops/clusters/cluster0

// flux-create-source.sh sealed-secrets https://bitnami-labs.github.io/sealed-secrets

flux create source helm sealed-secrets \
  --url=https://bitnami-labs.github.io/sealed-secrets \
  --interval=1h \
  --export > "${HOME}/gitops/clusters/cluster0/infra/common/sources/sealed-secrets.yaml"

cd ${HOME}/gitops/clusters/cluster0/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd ${HOME}/gitops/clusters/cluster0

//

git add -A
git commit -am "sealed-secrets deployment"
git push
flux reconcile source git "flux-system"

sleep 5
while flux get all -A | grep -q "Unknown" ; do 
  echo "System not ready yet, waiting anoher ${WAIT} seconds"
  sleep 5
done

/*
${SCRIPTS}/flux-create-helmrel.sh \
        sealed-secrets \
        "2.7.3" \
        "sealed-secrets-controller" \
        "flux-system" \
        "flux-system" \
        HelmRepository/sealed-secrets \
        --values=${CONFIG}/envs/ss_values.yaml --crds=CreateReplace || exit 1
*/
FILE="${DIR}/sealed-secrets.yaml"
CMD="flux create helmrelease sealed-secrets \
	--interval=1h \
	--release-name=sealed-secrets-controller \
	--source=HelmRepository/sealed-secrets \
	--chart-version=2.7.3 \
	--chart=sealed-secrets \
	--namespace=flux-system
	--target-namespace=flux-system $*" --export > ${FILE}

cd ${DIR}
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd -

cd ${CL_DIR}
rm -f kustomization.yaml
kustomize create --autodetect --recursive --namespace="${TARGET_NAMESPACE}"
cd -

cd ${BASE_DIR}
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd -

git add -A
git commit -am "sealed-secrets deployment"
git push
flux reconcile source git "flux-system"

sleep 5
while flux get all -A | grep -q "Unknown" ; do 
  echo "System not ready yet, waiting anoher ${WAIT} seconds"
  sleep 5
done

kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system &
sleep 10
curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-${CLUSTER_NAME}.pem
killall kubectl

git add -A
git commit -am "public-key deployment"
git push
flux reconcile source git "flux-system"

## Uninstall
```
rm -rf infra/common/sealed-secrets/
git commit -am "Removing sealed-secrets"
git push
flux reconcile source git flux-system
```
