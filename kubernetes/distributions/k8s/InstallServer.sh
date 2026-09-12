#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
# shellcheck disable=SC1091
source "${DIR}/cluster.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo -E bash ${0}"
  exit 1
fi

if [[ "${HOSTNAME}" != "${PRIMARY_CONTROL_PLANE}" ]]; then
  echo "This script must run on ${PRIMARY_CONTROL_PLANE}. Current host: ${HOSTNAME}"
  exit 1
fi

LOG_FILE="${DIR}/InstallServer.log"
TASK_NO=0

log() { echo "$1" | tee -a "${LOG_FILE}"; }
task() { TASK_NO=$((TASK_NO + 1)); log "[TASK ${TASK_NO}] $1"; }
run() { "$@" >>"${LOG_FILE}" 2>&1; }
run_eval() { eval "$1" >>"${LOG_FILE}" 2>&1; }
wait_for_containerd() {
  local retries=30
  local i
  for ((i = 1; i <= retries; i++)); do
    if systemctl is-active --quiet containerd && crictl info >>"${LOG_FILE}" 2>&1; then
      return 0
    fi
    log "Waiting for containerd/cri (${i}/${retries})..."
    sleep 2
  done
  return 1
}
wait_for_vip() {
  local retries=45
  local i
  for ((i = 1; i <= retries; i++)); do
    if ip -4 addr show dev "${CONTROL_PLANE_VIP_IFACE}" | grep -q "${CONTROL_PLANE_VIP}"; then
      return 0
    fi
    log "Waiting for VIP ${CONTROL_PLANE_VIP} on ${CONTROL_PLANE_VIP_IFACE} (${i}/${retries})..."
    sleep 2
  done
  return 1
}
wait_for_endpoint() {
  local endpoint_host endpoint_port retries i
  local nc_out
  endpoint_host="${CONTROL_PLANE_ENDPOINT%:*}"
  endpoint_port="${CONTROL_PLANE_ENDPOINT##*:}"
  retries=45
  for ((i = 1; i <= retries; i++)); do
    nc_out="$(nc -vz -w 2 "${endpoint_host}" "${endpoint_port}" 2>&1 || true)"
    echo "${nc_out}" >>"${LOG_FILE}"
    # Pre-bootstrap, "Connection refused" is acceptable (endpoint is routable but API not up yet).
    if echo "${nc_out}" | grep -qiE "succeeded|open|refused"; then
      return 0
    fi
    log "Waiting for endpoint ${CONTROL_PLANE_ENDPOINT} (${i}/${retries})..."
    sleep 2
  done
  return 1
}

run mkdir -p "${K8S_WORKDIR}"
run mkdir -p /etc/kubernetes/manifests

task "Ensure containerd and kubelet are running"
run systemctl enable --now containerd
run systemctl enable --now kubelet
if ! wait_for_containerd; then
  log "containerd or CRI is not ready. See ${LOG_FILE}"
  exit 1
fi

if [[ "${CONTROL_PLANE_HA_MODE}" == "kube-vip" ]]; then
  task "Generate kube-vip manifest for bootstrap API VIP"
  run ctr image pull "ghcr.io/kube-vip/kube-vip:${KUBE_VIP_VERSION}"
  run_eval "ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:${KUBE_VIP_VERSION} kvip /kube-vip manifest pod --interface ${CONTROL_PLANE_VIP_IFACE} --address ${CONTROL_PLANE_VIP} --controlplane --arp --leaderElection > /etc/kubernetes/manifests/kube-vip.yaml"
  # Kubernetes 1.29+ bootstrap: kube-vip must use super-admin.conf and mount it as /.kube/config.
  run sed -i 's#/etc/kubernetes/admin.conf#/etc/kubernetes/super-admin.conf#g' /etc/kubernetes/manifests/kube-vip.yaml
  run sed -i 's#mountPath: /etc/kubernetes/super-admin.conf#mountPath: /.kube/config#g' /etc/kubernetes/manifests/kube-vip.yaml
  run test -s /etc/kubernetes/manifests/kube-vip.yaml
  run systemctl restart kubelet

  task "Validate kube-vip static pod manifest is present"
  run ls -l /etc/kubernetes/manifests/kube-vip.yaml
else
  task "Validate external HA endpoint ${CONTROL_PLANE_ENDPOINT}"
  if ! wait_for_endpoint; then
    log "Endpoint ${CONTROL_PLANE_ENDPOINT} not reachable. Run InstallApiEndpointHA.sh on control-plane nodes first."
    exit 1
  fi
fi

task "Pull kubeadm images"
run kubeadm config images pull --kubernetes-version "v${K8S_VERSION}"

task "Initialize primary control-plane"
run_eval "kubeadm init --control-plane-endpoint ${CONTROL_PLANE_ENDPOINT} --upload-certs --kubernetes-version v${K8S_VERSION} --pod-network-cidr 10.244.0.0/16 | tee ${DIR}/kubeinit.log"

task "Configure kubeconfig"
run mkdir -p "$HOME/.kube"
run cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
run chown "$(id -u):$(id -g)" "$HOME/.kube/config"
export KUBECONFIG=/etc/kubernetes/admin.conf

task "Generate join artifacts"
run_eval "kubeadm token create --print-join-command >${DIR}/join-worker.sh"
CERT_KEY="$(kubeadm init phase upload-certs --upload-certs 2>>"${LOG_FILE}" | tail -n 1)"
echo "$(cat "${DIR}/join-worker.sh") --control-plane --certificate-key ${CERT_KEY}" >"${DIR}/join-control-plane.sh"
chmod +x "${DIR}/join-worker.sh" "${DIR}/join-control-plane.sh"

task "Endpoint and control-plane gate checks"
if [[ "${CONTROL_PLANE_HA_MODE}" == "kube-vip" ]]; then
  run crictl ps -a --name kube-vip
  if ! wait_for_vip; then
    log "VIP ${CONTROL_PLANE_VIP} did not bind on ${CONTROL_PLANE_VIP_IFACE}. See ${LOG_FILE}"
    exit 1
  fi
  run ip -4 addr show dev "${CONTROL_PLANE_VIP_IFACE}"
fi
run kubectl get nodes -o wide
run kubectl get pods -A
run curl -k --max-time 10 "https://${CONTROL_PLANE_ENDPOINT}/healthz"

log "InstallServer.sh complete (details in ${LOG_FILE})"
