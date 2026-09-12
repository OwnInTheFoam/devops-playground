#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# FluxCD
# Kustomize
# git
# sealed secrets
# Persistant storage (longhorn)

# DEFINES
PM_VER="83.4.0" # helm search hub --max-col-width 80 prometheus-community | grep "/prometheus-community/kube-prometheus-stack"
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
sudo flux create source helm prometheus-community \
  --url="https://prometheus-community.github.io/helm-charts" \
  --interval=2h \
  --export > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/prometheus-community.yaml"

echo "[TASK] Regenerate the kustomize manifest"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "prometheus-community create source helm"
git push

echo "[TASK] Reconcile flux system"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done


echo "[TASK] Retrieve helm values"
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# helm search repo prometheus-community/prometheus-community --versions
helm show values prometheus-community/kube-prometheus-stack --version ${PM_VER} > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
helm repo remove prometheus-community

echo "[TASK] Update the git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kube-prometheus-stack helm default values"
git push

echo "[TASK] Configure values file"
yq -i '.alertmanager.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# Alertmanager keeps silences and notification state on disk; without a PVC
# they are lost on every restart.
yq -i '.alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.accessModes[0]="ReadWriteOnce"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage="1Gi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName="longhorn"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.create=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.etcd=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.kubeScheduler=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.kubeControllerManager=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.defaultRules.rules.kubeProxy=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# The control-plane components bind their metrics to localhost only on this
# cluster, so Prometheus cannot reach them from a pod:
#   etcd                    --listen-metrics-urls=http://127.0.0.1:2381
#   kube-scheduler          --bind-address=127.0.0.1
#   kube-controller-manager --bind-address=127.0.0.1
#   kube-proxy              metricsBindAddress: ""  (defaults to localhost)
# Leaving these enabled gives four permanently firing TargetDown alerts.
# Enabling them for real means changing the kubeadm manifests on the nodes,
# which is out of scope for gitops.
yq -i '.kubeEtcd.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.kubeScheduler.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.kubeControllerManager.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.kubeProxy.enabled=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].name="loki-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].selector.matchLabels.app="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].selector.matchLabels.release="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].namespaceSelector.matchNames[0]="monitoring"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].endpoints[0].port="http-metrics"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[0].endpoints[0].port style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].name="promtail-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].selector.matchLabels.app="promtail"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].selector.matchLabels.release="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].namespaceSelector.matchNames[0]="monitoring"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].endpoints[0].port="http-metrics"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[1].endpoints[0].port style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]="ReadWriteOnce"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage="5Gi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName="longhorn"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.type="pvc"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.accessModes[0]="ReadWriteOnce"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.size="5Gi"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.persistence.storageClassName="longhorn"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# A ReadWriteOnce PVC and the default RollingUpdate strategy deadlock: the new
# pod cannot attach the volume until the old pod releases it, and the old pod
# is not removed until the new one is ready (Multi-Attach error, Helm times
# out). Recreate stops the old pod first. Correct for a single replica.
yq -i '.grafana.deploymentStrategy.type="Recreate"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.deploymentStrategy.type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# Fresh installs render this cleanly. Switching an EXISTING release from
# RollingUpdate fails once with "rollingUpdate: Forbidden ... Recreate": the live
# Deployment carries API-defaulted rollingUpdate.{maxSurge,maxUnavailable}, Helm's
# three-way merge keeps them, and setting rollingUpdate to null in values does
# nothing (Helm drops null keys while coalescing). Patch the live object once:
#   kubectl -n monitoring patch deploy kube-prometheus-stack-grafana --type=json \n#     -p='[{"op":"remove","path":"/spec/strategy/rollingUpdate"},{"op":"replace","path":"/spec/strategy/type","value":"Recreate"}]'
# Loki and Tempo are separate HelmReleases; wire them in as Grafana datasources
# so logs and traces are queryable from the same Grafana as the metrics.
yq -i '.grafana.additionalDataSources[0].name="Loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].type="loki"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].access="proxy"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].access style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].url="http://loki.monitoring.svc.cluster.local:3100"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[0].url style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].name="Tempo"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].type="tempo"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].access="proxy"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].access style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].url="http://tempo.monitoring.svc.cluster.local:3200"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.additionalDataSources[1].url style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# >>> dashboards
# Community dashboards, provisioned rather than imported by hand. A dashboard
# imported through the UI lives only in Grafana's database on the PVC and is
# gone with it; these are re-fetched from grafana.com by the chart's
# download-dashboards init container on every Grafana start, into a
# 'Community' folder. Pin the revision -- grafana.com dashboards change.
# To add one: another entry under .grafana.dashboards.community with its
# gnetId (the number in the grafana.com URL) and current revision.
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".apiVersion=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name="community"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder="Community"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type="file"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path="/var/lib/grafana/dashboards/community"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# Node Exporter Full -- per-node CPU/memory/disk/network and the hwmon
# temperature panels under 'Hardware Misc'. https://grafana.com/grafana/dashboards/1860
yq -i '.grafana.dashboards.community.node-exporter-full.gnetId=1860' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.node-exporter-full.revision=45' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.node-exporter-full.datasource="Prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.node-exporter-full.datasource style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# <<< dashboards
# >>> alerts-and-monitors
# --- Discovery. The chart defaults every *SelectorNilUsesHelmValues to true,
# which makes Prometheus ignore any ServiceMonitor/PrometheusRule not labelled
# release=kube-prometheus-stack. That silently dropped Tempo's ServiceMonitor and
# would drop anything created outside this chart (crypta-infra's analytic-service
# monitor). false = "select everything", which is what the AWS cluster runs.
yq -i '.prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.probeSelectorNilUsesHelmValues=false' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# --- Retention. 5Gi PVC: without a size cap Prometheus fills it and stops
# writing. retentionSize wins over retention when the disk is the limit.
yq -i '.prometheus.prometheusSpec.retention="15d"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.retention style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.retentionSize="4GB"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.prometheusSpec.retentionSize style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# --- Longhorn metrics: longhorn-manager serves /metrics on the longhorn-backend
# service, port "manager" (9500). Kept here rather than in the Longhorn script
# because Longhorn installs before this chart's ServiceMonitor CRD exists.
yq -i '.prometheus.additionalServiceMonitors[2].name="longhorn-monitor"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[2].name style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[2].selector.matchLabels.app="longhorn-manager"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[2].namespaceSelector.matchNames[0]="longhorn-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[2].endpoints[0].port="manager"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.prometheus.additionalServiceMonitors[2].endpoints[0].port style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# --- Alert rules. Merged in as additionalPrometheusRulesMap so the chart labels
# them for the operator. Longhorn rules are upstream's published examples
# (docs/1.11.0/monitoring/alert-rules-example); thresholds unchanged.
cat>/${HOME}/${K8S_CONTEXT}/tmp/kps-rules.yaml<<EOF
node-temperature:
  groups:
    - name: node-temperature
      rules:
        - alert: NodeTemperatureHigh
          expr: node_hwmon_temp_celsius > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "{{ \$labels.instance }} {{ \$labels.chip }} {{ \$labels.sensor }} at {{ \$value }}C"
            description: "A hwmon sensor has been above 80C for 5 minutes."
        - alert: NodeTemperatureCritical
          expr: node_hwmon_temp_celsius > 90
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ \$labels.instance }} {{ \$labels.chip }} {{ \$labels.sensor }} at {{ \$value }}C"
            description: "A hwmon sensor has been above 90C for 2 minutes. Thermal shutdown is likely."
longhorn:
  groups:
    - name: longhorn
      rules:
        - alert: LonghornVolumeActualSpaceUsedWarning
          expr: (longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) * 100 > 90
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Volume {{ \$labels.volume }} actual space used is over 90% of capacity"
        - alert: LonghornVolumeStatusCritical
          expr: longhorn_volume_robustness == 3
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Volume {{ \$labels.volume }} is Fault"
        - alert: LonghornVolumeStatusWarning
          expr: longhorn_volume_robustness == 2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Volume {{ \$labels.volume }} is Degraded"
        - alert: LonghornNodeStorageWarning
          expr: (longhorn_node_storage_usage_bytes / longhorn_node_storage_capacity_bytes) * 100 > 70
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Storage on {{ \$labels.node }} is over 70% used"
        - alert: LonghornDiskStorageWarning
          expr: (longhorn_disk_usage_bytes / longhorn_disk_capacity_bytes) * 100 > 70
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Disk {{ \$labels.disk }} on {{ \$labels.node }} is over 70% used"
        - alert: LonghornNodeDown
          expr: (avg(longhorn_node_count_total) or on() vector(0)) - (count(longhorn_node_status{condition="ready"} == 1) or on() vector(0)) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "{{ \$value }} Longhorn node(s) are not Ready"
EOF
# Double-quoted on purpose: the load() path has to be shell-expanded.
yq -i ".additionalPrometheusRulesMap = load(\"/${HOME}/${K8S_CONTEXT}/tmp/kps-rules.yaml\")" /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# --- Dashboards for the rest of the stack. Longhorn and Loki from grafana.com;
# Tempo publishes its own in the Tempo repo, pinned to the running version.
yq -i '.grafana.dashboards.community.longhorn.gnetId=17626' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.longhorn.revision=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.longhorn.datasource="Prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.longhorn.datasource style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.loki-promtail.gnetId=10880' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.loki-promtail.revision=1' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.loki-promtail.datasource="Prometheus"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.loki-promtail.datasource style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.tempo-operational.url="https://raw.githubusercontent.com/grafana/tempo/v2.9.0/operations/tempo-mixin-compiled/dashboards/tempo-operational.json"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.dashboards.community.tempo-operational.url style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# <<< alerts-and-monitors
# >>> dashboard-backups
# Dashboards made in the UI live only in Grafana's SQLite on the PVC.
# backup-dashboards.sh exports them into this repo as ConfigMaps that the
# dashboard sidecar (already on, label grafana_dashboard=1) loads back. These
# settings make that round trip work:
#   folderAnnotation      a ConfigMap annotated grafana_folder=Custom lands in a
#                         'Custom' folder instead of General
#   allowUiUpdates        backed-up dashboards stay editable in the UI (edits are
#                         captured by the next backup run; a restart before that
#                         reverts to the committed copy)
yq -i '.grafana.sidecar.dashboards.folderAnnotation="grafana_folder"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.sidecar.dashboards.folderAnnotation style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.sidecar.dashboards.provider.foldersFromFilesStructure=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.grafana.sidecar.dashboards.provider.allowUiUpdates=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# <<< dashboard-backups
# >>> alertmanager-telegram
echo "[TASK] Alertmanager: Telegram receiver"
# Without a receiver every alert is discarded (the chart default route is
# "null"). Alertmanager speaks Telegram natively. The bot token is the secret:
# sealed into alertmanager-telegram and read by Alertmanager from the mounted
# file. The chat id is just a number and lives in the readable config below.
#
#   Bot token: @BotFather -> /newbot. Chat id: message the bot once, then
#   https://api.telegram.org/bot<TOKEN>/getUpdates -> result[].message.chat.id
#   (negative for a group; the bot must be a member of it).
read -s -p "Enter the Telegram bot token: " TELEGRAM_BOT_TOKEN
echo
read -p "Enter the Telegram chat id: " TELEGRAM_CHAT_ID
if ! [[ "${TELEGRAM_CHAT_ID}" =~ ^-?[0-9]+$ ]]; then
  echo "  - chat id must be an integer (got '${TELEGRAM_CHAT_ID}')! Exiting..."
  exit 1
fi
sudo kubectl create secret generic "alertmanager-telegram"   --namespace "monitoring"   --from-literal=bot_token="${TELEGRAM_BOT_TOKEN}"   --dry-run=client -o yaml   | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem"   --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-telegram.yaml.tmp"   && mv "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-telegram.yaml.tmp" "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-telegram.yaml"
if [ ! -s "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-telegram.yaml" ]; then
  echo "  - FAILED to seal alertmanager-telegram! Exiting before commit..."
  rm -f "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-telegram.yaml.tmp"
  exit 1
fi
# The operator mounts alertmanagerSpec.secrets at /etc/alertmanager/secrets/<name>/<key>.
yq -i '.alertmanager.alertmanagerSpec.secrets[0]="alertmanager-telegram"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq -i '.alertmanager.alertmanagerSpec.secrets[0] style="double"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# Routing. Watchdog fires permanently by design and is dropped. The three
# inhibit rules are the chart defaults, kept so a critical alert silences its
# warning/info siblings.
cat>/${HOME}/${K8S_CONTEXT}/tmp/kps-alertmanager.yaml<<EOF
global:
  resolve_timeout: 5m
route:
  receiver: telegram
  group_by:
    - alertname
    - namespace
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - receiver: "null"
      matchers:
        - alertname = "Watchdog"
receivers:
  - name: "null"
  - name: telegram
    telegram_configs:
      - bot_token_file: /etc/alertmanager/secrets/alertmanager-telegram/bot_token
        chat_id: ${TELEGRAM_CHAT_ID}
        parse_mode: HTML
        send_resolved: true
inhibit_rules:
  - source_matchers:
      - severity = critical
    target_matchers:
      - severity =~ warning|info
    equal:
      - namespace
      - alertname
  - source_matchers:
      - severity = warning
    target_matchers:
      - severity = info
    equal:
      - namespace
      - alertname
  - source_matchers:
      - alertname = InfoInhibitor
    target_matchers:
      - severity = info
    equal:
      - namespace
  - target_matchers:
      - alertname = InfoInhibitor
EOF
# Double-quoted on purpose: the load() path has to be shell-expanded.
yq -i ".alertmanager.config = load(\"/${HOME}/${K8S_CONTEXT}/tmp/kps-alertmanager.yaml\")" /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
# <<< alertmanager-telegram
yq -i '.prometheusOperator.enabled=true' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml

mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
mkdir -p /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack

echo "[TASK] Create namespace"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

echo "[TASK] Create the grafana secret and update the manifest"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
read -s -p "Enter your grafana user: " GRAFANA_ADMIN_USER
read -s -p "Enter your grafana password: " GRAFANA_ADMIN_PASSWORD

sudo kubectl create secret generic "kube-prometheus-credentials" \
 --namespace "monitoring" \
 --from-literal=grafana_admin_user="${GRAFANA_ADMIN_USER}" \
 --from-literal=grafana_admin_password="${GRAFANA_ADMIN_PASSWORD}" \
 --dry-run=client -o yaml | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
 --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-credentials-sealed.yaml"

yq e -i '.grafana.admin.existingSecret = "kube-prometheus-credentials"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq e -i '.grafana.admin.userKey = "grafana_admin_user"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml
yq e -i '.grafana.admin.passwordKey = "grafana_admin_password"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml

echo "[TASK] Create helmrelease"
sudo flux create helmrelease kube-prometheus-stack \
  --interval=2h \
  --release-name=kube-prometheus-stack \
  --source=HelmRepository/prometheus-community \
  --chart-version=${PM_VER} \
  --chart=kube-prometheus-stack \
  --namespace=flux-system \
  --target-namespace=monitoring \
  --values=/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/charts/prometheus-community/kube-prometheus-stack-values.yaml \
  --create-target-namespace \
  --depends-on=flux-system/sealed-secrets \
  --export > /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml

echo "[TASK] Update namespace of prometheus community chart"
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml

echo "[TASK] Create the grafana certificate"
# cert-manager Certificates are namespace scoped, so the crypta-dev wildcard
# secret cannot be reused from here -- the monitoring namespace needs its own.
# letsencrypt-dns is the only issuer that can satisfy a wildcard (DNS-01).
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/grafana-certificate.yaml<<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: monitoring-wildcard
  namespace: monitoring
spec:
  secretName: monitoring-wildcard-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
    - "*.<REDACTED>"
    - <REDACTED>
EOF

echo "[TASK] Create the grafana ingress"
cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/grafana-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: traefik
  rules:
    - host: grafana.<REDACTED>
      http:
        paths:
          - backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - grafana.<REDACTED>
      secretName: monitoring-wildcard-tls
EOF

# >>> basicauth
echo "[TASK] Create basic auth for Prometheus and Alertmanager"
# Neither has a login of its own that the Prometheus Operator exposes, so the
# password prompt is Traefik's, in front of the ingress. Grafana keeps its own
# login and is not behind this.
read -s -p "Enter the Prometheus/Alertmanager basic auth user: " BASICAUTH_USER
echo
read -s -p "Enter the Prometheus/Alertmanager basic auth password: " BASICAUTH_PASS
echo
# Traefik's basicAuth middleware reads an htpasswd list from the `users` key.
# openssl's apr1 output is one of the formats Traefik accepts. Capture it into
# a variable first: the hash contains `$` and would be expanded by the shell if
# written inline inside double quotes.
BASICAUTH_USERS="${BASICAUTH_USER}:$(openssl passwd -apr1 "${BASICAUTH_PASS}")"
sudo kubectl create secret generic "monitoring-basicauth" \
  --namespace "monitoring" \
  --from-literal=users="${BASICAUTH_USERS}" \
  --dry-run=client -o yaml \
  | kubeseal --cert="/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/pub-sealed-secrets-${CLUSTER_NAME}.pem" \
  --format=yaml > "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/monitoring-basicauth.yaml.tmp" \
  && mv "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/monitoring-basicauth.yaml.tmp" "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/monitoring-basicauth.yaml"
if [ ! -s "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/monitoring-basicauth.yaml" ]; then
  echo "  - FAILED to seal monitoring-basicauth! Exiting before commit..."
  rm -f "/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/monitoring-basicauth.yaml.tmp"
  exit 1
fi

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/basicauth-middleware.yaml<<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basicauth
  namespace: monitoring
spec:
  basicAuth:
    secret: monitoring-basicauth
    removeHeader: true
EOF

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/prometheus-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    # Middleware refs are <namespace>-<name>@kubernetescrd. Cross-namespace
    # references are off in the Traefik values, so the middleware lives here.
    traefik.ingress.kubernetes.io/router.middlewares: monitoring-basicauth@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
    - host: prometheus.<REDACTED>
      http:
        paths:
          - backend:
              service:
                name: kube-prometheus-stack-prometheus
                port:
                  number: 9090
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - prometheus.<REDACTED>
      secretName: monitoring-wildcard-tls
EOF

cat>/${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/alertmanager-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager
  namespace: monitoring
  annotations:
    # Middleware refs are <namespace>-<name>@kubernetescrd. Cross-namespace
    # references are off in the Traefik values, so the middleware lives here.
    traefik.ingress.kubernetes.io/router.middlewares: monitoring-basicauth@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
    - host: alertmanager.<REDACTED>
      http:
        paths:
          - backend:
              service:
                name: kube-prometheus-stack-alertmanager
                port:
                  number: 9093
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - alertmanager.<REDACTED>
      secretName: monitoring-wildcard-tls
EOF
# <<< basicauth

echo "[TASK] Update kustomize"
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring/kube-prometheus-stack/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/monitoring
rm -f kustomization.yaml
kustomize create  --autodetect --recursive
cd /${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd ${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git status
git commit -am "kube-prometheus-stack deployment"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system"
sleep 10
while sudo flux get all -A | grep -q "Unknown" ; do
  echo "System not ready yet, waiting anoher 10 seconds"
  sleep 10
done

echo "COMPLETE"
