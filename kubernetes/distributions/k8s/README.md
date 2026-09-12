# Kubernetes HA kubeadm on Ubuntu 26.04 (HAProxy + Keepalived + Cilium)

This runbook deploys a 4-node local cluster with stacked etcd, external API endpoint HA (HAProxy + Keepalived), and Cilium CNI.

## Pinned versions

```bash
K8S_VERSION=1.34.6
CONTAINERD_VERSION=2.1.7
CILIUM_VERSION=v1.19.3
CILIUM_CLI_VERSION=v0.18.9
KUBE_VIP_VERSION=v1.1.2
RUNC_VERSION=1.4.2
CNI_PLUGIN_VERSION=1.9.1
CONTROL_PLANE_ENDPOINT=192.168.0.220:6443
CONTROL_PLANE_VIP_IFACE=eno1
CONTROL_PLANE_HA_MODE=keepalived_haproxy
```

## Topology

- `server1` `192.168.0.221`: worker-only, dedicated heavy workloads
- `server2` `192.168.0.222`: control-plane + worker
- `server3` `192.168.0.223`: control-plane + worker
- `server4` `192.168.0.224`: first control-plane + worker

Bootstrap order:
- `server4` init first
- `server3` join control-plane
- `server2` join control-plane
- `server1` join worker

## SSH maps

From current machine:

```bash
ssh -p 22001 server1@<REDACTED>
ssh -p 22002 server2@<REDACTED>
ssh -p 22003 server3@<REDACTED>
ssh -p 22004 server4@<REDACTED>
```

From `server4`:

```bash
ssh server1@192.168.0.221 -p 22001
ssh server2@192.168.0.222 -p 22002
ssh server3@192.168.0.223 -p 22003
```

## Important model boundaries

- API endpoint `192.168.0.220:6443` is owned by Keepalived + HAProxy, not MetalLB.
- MetalLB is only for `Service type=LoadBalancer` after cluster bootstrap.
- `kube-proxy` is retained.
- This repo includes phased scripts; do not run them out of order.

## Prerequisites (all nodes)

- Fresh Ubuntu `26.04 LTS`
- Correct hostnames (`server1..server4`)
- Time sync healthy (`timedatectl status`)
- Passwordless sudo for the SSH users used above
- Layer-2 reachability on `192.168.0.0/24`
- Confirm VIP is free before bootstrap:

```bash
ping -c 2 192.168.0.220 || true
nc -vz 192.168.0.220 6443 || true
ip route | grep 192.168.0.0/24
ip -br a
```

## Phase A: Prepare every node

Option 1 (recommended wrapper):

```bash
cd kubernetes/distributions/k8s
chmod +x *.sh
./setup.sh prep-all
```

Option 2 (manual on each node):

```bash
sudo -E bash ~/k8s/Install.sh
```

Gate checks (all nodes):

```bash
swapon --show
containerd --version
systemctl is-active containerd
sudo crictl info >/dev/null && echo ok
kubeadm version -o short
apt-mark showhold | grep -E 'kubelet|kubeadm|kubectl'
```

Do not continue until all nodes pass.

## Phase A.1: Install HA endpoint services on control-plane nodes

From your control machine:

```bash
cd kubernetes/distributions/k8s
./setup.sh prep-ha
```

This installs and configures:
- `haproxy` listening on `:6443` and forwarding to `server4/server3/server2`
- `keepalived` managing VIP `192.168.0.220` on `eno1`

Gate checks:

```bash
nc -vz 192.168.0.220 6443
```

A `connection refused` is acceptable before API server starts; timeout/no-route is not.

## Phase B: Initialize first control-plane (`server4`)

```bash
cd ~/k8s
sudo -E bash ./InstallServer.sh
```

This phase:
- runs `kubeadm init --control-plane-endpoint 192.168.0.220:6443`
- generates join artifacts:
  - `~/k8s/join-control-plane.sh`
  - `~/k8s/join-worker.sh`

Gate checks (`server4`):

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes -o wide
kubectl get pods -A
curl -k https://192.168.0.220:6443/healthz
```

Do not continue until API endpoint is healthy.

## Phase C: Install Cilium (from `server4`)

Install Cilium CLI:

```bash
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then CLI_ARCH=amd64; else CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
```

Install Cilium:

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cilium install \
  --version ${CILIUM_VERSION} \
  --set kubeProxyReplacement=false \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true
```

Gate checks:

```bash
cilium status --wait
kubectl -n kube-system get pods -o wide
kubectl get nodes
```

Do not continue until Cilium is healthy and nodes are `Ready`.

## Phase D: Join additional control-planes (`server3`, then `server2`)

From current machine:

```bash
cd kubernetes/distributions/k8s
./setup.sh join-cp server3
./setup.sh join-cp server2
```

Or manual per node:

```bash
scp -P 22003 ~/git/devops-playground/kubernetes/distributions/k8s/join-control-plane.sh server3@192.168.0.223:~/k8s/
scp -P 22003 ~/git/devops-playground/kubernetes/distributions/k8s/join-worker.sh server3@192.168.0.223:~/k8s/
sudo -E bash ~/k8s/joinMaster.sh
```

Gate checks (`server4`):

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes -o wide
kubectl -n kube-system get pods -l tier=control-plane -o wide
kubectl -n kube-system get pods -l component=etcd -o wide
```

Do not continue until all three control-planes are healthy.

## Phase E: Join worker (`server1`)

From current machine:

```bash
cd kubernetes/distributions/k8s
./setup.sh join-worker server1
```

Or manual on `server1`:

```bash
scp -P 22001 ~/git/devops-playground/kubernetes/distributions/k8s/join-worker.sh server1@192.168.0.221:~/k8s/
sudo -E bash ~/k8s/InstallAgent.sh
```

Gate checks (`server4`):

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes -o wide
```

## Phase F: Dedicated heavy-workload placement on `server1`

Apply taint + label:

```bash
kubectl taint nodes server1 workload=heavy:NoSchedule
kubectl label nodes server1 workload=heavy
```

Example workload selector/toleration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: heavy-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: heavy-nginx
  template:
    metadata:
      labels:
        app: heavy-nginx
    spec:
      nodeSelector:
        workload: heavy
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "heavy"
        effect: "NoSchedule"
      containers:
      - name: nginx
        image: nginx:stable
```

## Functional validation

```bash
kubectl create deployment smoke --image=nginx:stable
kubectl expose deployment smoke --port 80 --type NodePort
kubectl get svc smoke -o wide
kubectl get pods -o wide
```

Test east-west and node access with returned NodePort from multiple nodes, then cleanup:

```bash
kubectl delete svc smoke
kubectl delete deployment smoke
```

## Stability validation (reboot gates)

Reboot one node at a time, wait for ready:

```bash
kubectl get nodes
kubectl get pods -A
cilium status
```

Include at least one control-plane reboot in this sequence.

## Script index

- `cluster.env`: shared versions/topology/SSH map
- `Install.sh`: all-node base prep
- `InstallApiEndpointHA.sh`: HAProxy + Keepalived API endpoint setup on control-plane nodes
- `InstallServer.sh`: primary control-plane init (`server4`)
- `joinMaster.sh`: additional control-plane join
- `InstallAgent.sh`: worker join
- `setup.sh`: phased wrapper
- `uninstall.sh`: local teardown
- `uninstallAll.sh`: remote teardown for all nodes

## Teardown

Single node:

```bash
sudo -E bash ./uninstall.sh
```

All nodes:

```bash
./uninstallAll.sh
```

