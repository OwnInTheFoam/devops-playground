#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

LOG_FILE="${DIR}/uninstall.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }
run_eval() { eval "$1" >>"${LOG_FILE}" 2>&1; }

ARCH=$(dpkg --print-architecture)

task "Reset kubeadm and remove Kubernetes state"
run kubeadm reset -f || true
run rm -rf /etc/cni/net.d /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/cni /var/run/kubernetes
run rm -rf "$HOME/.kube" /root/.kube

task "Remove Kubernetes packages"
run apt-get purge -y kubeadm kubelet kubectl kubernetes-cni || true
run apt-get autoremove -y || true
run rm -f /etc/apt/sources.list.d/kubernetes.list
run rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

task "Remove Cilium and kube-vip artifacts"
run rm -f /etc/kubernetes/manifests/kube-vip.yaml
run ip link delete cilium_host || true
run ip link delete cilium_net || true
run ip link delete cilium_vxlan || true
run_eval "iptables-save | grep -iv cilium | iptables-restore" || true
run_eval "ip6tables-save | grep -iv cilium | ip6tables-restore" || true

task "Remove HA endpoint services"
run systemctl stop keepalived || true
run systemctl disable keepalived || true
run systemctl stop haproxy || true
run systemctl disable haproxy || true
run apt-get purge -y keepalived haproxy || true
run rm -f /etc/keepalived/keepalived.conf /etc/haproxy/haproxy.cfg

task "Stop and remove containerd/runc/CNI"
run systemctl stop kubelet || true
run systemctl disable kubelet || true
run systemctl stop containerd || true
run systemctl disable containerd || true
run rm -f /usr/local/lib/systemd/system/containerd.service /etc/systemd/system/containerd.service
run systemctl daemon-reload
run rm -f /usr/local/sbin/runc
run rm -f /usr/local/bin/containerd /usr/local/bin/containerd-shim* /usr/local/bin/ctr
run rm -rf /etc/containerd /var/lib/containerd /run/containerd
run rm -rf /opt/cni/bin/*

task "Remove sysctl/modules changes"
run rm -f /etc/modules-load.d/k8s.conf
run rm -f /etc/sysctl.d/99-k8s.conf
run modprobe -r br_netfilter || true
run modprobe -r overlay || true
run sysctl --system || true

task "Clean temporary artifacts"
run rm -f "${DIR}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
run rm -f "${DIR}/runc.${ARCH}"
run rm -f "${DIR}/cni-plugins-linux-${ARCH}-v${CNI_PLUGIN_VERSION}.tgz"
run rm -f "${DIR}/crictl-v1.34.0-linux-${ARCH}.tar.gz"
run rm -f "${DIR}/join-worker.sh" "${DIR}/join-control-plane.sh" "${DIR}/kubeinit.log"

log "uninstall.sh complete (details in ${LOG_FILE})"
