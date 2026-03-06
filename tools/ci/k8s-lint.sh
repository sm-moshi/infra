#!/usr/bin/env bash
set -euo pipefail

# ── Early --help (before dependency checks) ───────────────────────────
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<'EOF'
Usage: tools/ci/k8s-lint.sh [OPTIONS] [CHART_DIR ...]

Lint Helm charts, validate rendered manifests, and schema-check raw manifests.

Modes:
  (no args)                   Lint all charts under apps/{cluster,user}/
  --changed                   Lint only charts with files changed vs base branch
  apps/cluster/foo/ [...]     Lint specific chart directories

Options:
  --changed                   Diff-based targeting (vs K8S_LINT_BASE, default: main)
  -h, --help                  Show this help

Environment:
  K8S_LINT_KUBE_LINTER=0      Disable kube-linter (default: 1)
  K8S_LINT_BASE=main          Base branch for --changed mode (default: main)
EOF
            exit 0
            ;;
    esac
done

# ── Dependency checks ──────────────────────────────────────────────────
for cmd in helm kubeconform fd; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd is required (see mise install)." >&2
        exit 2
    fi
done

# ── Temp dir ───────────────────────────────────────────────────────────
tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

# ── Shared dep helper path ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DEP_BUILD="${SCRIPT_DIR}/helm-dep-build.sh"

# ── Changed-charts detection ──────────────────────────────────────────
changed_charts() {
    local base="${K8S_LINT_BASE:-main}"
    local merge_base

    # Ensure we have the base branch ref in shallow clones, if possible
    if ! git rev-parse --verify "origin/$base" >/dev/null 2>&1; then
        git fetch --depth=50 origin "$base" >/dev/null 2>&1 || true
    fi

    if merge_base="$(git merge-base HEAD "origin/$base" 2>/dev/null)" && [ -n "$merge_base" ]; then
        :
    elif merge_base="$(git merge-base HEAD "$base" 2>/dev/null)" && [ -n "$merge_base" ]; then
        :
    else
        # No suitable merge-base (e.g. very shallow clone) — lint all charts
        all_charts
        return 0
    fi
    git diff --name-only "${merge_base}...HEAD" -- 'apps/cluster/' 'apps/user/' \
        | sed -n 's|\(apps/\(cluster\|user\)/[^/]*/\).*|\1|p' \
        | sort -u \
        | while IFS= read -r dir; do
            [ -f "${dir}Chart.yaml" ] && printf '%s\n' "$dir"
          done
}

# ── Collect chart list ────────────────────────────────────────────────
all_charts() {
    for chart in apps/cluster/*/ apps/user/*/; do
        [ -f "${chart}Chart.yaml" ] && printf '%s\n' "$chart"
    done
}

# ── Parse arguments ──────────────────────────────────────────────────
mode="all"
explicit_charts=()

while [ $# -gt 0 ]; do
    case "$1" in
        --changed)   mode="changed"; shift ;;
        *)
            # Normalise: strip trailing slash then re-add for consistency
            dir="${1%/}/"
            if [ ! -f "${dir}Chart.yaml" ]; then
                echo "Error: ${dir}Chart.yaml not found" >&2
                exit 1
            fi
            explicit_charts+=("$dir")
            shift
            ;;
    esac
done

charts_list="$tmp_dir/charts.list"

case "$mode" in
    changed)
        changed_charts > "$charts_list"
        count="$(wc -l < "$charts_list" | tr -d ' ')"
        echo "==> --changed: ${count} chart(s) to lint"
        ;;
    all)
        if [ ${#explicit_charts[@]} -gt 0 ]; then
            printf '%s\n' "${explicit_charts[@]}" > "$charts_list"
        else
            all_charts > "$charts_list"
        fi
        ;;
esac

if [ ! -s "$charts_list" ]; then
    echo "No Helm charts to lint."
    exit 0
fi

# ── Phase 1: helm lint (local, fast) ──────────────────────────────────
echo ""
echo "=== Phase 1: helm lint ==="
fail=0
while IFS= read -r chart; do
    echo "  lint: $chart"
    helm lint "$chart" || fail=1
done < "$charts_list"
[ "$fail" -eq 0 ] || { echo "helm lint failed" >&2; exit 1; }

# ── Auto-register missing Helm repos ─────────────────────────────────
# Charts using traditional (https://) repos need them registered locally
# before `helm dep build` can resolve Chart.lock references.
ensure_helm_repos() {
    local known_urls
    # Collect registered repo URLs (normalised: no trailing slash)
    known_urls="$(helm repo list -o json 2>/dev/null \
        | grep -o '"url":"[^"]*"' \
        | sed 's/"url":"//;s/"//;s|/$||' \
        | sort -u)"

    local did_add=0
    while IFS= read -r chart; do
        awk '/^[[:space:]]*repository:/{gsub(/^[[:space:]]*repository:[[:space:]]*/,""); if(/^https:\/\//) print}' \
            "${chart}Chart.yaml" 2>/dev/null \
        | while IFS= read -r url; do
            # Normalise: strip trailing slash for comparison
            local norm_url="${url%/}"
            if echo "$known_urls" | grep -qxF "$norm_url"; then
                continue
            fi
            local name
            name="$(echo "$url" | sed 's|https://||;s|/.*||;s|\.|-|g')"
            if helm repo list 2>/dev/null | awk '{print $1}' | grep -qxF "$name"; then
                name="${name}-auto"
            fi
            echo "  auto-add repo: $name → $url"
            helm repo add "$name" "$url" >/dev/null 2>&1 || true
        done
    done < "$charts_list"
}

ensure_helm_repos

# ── Phase 2: smart dependency build ──────────────────────────────────
echo ""
echo "=== Phase 2: dependency build (smart) ==="
mapfile -t dep_charts < "$charts_list"
"$HELM_DEP_BUILD" "${dep_charts[@]}"

# ── Phase 3: template + kubeconform + kube-linter ────────────────────
echo ""
echo "=== Phase 3: template + validate ==="
while IFS= read -r chart; do
    name="$(basename "$chart")"
    out="$tmp_dir/${name}.yaml"

    echo "  template: $chart"
    helm template \
        "$name" "$chart" \
        --namespace "$name" \
        --include-crds \
        --api-versions monitoring.coreos.com/v1 \
        > "$out"

    echo "  kubeconform: $name"
    kubeconform -strict -ignore-missing-schemas -summary "$out"

    if [ "${K8S_LINT_KUBE_LINTER:-1}" -eq 1 ]; then
        if command -v kube-linter >/dev/null 2>&1; then
            echo "  kube-linter: $name"
            kube-linter lint --config tools/ci/kube-linter.yaml "$out"
        else
            echo "  kube-linter: not found, skipping (set K8S_LINT_KUBE_LINTER=0 to disable)"
        fi
    fi
done < "$charts_list"

# ── Phase 4: raw manifest validation (ArgoCD apps, etc.) ────────────
echo ""
echo "=== Phase 4: raw manifests ==="
raw_list="$tmp_dir/raw-files.list"
fd --type f --extension yaml \
    --exclude "argocd/disabled" \
    --exclude "*.template.yaml" \
    --search-path argocd/apps \
    --search-path cluster/environments/lab \
    --print0 \
    > "$raw_list" 2>/dev/null || true

if [ -s "$raw_list" ]; then
    echo "  kubeconform: raw manifests"
    xargs -0 kubeconform -strict -ignore-missing-schemas -summary < "$raw_list"
else
    echo "  no raw manifests found, skipping"
fi

echo ""
echo "=== All checks passed ==="
