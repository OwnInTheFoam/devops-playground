#!/bin/bash
# chmod u+x backup-dashboards.sh
# git add --chmod=+x backup-dashboards.sh
#
# Back up Grafana dashboards made in the UI into the gitops repo.
#
# A dashboard created or imported through the Grafana UI exists only in
# Grafana's SQLite database on its PVC. This exports each one as a ConfigMap
# labelled grafana_dashboard=1, which the dashboard sidecar loads back into
# Grafana -- so it survives losing the volume, is versioned in git, and comes
# back on a fresh install.
#
# What is exported:   dashboards with no provisioning file behind them (UI-made),
#                     plus every dashboard already backed up here (file under
#                     "Custom/") -- re-exported so UI edits are captured.
# What is skipped:    everything else that is provisioned: the chart's
#                     Kubernetes/Node dashboards and the Community folder, which
#                     are reproducible from the values in flux-install.sh.
# Deleting one:       provisioned dashboards cannot be deleted in the UI; remove
#                     its file from infra/common/monitoring/kube-prometheus-stack/
#                     dashboards/ and push. This script never deletes.
#
# Run it after creating or editing a dashboard. Safe to run any time.

# Requirements
# K8S_CONTEXT environment variable set as (sudo kubectl config get-contexts)
# kubectl, kustomize, git, yq, python3, curl

# DEFINES
CLUSTER_REPO=gitops
GRAFANA_NS=monitoring
GRAFANA_SVC=kube-prometheus-stack-grafana
GRAFANA_SECRET=kube-prometheus-credentials
LOCAL_PORT=13000
FOLDER=Custom

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO="${HOME}/${K8S_CONTEXT}/projects/${CLUSTER_REPO}"
OUT="${REPO}/infra/common/monitoring/kube-prometheus-stack/dashboards"
TMP="${HOME}/${K8S_CONTEXT}/tmp/dashboards"

echo "[CHECK] Required environment variables"
REQUIRED_VARS=("K8S_CONTEXT")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
    echo "  - $VAR is not set! Exiting..."
    exit 1
  else
    echo "  - $VAR is set. Value: ${!VAR}"
  fi
done

echo "[CHECK] Required packages installed"
REQUIRED_CMDS="kubectl kustomize git yq python3 curl"
for CMD in $REQUIRED_CMDS; do
  if ! command -v "$CMD" &> /dev/null; then
      echo "  - $CMD could not be found! Exiting..."
      exit 1
  fi
done

echo "[TASK] Read the Grafana admin credential from the cluster"
GRAFANA_USER=$(sudo kubectl -n "${GRAFANA_NS}" get secret "${GRAFANA_SECRET}" -o jsonpath='{.data.grafana_admin_user}' | base64 -d)
GRAFANA_PASS=$(sudo kubectl -n "${GRAFANA_NS}" get secret "${GRAFANA_SECRET}" -o jsonpath='{.data.grafana_admin_password}' | base64 -d)
if [[ -z "${GRAFANA_USER}" || -z "${GRAFANA_PASS}" ]]; then
  echo "  - could not read ${GRAFANA_SECRET}! Exiting..."
  exit 1
fi

echo "[TASK] Port-forward to Grafana"
sudo kubectl -n "${GRAFANA_NS}" port-forward "svc/${GRAFANA_SVC}" "${LOCAL_PORT}:80" >/dev/null 2>&1 &
# The port-forward runs under sudo, so it has to be stopped under sudo too.
trap 'sudo pkill -f "port-forward svc/${GRAFANA_SVC} ${LOCAL_PORT}:80" 2>/dev/null' EXIT
for i in $(seq 1 20); do
  curl -sf -m 3 "http://127.0.0.1:${LOCAL_PORT}/api/health" >/dev/null 2>&1 && break
  sleep 1
done
if ! curl -sf -m 3 "http://127.0.0.1:${LOCAL_PORT}/api/health" >/dev/null 2>&1; then
  echo "  - Grafana not reachable on the port-forward! Exiting..."
  exit 1
fi

echo "[TASK] Export dashboards"
mkdir -p "${OUT}" "${TMP}"
rm -f "${TMP}"/*.json
GRAFANA_URL="http://127.0.0.1:${LOCAL_PORT}" GRAFANA_USER="${GRAFANA_USER}" GRAFANA_PASS="${GRAFANA_PASS}" \
FOLDER="${FOLDER}" TMP="${TMP}" python3 - <<'PYEOF'
import os, json, re, base64, urllib.request

url, user, pw = os.environ["GRAFANA_URL"], os.environ["GRAFANA_USER"], os.environ["GRAFANA_PASS"]
folder, tmp = os.environ["FOLDER"], os.environ["TMP"]
auth = base64.b64encode(f"{user}:{pw}".encode()).decode()

def get(path):
    req = urllib.request.Request(url + path, headers={"Authorization": "Basic " + auth})
    return json.load(urllib.request.urlopen(req, timeout=20))

def slug(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return s[:60] or "dashboard"

exported = 0
for entry in get("/api/search?type=dash-db&limit=5000"):
    full = get("/api/dashboards/uid/" + entry["uid"])
    meta, dash = full["meta"], full["dashboard"]
    # meta.provisioned is NOT "came from a file" -- it is "locked against UI
    # edits", and goes false the moment a provider allows UI updates (ours
    # does). provisionedExternalId is the file path and is always set for a
    # file-backed dashboard: empty means made in the UI, a path under the
    # Custom folder means an earlier backup, anything else is the chart's.
    ext = meta.get("provisionedExternalId") or ""
    if ext and not ext.startswith(folder + "/"):
        continue  # chart / Community dashboards: reproducible from values
    # Instance state, not content: id is assigned on import, version is bumped
    # every time Grafana re-reads the file. Keeping either makes every run a
    # new commit with no real change.
    dash.pop("id", None)
    dash.pop("version", None)
    name = slug(dash.get("title", entry["uid"]))
    with open(os.path.join(tmp, name + ".json"), "w") as f:
        json.dump(dash, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f"  - {dash.get('title')}  ->  {name}.json")
    exported += 1
print(f"  {exported} dashboard(s) exported")
PYEOF

echo "[TASK] Write ConfigMaps"
shopt -s nullglob
for f in "${TMP}"/*.json; do
  name=$(basename "${f}" .json)
  # One ConfigMap per dashboard. The label is what the sidecar watches for; the
  # annotation is the Grafana folder it is filed under.
  sudo kubectl create configmap "grafana-dashboard-${name}" \
    --namespace "${GRAFANA_NS}" \
    --from-file="${name}.json=${f}" \
    --dry-run=client -o yaml \
    | yq '.metadata.labels.grafana_dashboard = "1" | .metadata.annotations.grafana_folder = "'"${FOLDER}"'"' \
    > "${OUT}/${name}.yaml"
done

echo "[TASK] Update kustomize"
cd "${REPO}/infra/common/monitoring/kube-prometheus-stack/"
rm -f kustomization.yaml
kustomize create --autodetect --recursive

echo "[TASK] Update git repository"
cd "${REPO}"
git add -A
git status --short -- infra/common/monitoring/kube-prometheus-stack/
if git diff --cached --quiet; then
  echo "  - nothing changed since the last backup"
  exit 0
fi
git commit -qm "grafana dashboards backup"
git push

echo "[TASK] Flux reconcile"
sudo flux reconcile source git "flux-system" >/dev/null 2>&1
sudo flux reconcile kustomization common >/dev/null 2>&1

echo "COMPLETE"
