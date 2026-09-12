#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

LOG_FILE="${DIR}/InstallApiEndpointHA.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }

if [[ "${CONTROL_PLANE_HA_MODE}" != "keepalived_haproxy" ]]; then
  log "Skipping: CONTROL_PLANE_HA_MODE=${CONTROL_PLANE_HA_MODE}"
  exit 0
fi

NODE_IP=""
PRIORITY=""
STATE="BACKUP"
ROUTER_ID="51"
PEERS=""
NODE_TAG=""

case "${HOSTNAME}" in
  server4)
    NODE_IP="${SERVER4_IP}"; PRIORITY="130"; STATE="MASTER"; NODE_TAG="S4"
    PEERS="${SERVER3_IP}
    ${SERVER2_IP}" ;;
  server3)
    NODE_IP="${SERVER3_IP}"; PRIORITY="120"; NODE_TAG="S3"
    PEERS="${SERVER4_IP}
    ${SERVER2_IP}" ;;
  server2)
    NODE_IP="${SERVER2_IP}"; PRIORITY="110"; NODE_TAG="S2"
    PEERS="${SERVER4_IP}
    ${SERVER3_IP}" ;;
  *)
    log "This script is for control-plane nodes server4/server3/server2 only."
    exit 1 ;;
esac

task "Install HAProxy and Keepalived"
run apt-get update -y
run apt-get install -y haproxy keepalived

task "Enable nonlocal bind for VIP listener"
cat >/etc/sysctl.d/99-k8s-ha.conf <<EOF
net.ipv4.ip_nonlocal_bind = 1
EOF
run sysctl --system

task "Configure HAProxy for kube-apiserver endpoint"
cat >/etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log local0
  log /dev/log local1 notice

defaults
  mode tcp
  log global
  option tcplog
  timeout connect 5s
  timeout client  60s
  timeout server  60s

frontend kube-apiserver
  bind ${CONTROL_PLANE_VIP}:6443
  default_backend kube-apiserver-nodes

backend kube-apiserver-nodes
  mode tcp
  option tcp-check
  balance roundrobin
  server server4 ${SERVER4_IP}:6443 check
  server server3 ${SERVER3_IP}:6443 check
  server server2 ${SERVER2_IP}:6443 check
EOF

run systemctl enable --now haproxy
run systemctl restart haproxy

task "Configure Keepalived for VIP failover"
cat >/etc/keepalived/keepalived.conf <<EOF
global_defs {
  router_id K8S_${NODE_TAG}
  enable_script_security
}

vrrp_script chk_haproxy {
  script "/usr/bin/pidof haproxy"
  interval 2
  weight -20
}

vrrp_instance VI_1 {
  state ${STATE}
  interface ${CONTROL_PLANE_VIP_IFACE}
  virtual_router_id ${ROUTER_ID}
  priority ${PRIORITY}
  advert_int 1
  nopreempt
  unicast_src_ip ${NODE_IP}
  unicast_peer {
${PEERS}
  }
  authentication {
    auth_type PASS
    auth_pass k8sha220
  }
  virtual_ipaddress {
    ${CONTROL_PLANE_VIP}/24 dev ${CONTROL_PLANE_VIP_IFACE}
  }
  track_script {
    chk_haproxy
  }
}
EOF

run systemctl enable --now keepalived
run systemctl restart keepalived

task "Endpoint HA verification"
run systemctl is-active haproxy
run systemctl is-active keepalived
run ip -4 addr show dev "${CONTROL_PLANE_VIP_IFACE}"

if [[ "${HOSTNAME}" == "server4" ]]; then
  # On bootstrap node, VIP should typically be here first.
  if ip -4 addr show dev "${CONTROL_PLANE_VIP_IFACE}" | grep -q "${CONTROL_PLANE_VIP}"; then
    log "VIP ${CONTROL_PLANE_VIP} is present on ${HOSTNAME}."
  else
    log "VIP ${CONTROL_PLANE_VIP} is not currently on ${HOSTNAME}; check keepalived on all CP nodes."
  fi
fi

log "InstallApiEndpointHA.sh complete (details in ${LOG_FILE})"
