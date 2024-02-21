# [Prometheus](https://prometheus.io/docs/introduction/overview/)

## Resources
[Prometheus v2.40.7](https://github.com/prometheus/prometheus/releases/tag/v2.40.7)
[Techno Tim](https://github.com/techno-tim/launchpad/tree/master/kubernetes/kube-prometheus-stack)
[tips4you](https://www.youtube.com/watch?v=hfKASyWzOIs)

### Requirememts
- K8s cluster
- persistent storage

### Installation
- Docker image
- Precompiled binaries
- Building from source
- helm

#### [Helm](https://github.com/prometheus-community/helm-charts)

```bash
helm repo add prometheus-community https://prometheud-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/prometheus --versions
#helm inspect values stable/prometheus > /prometheus-values.yaml
helm show values prometheus-community/prometheus --version 25.6.0> /${HOME}/prometheus-values.yaml
helm install prometheus prometheus-community/prometheus --version 25.6.0 --values /${HOME}/prometheus-values.yaml --namespace monitoring --create-namespace

sudo kubectl get svc -n monitoring
sudo kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-ext
minikube service prometheus-server-ext

# ui
# port forward direct
sudo kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 8080:8080
curl localhost:8080
# port forward indirect
ssh -f server1@IPAddress -p 22001 -L 30000:ContainerIP:30000 -N #if you need to port forward from remote machine
sudo kubectl proxy --port 30000
curl http://localhost:30000/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/
# loadbalancer via metalLB
nano /tmp/prometheus-values.yaml
service:
  ui:
    type: LoadBalancer
    nodePort: null
helm upgrade --install prometheus prometheus-community/prometheus --values /tmp/prometheus-values.yaml -n monitoring
sudo kubectl -n monitoring get svc
nano /etc/hosts
svc-ip-address prometheus
curl prometheus
```

#### FluxCD
Create helm repository manifest file and update the repository.
```bash
helm search hub --max-col-width 80 prometheus-community | grep "/prometheus-community/prometheus"

sudo flux create source helm prometheus-community \
  --url="https://prometheus-community.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/prometheus-community.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "prometheus deployment"
git push
flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/prometheus/

cat >/${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

flux create helmrelease prometheus \
  --interval=2h \
  --release-name=prometheus \
  --source=HelmRepository/prometheus-community \
  --chart-version=25.6.0 \
  --chart=prometheus \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=/${HOME}/${K8S_CONTEXT}/envs/prometheus-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/prometheus/prometheus.yaml
```

Update kustomize manifests
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/prometheus/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/prometheus/prometheus.yaml

git add -A
git commit -am "prometheus deployment"
git push
flux reconcile source git "flux-system"
```

### Usage
