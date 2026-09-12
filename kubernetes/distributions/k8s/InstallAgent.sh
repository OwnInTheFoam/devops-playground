#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

if [[ ! -f "${DIR}/join-worker.sh" ]]; then
  echo "Missing ${DIR}/join-worker.sh. Run InstallServer.sh on ${PRIMARY_CONTROL_PLANE} first."
  exit 1
fi

LOG_FILE="${DIR}/InstallAgent.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }

task "Join worker node"
run bash "${DIR}/join-worker.sh"

task "Verify kubelet readiness"
run systemctl is-active kubelet

log "InstallAgent.sh complete (details in ${LOG_FILE})"
