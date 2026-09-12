> **DO NOT INSTALL. Beyla panics the kernel on this cluster.**
>
> Beyla `3.32.0` (chart `1.16.11`) crashed every node within two days of being
> installed — server2, server4, server1 (twice) and server3 (twice), with the
> display frozen. The kdump on server1 (`/var/crash/202609121053`) shows why:
>
> ```
> BUG: kernel NULL pointer dereference, address: 0000000000000021
> Comm: longhorn    7.0.0-31-generic
> RIP: bpf_prog_..._obi_protocol_tcp+0x5d19
> Call Trace: __uprobe_perf_func -> uprobe_dispatcher -> handle_swbp
> ```
>
> Beyla auto-instruments every Go process on the node with uprobes. Longhorn's
> binaries are Go. One of them trips a NULL dereference inside Beyla's eBPF TCP
> parser, in kernel mode, and the node dies. Removed 2026-09-12 with
> `flux-uninstall.sh`; the scripts are kept only as a record. Do not run
> `flux-install.sh` on kernel 7.0 without a Beyla release that fixes this.

# [Beyla](https://github.com/grafana/beyla)

eBPF auto-instrumentation. Derives RED metrics and traces for HTTP/gRPC traffic
without touching application code — which is the point here, because most
workloads on this cluster expose no metrics endpoint and emit no spans of their
own.

Metrics are scraped by Prometheus; traces are exported to
[Tempo](../tempo/README.md).

## Resources

- Chart: `grafana/beyla`
- Version: `1.16.11` (app `3.32.0`)
- Namespace: `monitoring`

> **Version caveat.** The other three components in this directory are pinned to
> the versions the AWS qa cluster runs. Beyla is the exception: it runs on qa but
> appears in no manifest repository, and the `discovery/capture-live-20260830`
> capture did not include DaemonSets, so its version there is unknown. `1.16.11`
> is simply the current release. To reconcile:
>
> ```bash
> kubectl -n dev-grafana-ns get ds beyla -o jsonpath='{.metadata.labels.helm\.sh/chart}'
> ```

## Requirements

- FluxCD, kustomize, git, helm, yq
- sealed secrets
- `kube-prometheus-stack` installed first, for the `ServiceMonitor` CRD
- `tempo` installed first — Beyla's trace exporter points at it

## Privileged workload

This is a **privileged DaemonSet on every node**, running with
`privileged: true` and `dnsPolicy: ClusterFirstWithHostNet`. eBPF cannot attach
without it. Both are chart defaults and the install script deliberately leaves
them alone.

## Installation

```bash
export K8S_CONTEXT=<context>
./flux-install.sh
```

Non-default values the script sets:

| Value | Why |
|---|---|
| `serviceMonitor.enabled=true` | Chart default is off, so Beyla's metrics would never be scraped |
| `config.data.otel_traces_export.endpoint` | Chart ships no exporter target; without it spans are generated and dropped |
| `preset=application` | Already the default; set explicitly so the choice is visible |

## Verifying

```bash
kubectl -n monitoring get ds beyla
```

Then in Grafana, query `beyla_http_request_duration_seconds_count` — a non-empty
result means Beyla is instrumenting traffic.

## Uninstallation

```bash
./flux-uninstall.sh
```
