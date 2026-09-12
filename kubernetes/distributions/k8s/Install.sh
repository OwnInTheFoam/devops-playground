#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

LOG_FILE="${DIR}/Install.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }
run_eval() { eval "$1" >>"${LOG_FILE}" 2>&1; }
wait_for_apt_lock() {
  local retries=60
  local sleep_s=5
  local i
  for ((i = 1; i <= retries; i++)); do
    if ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
       ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
       ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
      return 0
    fi
    log "Waiting for apt/dpkg lock (${i}/${retries})..."
    sleep "${sleep_s}"
  done
  log "Timed out waiting for apt/dpkg lock."
  return 1
}
apt_run() {
  wait_for_apt_lock
  run "$@"
}

ARCH=$(dpkg --print-architecture)
case "${ARCH}" in
  amd64|arm64) ;;
  *) log "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

task "Install required OS packages"
apt_run apt-get update -y
apt_run apt-get install -y ca-certificates curl wget gpg apt-transport-https socat conntrack jq

task "Disable swap"
run swapoff -a
run sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

task "Load kernel modules and sysctl"
cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
run modprobe overlay
run modprobe br_netfilter

cat >/etc/sysctl.d/99-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
run sysctl --system

task "Configure UFW and required ports"
run ufw --force enable
run ufw allow OpenSSH
run ufw allow 6443/tcp
run ufw allow 2379:2380/tcp
run ufw allow 10250/tcp
run ufw allow 10257/tcp
run ufw allow 10259/tcp
run ufw allow 30000:32767/tcp
run ufw allow in proto udp from 192.168.0.0/24 to any port 8472
run ufw allow in proto udp from 192.168.0.0/24 to any port 51871
run ufw allow in proto udp from 192.168.0.0/24 to any port 51820
# Pods on THIS node reaching hostNetwork services on it (node-exporter :9100,
# kubelet, etc.) enter the host stack via the pod's lxc* veth and hit ufw's
# default deny -- traffic from other nodes arrives on eno1 where Cilium's BPF
# serves it before netfilter, which is why only same-node scrapes failed.
# 10.244.0.0/16 is the --pod-network-cidr given to kubeadm init below.
run ufw allow in from 10.244.0.0/16

if [[ -n "${CONTROL_PLANE_VIP_IFACE}" ]]; then
  run ufw allow in on "${CONTROL_PLANE_VIP_IFACE}" to "${CONTROL_PLANE_VIP}" proto tcp port 6443
fi

if [[ "${HOSTNAME}" == "server1" ]]; then
  run ufw allow "${SERVER1_PORT}/tcp"
elif [[ "${HOSTNAME}" == "server2" ]]; then
  run ufw allow "${SERVER2_PORT}/tcp"
elif [[ "${HOSTNAME}" == "server3" ]]; then
  run ufw allow "${SERVER3_PORT}/tcp"
elif [[ "${HOSTNAME}" == "server4" ]]; then
  run ufw allow "${SERVER4_PORT}/tcp"
fi
run ufw status verbose

task "Install containerd ${CONTAINERD_VERSION}"
cd "${DIR}"
CONTAINERD_TGZ="containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
run wget -q --show-progress "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_TGZ}"
run tar Cxzvf /usr/local "${CONTAINERD_TGZ}"
run mkdir -p /usr/local/lib/systemd/system
run curl -fsSL "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" -o /usr/local/lib/systemd/system/containerd.service

task "Install runc ${RUNC_VERSION}"
run wget -q --show-progress "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}"
run install -m 755 "runc.${ARCH}" /usr/local/sbin/runc

task "Install CNI plugins ${CNI_PLUGIN_VERSION}"
CNI_TGZ="cni-plugins-linux-${ARCH}-v${CNI_PLUGIN_VERSION}.tgz"
run wget -q --show-progress "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGIN_VERSION}/${CNI_TGZ}"
run mkdir -p /opt/cni/bin
run tar Cxzvf /opt/cni/bin "${CNI_TGZ}"

task "Configure and start containerd"
run mkdir -p /etc/containerd
run_eval "containerd config default >/etc/containerd/config.toml"
run sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
run systemctl daemon-reload
run systemctl enable --now containerd

task "Add Kubernetes apt repository (pkgs.k8s.io v1.34)"
run mkdir -p -m 755 /etc/apt/keyrings
run_eval "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
run chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat >/etc/apt/sources.list.d/kubernetes.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
EOF

apt_run apt-get update -y
KUBE_PKG_VERSION="$(apt-cache madison kubeadm 2>>"${LOG_FILE}" | awk -v v="${K8S_VERSION}" '$3 ~ v {print $3; exit}')"
if [[ -z "${KUBE_PKG_VERSION}" ]]; then
  log "Unable to resolve kube package version for ${K8S_VERSION}. See ${LOG_FILE}"
  exit 1
fi
apt_run apt-get install -y "kubelet=${KUBE_PKG_VERSION}" "kubeadm=${KUBE_PKG_VERSION}" "kubectl=${KUBE_PKG_VERSION}"
run apt-mark hold kubelet kubeadm kubectl
run systemctl enable kubelet

task "Install crictl"
CRICTL_VERSION="v1.34.0"
CRICTL_TGZ="crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz"
run wget -q --show-progress "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/${CRICTL_TGZ}"
run tar Cxzvf /usr/local/bin "${CRICTL_TGZ}"
cat >/etc/crictl.yaml <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

task "Update /etc/hosts"
run_eval "grep -q '${SERVER1_IP} server1' /etc/hosts || echo '${SERVER1_IP} server1' >>/etc/hosts"
run_eval "grep -q '${SERVER2_IP} server2' /etc/hosts || echo '${SERVER2_IP} server2' >>/etc/hosts"
run_eval "grep -q '${SERVER3_IP} server3' /etc/hosts || echo '${SERVER3_IP} server3' >>/etc/hosts"
run_eval "grep -q '${SERVER4_IP} server4' /etc/hosts || echo '${SERVER4_IP} server4' >>/etc/hosts"
run_eval "grep -q '${CONTROL_PLANE_VIP} k8s-api' /etc/hosts || echo '${CONTROL_PLANE_VIP} k8s-api' >>/etc/hosts"

task "Runtime and version gate checks"
run containerd --version
run systemctl is-active containerd
run crictl info
run kubeadm version -o short
run kubelet --version
run kubectl version --client

log "Install.sh complete (details in ${LOG_FILE})"
