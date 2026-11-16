## Kubernetes v1.34.6 + containerd v2.1.7 + Cilium v1.19.3 (HA kubeadm) README + Script Update Plan

### Summary
Update [README.md](kubernetes/distributions/k8s/README.md) from legacy `v1.26`/Flannel instructions to a gated, official-doc-aligned install runbook for Ubuntu `26.04` across:
- `server1` `192.168.0.221`: worker-only, dedicated heavy workloads
- `server2` `192.168.0.222`: control-plane + worker
- `server3` `192.168.0.223`: control-plane + worker
- `server4` `192.168.0.224`: control-plane + worker

The runbook will use stacked-etcd HA kubeadm with a control-plane VIP endpoint, pinned `kubernetes v1.34.6`, pinned `containerd v2.1.7`, Cilium via CLI, and kube-proxy retained.

Version table (latest stable compatible set as of 2026-04-24):
K8S_VERSION=v1.34.6
CONTAINERD_VERSION=2.1.7
CILIUM_VERSION=v1.19.3
CILIUM_CLI_VERSION=v0.18.9
KUBE_VIP_VERSION=v1.1.2
RUNC_VERSION=v1.4.2
CNI_PLUGIN_VERSION=v1.9.1
CONTROL_PLANE_ENDPOINT=192.168.0.200:6443

### Why this version set aligns
- Kubernetes `v1.34.6` is the latest stable patch release in the explicitly tested `1.34` line for Cilium `v1.19.x`.
- Containerd `v2.1.7` is actively supported and recommended for Kubernetes `1.34` by containerd's Kubernetes support matrix.
- Cilium CLI `v0.18.9` is the current stable CLI and is compatible with Cilium `1.16+`.
- kube-vip `v1.1.2` is the latest stable release for API VIP ownership in this local HA topology.
- runc `v1.4.2` is current latest stable release (avoiding `v1.5.0-rc` pre-release line).
- CNI plugins `v1.9.1` is current latest stable.

### Implementation Changes (README content)
1. Replace deprecated install flow with current official repositories and commands.
- Remove `apt-key` + `apt.kubernetes.io` instructions.
- Add `pkgs.k8s.io/core:/stable:/v1.34` apt repo flow.
- Pin install to `kubeadm/kubelet/kubectl 1.34.6-*` and mark packages `hold`.
- Replace removed checks like `kubectl get cs` with `kubectl get nodes`, `kubectl get pods -A`, component health checks.

2. Container runtime section rewritten for pinned `containerd 2.1.7`.
- Install containerd from official `v2.1.7` release artifacts (tarball/service) and configure CRI with `SystemdCgroup=true`.
- Keep kernel modules/sysctl steps aligned with Kubernetes runtime docs.
- Add explicit runtime verification gate: `containerd --version`, `systemctl is-active containerd`, `crictl info`.
- Install pinned `runc v1.4.2` and CNI plugins `v1.9.1` from official release artifacts.

3. Topology and prerequisites section updated for HA control-plane.
- Add fixed node inventory and role matrix for `server1..server4`.
- Add prerequisite for stable `CONTROL_PLANE_ENDPOINT=192.168.0.200:6443` and connectivity check before `kubeadm init`.
- Use `kube-vip v1.1.2` for API VIP bootstrap ownership on control-plane nodes (not MetalLB).

4. Bootstrap flow changed to HA-safe order with milestone gates.
- Phase A (all nodes): OS prep, swap off, modules/sysctl, containerd install, kube tools install.
- Phase B (`server4` first CP): `kubeadm init --control-plane-endpoint 192.168.0.200:6443 --upload-certs --kubernetes-version v1.34.6`.
- Phase C (CNI): install Cilium (CLI, pinned version), keep kube-proxy.
- Phase D (`server3`,`server2`): join as control planes one at a time.
- Phase E (`server1`): join as worker.
- Phase F (placement policy): taint + label `server1` for dedicated heavy workloads.
- Each phase ends with explicit "do not proceed until checks pass" commands.

5. Networking section: replace Flannel with Cilium.
- Remove Flannel manifests and pod CIDR assumptions tied to Flannel.
- Add Cilium install/status checks (`cilium status`, `kubectl -n kube-system get pods`).
- Add post-install network validation and sample workload connectivity test.
- Clarify MetalLB is for post-bootstrap `Service type=LoadBalancer` only; kube-vip owns API endpoint bootstrap.

6. Script modernization scope included.
- Refactor `Install.sh`, `InstallServer.sh`, `InstallAgent.sh`, `setup.sh`, `joinMaster.sh`, `uninstall.sh`, and `uninstallAll.sh` to align with this plan.
- Use phased manual execution model with explicit gates (no single fire-and-forget orchestration path).
- Centralize node/version/endpoint/SSH settings into one sourced env/config file.

### Test Plan / Verification Gates (included as milestones in README)
1. Preflight gate (all nodes): hostname/IP/hosts consistency, time sync, SSH reachability, swap disabled, sysctl loaded.
2. Runtime gate: containerd service healthy and CRI responding on each node.
3. Kubernetes binaries gate: exact versions installed and held; `kubeadm version` matches target minor.
4. Control-plane bootstrap gate (`server4`): API reachable via `CONTROL_PLANE_ENDPOINT`, node `Ready`, core pods healthy.
5. CNI gate: Cilium DaemonSet healthy and no `NotReady` nodes due to networking.
6. Control-plane expansion gate: `server3` then `server2` join successfully; etcd/control-plane pods healthy across all CP nodes.
7. Worker gate (`server1`): joins and reaches `Ready`.
8. Scheduling policy gate: verify `server1` taint/label and confirm only tolerated workloads schedule there.
9. Stability gate (final): reboot one node at a time (including one control-plane), confirm cluster returns to healthy state each time.
10. Functional gate: deploy test app + service, verify east-west and node access behavior, then cleanup.

### Public Interfaces / Inputs in the new docs
- Required variables at top of README:
  - `K8S_VERSION=v1.34.6`
  - `CONTAINERD_VERSION=2.1.7`
  - `CILIUM_VERSION=v1.19.3`
  - `CILIUM_CLI_VERSION=v0.18.9`
  - `KUBE_VIP_VERSION=v1.1.2`
  - `RUNC_VERSION=v1.4.2`
  - `CNI_PLUGIN_VERSION=v1.9.1`
  - `CONTROL_PLANE_ENDPOINT=192.168.0.200:6443`
  - Node map (`server1..server4` IPs/roles)
- Join artifacts:
  - control-plane join command with certificate key
  - worker join command
- Node policy interface:
  - dedicated taint + label contract for `server1` and example workload toleration/nodeSelector usage.

### Assumptions and Defaults
- OS is fresh Ubuntu `26.04 LTS` on all 4 nodes with SSH already working.
- `CONTROL_PLANE_ENDPOINT=192.168.0.200:6443` is owned by `kube-vip` and fronts API traffic across control-plane nodes (`server4`,`server3`,`server2`).
- Cilium installed with CLI (pinned version), kube-proxy retained (not kube-proxy-free mode).
- Stacked etcd topology is used (no external etcd cluster).
- SSH access map from current machine:
  - `ssh -p 22001 server1@<REDACTED>`
  - `ssh -p 22002 server2@<REDACTED>`
  - `ssh -p 22003 server3@<REDACTED>`
  - `ssh -p 22004 server4@<REDACTED>`
- SSH access map from `server4` machine:
  - `ssh server1@192.168.0.221 -p 22001`
  - `ssh server2@192.168.0.222 -p 22002`
  - `ssh server3@192.168.0.223 -p 22003`
