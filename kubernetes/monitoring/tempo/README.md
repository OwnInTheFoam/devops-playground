# [Tempo](https://github.com/grafana/tempo)

Distributed tracing backend, single binary mode. Receives OTLP from
application SDKs and from [Beyla](../beyla/README.md), and is queried through
Grafana (the datasource is provisioned by
[kube-prometheus-stack](../kube-prometheus-stack/README.md)).

## Resources

- Chart: `grafana/tempo`
- Version: `1.24.4` (app `2.9.0`) — matches the AWS qa cluster
- Namespace: `monitoring`

## Requirements

- FluxCD, kustomize, git, helm, yq
- sealed secrets
- Persistent storage (longhorn)
- `kube-prometheus-stack` installed first, for the `ServiceMonitor` CRD

## Installation

```bash
export K8S_CONTEXT=<context>
./flux-install.sh
```

Non-default values the script sets:

| Value | Why |
|---|---|
| `persistence.enabled=true`, `storageClassName=longhorn`, `size=10Gi` | Chart default is off — without it the trace store is lost on every restart |
| `tempo.retention=168h` | Chart default is `24h`, too short to debug anything from yesterday |
| `serviceMonitor.enabled=true` | Chart default is off, so Tempo would not be scraped |

Storage backend needs no override: the chart already defaults to `local` at
`/var/tempo/traces`, which is what the PVC above backs.

## Endpoints

| Port | Protocol |
|---|---|
| 4317 | OTLP gRPC |
| 4318 | OTLP HTTP |
| 3200 | Prometheus metrics / Grafana datasource |

Applications send to `tempo.monitoring.svc.cluster.local:4317`.

## Uninstallation

```bash
./flux-uninstall.sh
```
