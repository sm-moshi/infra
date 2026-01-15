#!/usr/bin/env bash
# Download Prometheus Operator CRDs for a specific version
# Usage: ./download-crds.sh [version]
# Example: ./download-crds.sh v0.87.1

set -euo pipefail

VERSION="${1:-v0.87.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRDS_DIR="${SCRIPT_DIR}/crds"
BASE_URL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${VERSION}/example/prometheus-operator-crd"

echo "==> Downloading Prometheus Operator CRDs version ${VERSION}"
mkdir -p "${CRDS_DIR}"

CRDS=(
    "monitoring.coreos.com_alertmanagerconfigs"
    "monitoring.coreos.com_alertmanagers"
    "monitoring.coreos.com_podmonitors"
    "monitoring.coreos.com_probes"
    "monitoring.coreos.com_prometheusagents"
    "monitoring.coreos.com_prometheuses"
    "monitoring.coreos.com_prometheusrules"
    "monitoring.coreos.com_scrapeconfigs"
    "monitoring.coreos.com_servicemonitors"
    "monitoring.coreos.com_thanosrulers"
)

for crd in "${CRDS[@]}"; do
    filename="crd-${crd#monitoring.coreos.com_}.yaml"
    url="${BASE_URL}/${crd}.yaml"
    echo "  Downloading ${filename}..."
    if curl -fsSL -o "${CRDS_DIR}/${filename}" "${url}"; then
        echo "    ✓ ${filename}"
    else
        echo "    ✗ Failed to download ${filename}" >&2
        exit 1
    fi
done

echo "==> Successfully downloaded CRDs to ${CRDS_DIR}"
echo ""
echo "Next steps:"
echo "  1. Update apps/cluster/prometheus-crds/Chart.yaml with version ${VERSION}"
echo "  2. Bump chart version in Chart.yaml"
echo "  3. Commit changes: git add apps/cluster/prometheus-crds/"
echo "  4. Deploy before upgrading kube-prometheus-stack"
