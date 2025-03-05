# bitcoind

- [docker-bitcoind](https://github.com/kylemanna/docker-bitcoind)

## Helm Chart
- [bitcoind-chart](https://github.com/chrisrun/bitcoind-chart)

```sh
export BT_VER=1.1.3
export K8S_CONTEXT=kubernetes
export CLUSTER_REPO=gitops

mkdir /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps/bitcoind

sudo flux create source helm bitcoind \
 --url="https://chrisrun.github.io/bitcoind-chart/" \
 --interval=2h \
 --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/bitcoind.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps/bitcoind
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoind create source helm"
git push

sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

helm repo add bitcoind https://chrisrun.github.io/bitcoind-chart/
helm repo update
#helm search hub --max-col-width 80 bitcoind | grep "bitcoind"
#helm search repo bitcoind/bitcoind --versions
helm show values bitcoind/bitcoind --version ${BT_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoind/bitcoind-values.yaml
#helm upgrade --install bitcoind bitcoind/bitcoind -n bitcoind --create-namespace
#helm install bitcoind bitcoind/bitcoind --version 1.1.3 --values ~/bitcoind-values.yaml --namespace bitcoind --create-namespace
helm repo remove bitcoind

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoind helm default values"
git push

#yq -i '.cert-manager.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/kubernetes-dashboard/kubernetes-dashboard-values.yaml

mkdir /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps/bitcoind/bitcoind
mkdir /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps/bitcoind/bitcoind/bitcoind

cat>"${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/namespace.yaml"<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: bitcoind
EOF

sudo flux create helmrelease bitcoind \
	--interval=2h \
	--release-name=bitcoind \
	--source=HelmRepository/bitcoind \
	--chart-version=1.1.3 \
	--chart=bitcoind \
	--namespace=flux-system \
	--target-namespace=bitcoind \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/bitcoind/bitcoind-values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/bitcoind/bitcoind.yaml

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/apps/bitcoind/bitcoind

yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/c/bitcoind.yaml

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/bitcoind/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/bitcoind/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/apps/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "bitcoind deployment"
git push

sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

```
