# [Loki](https://github.com/grafana/loki)

## Resources

## Requirememts

## Installation

### FluxCD
[loki-stack Deprecated](https://github.com/grafana/helm-charts/tree/main/charts/loki-stack)

helm search hub --max-col-width 80 loki | grep "/grafana/"

export LO_VER="5.10.0"
LO_NAME="loki"
LO_S_NAME="grafana"
LO_RNAME="loki"
LO_NAMESPACE="${FLUX_NS}"
LO_TARGET_NAMESPACE="monitoring"
LO_SOURCE="HelmRepository/${LO_S_NAME}"
LO_VALUES="--values=${CONFIG}/envs/loki-values.yaml"

Create helm repository manifest file and update the repository.
```bash
sudo flux create source helm loki \
  --url="https://grafana.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/loki.yaml"

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "loki deployment"
git push

flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

cat>/${HOME}/${K8S_CONTEXT}/envs/loki-values.yaml<<EOF
    promtail:
      enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: prometheus
    pipelineStages:
      - docker: {}
      - drop:
          source: namespace
          expression: "kube-.*"
    prometheus:
      enabled: false
    fluent-bit:
      enabled: false
    grafana:
      enabled: false
    loki:
      enabled: true
    # Configure for 28 day retention on persistent volume
    persistence:
      enabled: true
      size: 10Gi
    config:
      chunk_store_config:
        max_look_back_period: 672h
      table_manager:
        retention_deletes_enabled: true
        retention_period: 672h
EOF

sudo flux create helmrelease loki \
  --interval=2h \
  --release-name=loki \
  --source=HelmRepository/loki \
  --chart-version=${LO_VER} \
  --chart=loki \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=/${HOME}/${K8S_CONTEXT}/envs/loki-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/loki.yaml
```

```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/loki.yaml
```

Update kustomize manifests
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```bash
git add -A
git status
git commit -am "loki deployment"
git push

flux reconcile source git "flux-system"
```

## Uninstallation

### FluxCD

```bash
rm -r /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/loki
```
Apply changes to git repository
```bash
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "loki"
git push
```
Reconcile cluster
```bash
flux reconcile source git "flux-system"
kubectl get all -A | grep loki
```
