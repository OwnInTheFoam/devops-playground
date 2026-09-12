#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

LOG_FILE="${DIR}/uninstallAll.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }

node_user() {
  case "$1" in
    server1) echo "${SERVER1_USER}" ;;
    server2) echo "${SERVER2_USER}" ;;
    server3) echo "${SERVER3_USER}" ;;
    server4) echo "${SERVER4_USER}" ;;
  esac
}

node_port() {
  case "$1" in
    server1) echo "${SERVER1_PORT}" ;;
    server2) echo "${SERVER2_PORT}" ;;
    server3) echo "${SERVER3_PORT}" ;;
    server4) echo "${SERVER4_PORT}" ;;
  esac
}

task "Run uninstall.sh on all nodes via bastion map"
for node in "${ALL_NODES[@]}"; do
  user="$(node_user "${node}")"
  port="$(node_port "${node}")"
  log "[${node}] copy and run uninstall"
  run ssh -p "${port}" "${user}@${SSH_BASTION_IP}" "mkdir -p ~/k8s"
  run scp -P "${port}" "${DIR}/cluster.env" "${user}@${SSH_BASTION_IP}:~/k8s/cluster.env"
  run scp -P "${port}" "${DIR}/uninstall.sh" "${user}@${SSH_BASTION_IP}:~/k8s/uninstall.sh"
  run ssh -t -p "${port}" "${user}@${SSH_BASTION_IP}" "cd ~/k8s && sudo -E bash ./uninstall.sh"
done

log "uninstallAll.sh complete (details in ${LOG_FILE})"
