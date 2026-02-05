#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_HELM="${REPO_ROOT}/tools/bin/helm-v3"
CHART="argo/argo-cd"
OUTPUT="${REPO_ROOT}/cluster/bootstrap/argocd/rendered.yaml"
SRC_VALUES="${REPO_ROOT}/apps/cluster/argocd/values.yaml"
VALUES="${REPO_ROOT}/cluster/bootstrap/argocd/values.yaml"
CHART_LOCK="${REPO_ROOT}/apps/cluster/argocd/Chart.lock"
CHART_YAML="${REPO_ROOT}/apps/cluster/argocd/Chart.yaml"

usage() {
  cat <<'EOF'
Usage: render-bootstrap-argocd.sh [--help]

Render the bootstrap ArgoCD manifest into cluster/bootstrap/argocd/rendered.yaml.

Requirements:
  - helm (preferred, via PATH) OR tools/bin/helm-v3 (see BIN_HELM in the script)
  - python3
EOF
}

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Unknown argument: ${1}" >&2
  usage >&2
  exit 1
fi

sync_values() {
  local tmp

  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' RETURN

  python3 - "$SRC_VALUES" "$tmp" <<'PY'
import sys

src, dest = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

if not lines or not lines[0].lstrip().startswith("argo-cd:"):
    raise SystemExit("expected first line to start with 'argo-cd:'")

with open(dest, "w", encoding="utf-8") as out:
    for line in lines[1:]:
        if line.startswith("  "):
            out.write(line[2:])
        else:
            out.write(line)
PY

  mv "${tmp}" "${VALUES}"
  echo "Synced ${SRC_VALUES} -> ${VALUES}"
}

resolve_version() {
  local version=""

  if [[ -f ${CHART_LOCK} ]]; then
    version="$(awk '
      $1=="-" && $2=="name:" {found=($3=="argo-cd")}
      found && $1=="version:" {gsub(/"/, "", $2); print $2; exit}
    ' "${CHART_LOCK}")"
  fi

  if [[ -z ${version} && -f ${CHART_YAML} ]]; then
    version="$(awk '
      $1=="-" && $2=="name:" {found=($3=="argo-cd")}
      found && $1=="version:" {gsub(/"/, "", $2); print $2; exit}
    ' "${CHART_YAML}")"
  fi

  if [[ -z ${version} ]]; then
    echo "Unable to determine argo-cd chart version from ${CHART_LOCK} or ${CHART_YAML}." >&2
    echo "Run 'helm dependency update apps/argocd/helm' or ensure Chart.yaml lists argo-cd." >&2
    exit 1
  fi

  echo "${version}"
}

VERSION="$(resolve_version)"

HELM_BIN=""

# Prefer a repo-local helm binary when available; otherwise use helm from PATH.
if [[ -x ${BIN_HELM} ]]; then
  HELM_BIN="${BIN_HELM}"
fi

if [[ -z ${HELM_BIN} ]]; then
  if command -v helm >/dev/null 2>&1; then
    HELM_BIN="$(command -v helm)"
  fi
fi

if [[ -z ${HELM_BIN} ]]; then
  echo "Helm is required. Install helm in PATH (preferred) or provide an executable at ${BIN_HELM}." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to sync bootstrap values." >&2
  exit 1
fi

"${HELM_BIN}" repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
"${HELM_BIN}" repo update >/dev/null 2>&1

sync_values

"${HELM_BIN}" template argocd "${CHART}" \
  --namespace argocd \
  --version "${VERSION}" \
  --include-crds \
  -f "${VALUES}" >"${OUTPUT}"

echo "Rendered ${OUTPUT}"
