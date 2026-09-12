# Monitoring

The observability stack, installed by Flux into the `monitoring` namespace.
Versions are pinned to match the AWS qa cluster (`dev-grafana-ns`) so the two
environments behave the same way.

| Component | Chart | Version | What it gives you |
|---|---|---|---|
| [kube-prometheus-stack](kube-prometheus-stack/) | `prometheus-community/kube-prometheus-stack` | `83.4.0` | Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter |
| [loki](loki/) | `grafana/loki-stack` | `2.10.3` | Log store + promtail shippers |
| [tempo](tempo/) | `grafana/tempo` | `1.24.4` | Trace store (OTLP) |
| ~~[beyla](beyla/)~~ | `grafana/beyla` | ~~`1.16.11`~~ | **REMOVED 2026-09-12 — panics the kernel. See [beyla/README.md](beyla/README.md)** |

[prometheus/](prometheus/) is the older standalone install and is superseded by
kube-prometheus-stack.

## Install order

Order matters:

1. **kube-prometheus-stack** — everything else creates `ServiceMonitor`
   resources, so its CRDs have to exist first.
2. **loki**
3. **tempo**

```bash
export K8S_CONTEXT=<context>
./kube-prometheus-stack/flux-install.sh
./loki/flux-install.sh
./tempo/flux-install.sh
```

## Access

Grafana is published through Traefik at `https://grafana.<REDACTED>`, which
resolves to the MetalLB address `192.168.0.240` and is therefore reachable only
on the tailnet. Its admin credential is a sealed secret created during install.

Loki and Tempo are wired in as Grafana datasources by the kube-prometheus-stack
script, so logs, metrics and traces are all queryable from that one Grafana.

## Dashboards

Everything in the `Community` folder and the chart's Kubernetes/Node set is
provisioned from values and comes back by itself. Anything you build in the UI
does not — run `kube-prometheus-stack/backup-dashboards.sh` after making or
editing one; it commits the dashboard to the gitops repo and the sidecar loads
it into a `Custom` folder. Details in
[kube-prometheus-stack/README.md](kube-prometheus-stack/README.md#dashboard-backups).

## Control-plane metrics are not scraped

etcd, kube-scheduler, kube-controller-manager and kube-proxy all bind their
metrics endpoints to `127.0.0.1` on this cluster, so Prometheus cannot reach
them from a pod. Their scrape targets and default alert rules are disabled — the
alternative is four alerts that fire forever. Enabling them means editing the
kubeadm manifests on the nodes, which is outside what gitops controls here.

## Storage

Everything that keeps state does so on `longhorn`:

| Component | Size |
|---|---|
| Prometheus | 5Gi |
| Grafana | 5Gi |
| Alertmanager | 1Gi |
| Loki | 10Gi |
| Tempo | 10Gi |
