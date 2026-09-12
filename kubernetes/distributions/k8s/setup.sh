#!/usr/bin/env bash
set -euo pipefail

# Phased wrapper for manual execution. It does not perform all actions in one call.
# Usage:
#   ./setup.sh prep-all
#   ./setup.sh prep-ha
#   ./setup.sh init-primary
#   ./setup.sh join-cp server3
#   ./setup.sh join-cp server2
#   ./setup.sh join-worker server1

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

ACTION="${1:-help}"
TARGET_NODE="${2:-}"

LOG_FILE="${DIR}/setup.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
)

# Connectivity mode:
# - bastion (default): user@${SSH_BASTION_IP} with per-node ssh ports.
# - local: user@<node-lan-ip> with per-node ssh ports.
CONNECT_MODE="${CONNECT_MODE:-bastion}"

node_ip() {
  case "$1" in
    server1) echo "${SERVER1_IP}" ;;
    server2) echo "${SERVER2_IP}" ;;
    server3) echo "${SERVER3_IP}" ;;
    server4) echo "${SERVER4_IP}" ;;
    *) echo "Unknown node: $1"; return 1 ;;
  esac
}

node_user() {
  case "$1" in
    server1) echo "${SERVER1_USER}" ;;
    server2) echo "${SERVER2_USER}" ;;
    server3) echo "${SERVER3_USER}" ;;
    server4) echo "${SERVER4_USER}" ;;
    *) echo "Unknown node: $1"; return 1 ;;
  esac
}

node_port() {
  case "$1" in
    server1) echo "${SERVER1_PORT}" ;;
    server2) echo "${SERVER2_PORT}" ;;
    server3) echo "${SERVER3_PORT}" ;;
    server4) echo "${SERVER4_PORT}" ;;
    *) echo "Unknown node: $1"; return 1 ;;
  esac
}

node_host() {
  local node="$1"
  if [[ "${CONNECT_MODE}" == "local" ]]; then
    node_ip "${node}"
  else
    echo "${SSH_BASTION_IP}"
  fi
}

copy_scripts() {
  local node="$1"
  local user port host
  user="$(node_user "${node}")"
  port="$(node_port "${node}")"
  host="$(node_host "${node}")"

  log "[${node}] copy scripts to ${user}@${host}:${port}"
  run ssh "${SSH_OPTS[@]}" -p "${port}" "${user}@${host}" "mkdir -p ~/k8s"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/cluster.env" "${user}@${host}:~/k8s/cluster.env"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/Install.sh" "${user}@${host}:~/k8s/Install.sh"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/InstallServer.sh" "${user}@${host}:~/k8s/InstallServer.sh"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/InstallApiEndpointHA.sh" "${user}@${host}:~/k8s/InstallApiEndpointHA.sh"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/joinMaster.sh" "${user}@${host}:~/k8s/joinMaster.sh"
  run scp -P "${port}" "${SSH_OPTS[@]}" "${DIR}/InstallAgent.sh" "${user}@${host}:~/k8s/InstallAgent.sh"
}

run_remote() {
  local node="$1"
  local cmd="$2"
  local user port host
  user="$(node_user "${node}")"
  port="$(node_port "${node}")"
  host="$(node_host "${node}")"

  log "[${node}] run: ${cmd}"
  run ssh -t "${SSH_OPTS[@]}" -p "${port}" "${user}@${host}" "${cmd}"
}

case "${ACTION}" in
  prep-all)
    task "Run setup phase A on all nodes (CONNECT_MODE=${CONNECT_MODE})"
    for node in "${ALL_NODES[@]}"; do
      copy_scripts "${node}"
      run_remote "${node}" "cd ~/k8s && sudo -E bash ./Install.sh"
    done
    ;;
  prep-ha)
    task "Install HA endpoint services (HAProxy + Keepalived) on control-plane nodes"
    for node in "${CONTROL_PLANE_NODES[@]}"; do
      copy_scripts "${node}"
      run_remote "${node}" "cd ~/k8s && sudo bash ./InstallApiEndpointHA.sh"
    done
    ;;
  init-primary)
    task "Run setup phase B on ${PRIMARY_CONTROL_PLANE}"
    copy_scripts "${PRIMARY_CONTROL_PLANE}"
    run_remote "${PRIMARY_CONTROL_PLANE}" "cd ~/k8s && sudo -E bash ./InstallServer.sh"
    ;;
  join-cp)
    if [[ -z "${TARGET_NODE}" ]]; then
      log "Usage: ./setup.sh join-cp <server3|server2>"
      exit 1
    fi
    task "Run setup phase D to join control-plane ${TARGET_NODE}"
    copy_scripts "${TARGET_NODE}"

    PRIMARY_USER="$(node_user "${PRIMARY_CONTROL_PLANE}")"
    PRIMARY_PORT="$(node_port "${PRIMARY_CONTROL_PLANE}")"
    PRIMARY_HOST="$(node_host "${PRIMARY_CONTROL_PLANE}")"
    TARGET_USER="$(node_user "${TARGET_NODE}")"
    TARGET_PORT="$(node_port "${TARGET_NODE}")"
    TARGET_HOST="$(node_host "${TARGET_NODE}")"

    run scp -P "${PRIMARY_PORT}" "${SSH_OPTS[@]}" "${PRIMARY_USER}@${PRIMARY_HOST}:~/k8s/join-control-plane.sh" "${DIR}/join-control-plane.sh"
    run scp -P "${PRIMARY_PORT}" "${SSH_OPTS[@]}" "${PRIMARY_USER}@${PRIMARY_HOST}:~/k8s/join-worker.sh" "${DIR}/join-worker.sh"
    run scp -P "${TARGET_PORT}" "${SSH_OPTS[@]}" "${DIR}/join-control-plane.sh" "${TARGET_USER}@${TARGET_HOST}:~/k8s/join-control-plane.sh"
    run scp -P "${TARGET_PORT}" "${SSH_OPTS[@]}" "${DIR}/join-worker.sh" "${TARGET_USER}@${TARGET_HOST}:~/k8s/join-worker.sh"
    run_remote "${TARGET_NODE}" "cd ~/k8s && sudo -E bash ./joinMaster.sh"
    ;;
  join-worker)
    if [[ -z "${TARGET_NODE}" ]]; then
      log "Usage: ./setup.sh join-worker <server1>"
      exit 1
    fi
    task "Run setup phase E to join worker ${TARGET_NODE}"
    copy_scripts "${TARGET_NODE}"

    PRIMARY_USER="$(node_user "${PRIMARY_CONTROL_PLANE}")"
    PRIMARY_PORT="$(node_port "${PRIMARY_CONTROL_PLANE}")"
    PRIMARY_HOST="$(node_host "${PRIMARY_CONTROL_PLANE}")"
    TARGET_USER="$(node_user "${TARGET_NODE}")"
    TARGET_PORT="$(node_port "${TARGET_NODE}")"
    TARGET_HOST="$(node_host "${TARGET_NODE}")"

    run scp -P "${PRIMARY_PORT}" "${SSH_OPTS[@]}" "${PRIMARY_USER}@${PRIMARY_HOST}:~/k8s/join-worker.sh" "${DIR}/join-worker.sh"
    run scp -P "${TARGET_PORT}" "${SSH_OPTS[@]}" "${DIR}/join-worker.sh" "${TARGET_USER}@${TARGET_HOST}:~/k8s/join-worker.sh"
    run_remote "${TARGET_NODE}" "cd ~/k8s && sudo -E bash ./InstallAgent.sh"
    ;;
  help|*)
    cat <<EOF | tee -a "${LOG_FILE}"
Usage:
  ./setup.sh prep-all
  ./setup.sh prep-ha
  ./setup.sh init-primary
  ./setup.sh join-cp server3
  ./setup.sh join-cp server2
  ./setup.sh join-worker server1
EOF
    ;;
esac
