# [Kube-Prometheus-Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
Chart version 43.2.1, aaplication version 0.61.1.

## Resources
[Techno Tim](https://github.com/techno-tim/launchpad/tree/master/kubernetes/kube-prometheus-stack)

## Requirememts
- K8s cluster
- persistent storage

## Installation
Add the helm chart and retrieve the values file.
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/kube-prometheus-stack --versions
mkdir ${HOME}/kube-prometheus-stack
helm show values prometheus-community/kube-prometheus-stack --version 43.2.1 > /${HOME}/kube-prometheus-stack/values.yaml
```

If you need to alter the values then do so;
```bash
nano /${HOME}/kube-prometheus-stack
```

Values to change;
```bash
fullnameOverride: prometheus
alertmanager:
  fullnameOverride: alertmanager
grafana:
  fullnameOverride: grafana
  admin:
    existingSecret: grafana-dashboard-auth
    userKey: admin-user
    passwordKey: admin-password
kubelet:
  serviceMonitor:
    metricRelabelings:
      - action: replace
        sourceLabels:
          - node
        targetLabel: instance
kubeControllerManager:
  endpoints: # ips of servers
    - 192.168.0.215
    - 192.168.0.225
    - 192.168.0.226
kubeEtcd:
  endpoints: # ips of servers
    - 192.168.0.215
    - 192.168.0.225
    - 192.168.0.226
kubeScheduler:
  endpoints: # ips of servers
    - 192.168.0.215
    - 192.168.0.225
    - 192.168.0.226
kubeProxy:
  endpoints: # ips of servers
    - 192.168.0.215
    - 192.168.0.225
    - 192.168.0.226
kube-state-metrics:
  fullnameOverride: kube-state-metrics
  prometheus:
    monitor:
      relabelings:
        - action: replace
          regex: (.*)
          replacement: $1
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: kubernetes_node
  selfMonitor:
    enabled: true
nodeExporter:
  serviceMonitor:
    relabelings:
      - action: replace
        regex: (.*)
        replacement: $1
        sourceLabels:
          - __meta_kubernetes_pod_node_name
        targetLabel: kubernetes_node
prometheus-node-exporter:
  fullnameOverride: node-exporter
  prometheus:
    monitor:
      enabled: true
      relabelings:
        - action: replace
          regex: (.*)
          replacement: $1
          sourceLabels:
            - __meta_kubernetes_pod_node_name
          targetLabel: kubernetes_node
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 2048Mi
prometheus:
  prometheusSpec:
    enableAdminAPI: true
    replicaExternalLabelName: "replica"
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    retention: 2d
```

If you dont have a default storage class, you can set storage keys on the services that need storage and specify which storage class to use. [SEE](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/storage.md)
```bash
prometheusSpec:
  storageSpec:
    volumeClaimTemplate:
      spec:
        storageClassName: managed-nfs-storage
        accessModes:
          - ReadWriteMany
        resources:
          requests:
            storage: 5Gi
```

Before installing the stack, create the grafana dashboard secret;
```bash
%htpasswd -nb your-username | base64
%htpasswd -nb your-password | base64
echo -n 'your-username' | base64
echo -n 'your-password' | base64

cat >/${HOME}/kube-prometheus-stack/secret.yaml<<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-dashboard-auth
  namespace: monitoring
type: Opaque
data:
  admin-user: REDACTED
  admin-password: REDACTED
EOF

kubectl create namespace monitoring
kubectl apply -f /${HOME}/kube-prometheus-stack/secret.yaml
kubectl get secret -n monitoring grafana-dashboard-auth -o jsonpath="{.data.admin-user}" | base64 --decode
```

Install the stack;
```bash
helm install prometheus prometheus-community/kube-prometheus-stack --version 43.2.1 --values /${HOME}/kube-prometheus-stack/values.yaml --namespace monitoring
```

## Setup access

1. Port forwarding

```bash
kubectl -n monitoring get pods -o wide | grep grafana
kubectl port-forward -n monitoring grafana-84df59b9cb-zds8x 52222:3000
```

2. IngressRoute
Deploy certificates for monitoring
```bash
cat >/${HOME}/kube-prometheus-stack/monitoring-certificate-production.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: monitoring-cert-production
  namespace: monitoring
spec:
  secretName: monitoring-production-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: grafana.local.${userDomain}
  dnsNames:
  - grafana.local.${userDomain}

EOF
kubectl apply -f /${HOME}/kube-prometheus-stack/monitoring-certificate-production.yaml
```

Deploy ingress route for grafana dashboard
```bash
cat >/${HOME}/kube-prometheus-stack/grafana-dashboard.yaml<<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana-dashboard
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`grafana.local.${userDomain}.au\`)
      kind: Rule
      services:
        - name: grafana
          port: 3000
  tls:
    secretName: monitoring-production-tls
EOF

kubectl apply -f /${HOME}/kube-prometheus-stack/grafana-dashboard.yaml
```

## FluxCD
[See Tigase](https://github.com/tigase/k8s-scripts)

### Installation

Create helm repository manifest file and update the repository.
```bash
flux create source helm prometheus-community \
  --url="https://prometheus-community.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/prometheus-community.yaml"

//flux reconcile source helm prometheus-community

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "kube-prometheus-stack deployment"
git push
flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/

cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

flux create helmrelease kube-prometheus-stack \
  --interval=2h \
  --release-name=kube-prometheus-stack \
  --source=HelmRepository/prometheus-community \
  --chart-version=44.4.1 \
  --chart=kube-prometheus-stack \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=/root/tigase/kubernetes-admin@kubernetes/envs/prometheus-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml
```

Create the grafana secret and update the manifest
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
export GRAFANA_ADMIN_PASSWORD=yourPassword

kubectl create secret generic "prometheus-stack-credentials" \
  --namespace "monitoring" \
  --from-literal=grafana_admin_password="${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubeseal --cert="pub-sealed-secrets-cluster0.pem" \
  --format=yaml > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/prometheus-stack-credentials-sealed.yaml"

cat >>"/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml"<<EOF
  valuesFrom:
    - kind: Secret
      name: prometheus-stack-credentials
      valuesKey: grafana_admin_password
      targetPath: grafana.adminPassword
      optional: false
EOF
```

Update kustomize manifests
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml

git add -A
git commit -am "kube-prometheus-stack deployment"
git push
flux reconcile source git "flux-system"
```

### Uninstallation

Via script with
```bash
/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-kube-prometheus-stack.sh --remove
/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-script-preprocess.sh --remove ?!?
```

```bash
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack
sed -i '/prometheus/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kustomization.yaml
//sed -i '/monitoring/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
//sed -i '/prometheus/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Apply changes to git repository
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "prometheus stack uninstall"
git push
```
Reconcile cluster
```bash
flux reconcile source git "flux-system"
kubectl get all -A | grep prometheus
```

## DEBUG
kubectl logs pods/helm-controller-xxxxxxxxxxx -n flux-system

kubectl get helmrepository <name> -oyaml