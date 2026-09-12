#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

if [[ ! -f "${DIR}/join-control-plane.sh" ]]; then
  echo "Missing ${DIR}/join-control-plane.sh. Run InstallServer.sh on ${PRIMARY_CONTROL_PLANE} first."
  exit 1
fi

LOG_FILE="${DIR}/joinMaster.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }
run_eval() { eval "$1" >>"${LOG_FILE}" 2>&1; }

run mkdir -p /etc/kubernetes/manifests

if [[ "${CONTROL_PLANE_HA_MODE}" == "kube-vip" ]]; then
  task "Ensure kube-vip manifest exists on joining control-plane"
  run ctr image pull "ghcr.io/kube-vip/kube-vip:${KUBE_VIP_VERSION}"
  run_eval "ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:${KUBE_VIP_VERSION} kvip /kube-vip manifest pod --interface ${CONTROL_PLANE_VIP_IFACE} --address ${CONTROL_PLANE_VIP} --controlplane --arp --leaderElection > /etc/kubernetes/manifests/kube-vip.yaml"
  run sed -i 's#/etc/kubernetes/admin.conf#/etc/kubernetes/super-admin.conf#g' /etc/kubernetes/manifests/kube-vip.yaml
  run sed -i 's#mountPath: /etc/kubernetes/super-admin.conf#mountPath: /.kube/config#g' /etc/kubernetes/manifests/kube-vip.yaml
fi

task "Join this node as control-plane"
run bash "${DIR}/join-control-plane.sh"

task "Verify control-plane status"
export KUBECONFIG=/etc/kubernetes/admin.conf
run kubectl get nodes -o wide

log "joinMaster.sh complete (details in ${LOG_FILE})"
