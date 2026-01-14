#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
Usage: tools/ci/k8s-lint.sh

Lint Helm charts, validate rendered manifests, and schema-check raw manifests.

Environment:
  K8S_LINT_KUBE_LINTER=0  Disable kube-linter on rendered output (default: 1).
EOF
  exit 0
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required." >&2
  exit 2
fi

if ! command -v kubeconform >/dev/null 2>&1; then
  echo "kubeconform is required." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

charts_list="$tmp_dir/charts.list"
for chart in apps/argocd/helm/ apps/cluster/*/ apps/user/*/; do
  if [ -f "${chart}Chart.yaml" ]; then
    printf '%s\n' "$chart" >>"$charts_list"
  fi
done

if [ ! -s "$charts_list" ]; then
  echo "No Helm charts found, skipping Helm lint and template validation."
else
  while IFS= read -r chart; do
    echo "Helm lint: $chart"
    helm lint "$chart"
  done <"$charts_list"

  while IFS= read -r chart; do
    name="$(basename "$chart")"
    out="$tmp_dir/${name}.yaml"
    echo "Helm template: $chart"
    helm template "$name" "$chart" --namespace "$name" --include-crds >"$out"

    echo "kubeconform: $out"
    kubeconform -strict -ignore-missing-schemas -summary "$out"

    if [ "${K8S_LINT_KUBE_LINTER:-1}" -eq 1 ]; then
      if command -v kube-linter >/dev/null 2>&1; then
        echo "kube-linter: $out"
        kube-linter lint --config tools/ci/kube-linter.yaml "$out"
      else
        echo "kube-linter not found, skipping."
      fi
    fi
  done <"$charts_list"
fi

raw_list="$tmp_dir/raw-files.list"
find apps/argocd/applications cluster/environments/lab \
  -type f \
  -name "*.yaml" \
  ! -path "apps/argocd/disabled/*" \
  ! -name "*.template.yaml" \
  -print0 \
  >"$raw_list"

if [ -s "$raw_list" ]; then
  echo "kubeconform: raw manifests"
  xargs -0 -r kubeconform -strict -ignore-missing-schemas -summary <"$raw_list"
else
  echo "No raw manifests found, skipping kubeconform."
fi
