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
  K8S_LINT_PARALLEL=4         Max parallel dep builds (default: 4)
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

# ── Smart dependency resolution ────────────────────────────────────────
# Returns 0 (true) when the chart needs `helm dep build`, 1 when it can
# be skipped.  Criteria:
#   1. No Chart.lock → no deps declared, skip
#   2. charts/ missing or empty → must fetch
#   3. Chart.yaml newer than Chart.lock → dep version bumped
needs_dep_build() {
    local chart="$1"
    # No lock file means no dependencies to manage
    [ -f "${chart}Chart.lock" ] || return 1
    # charts/ dir missing or empty → need to fetch tarballs
    if [ ! -d "${chart}charts" ] || [ -z "$(ls -A "${chart}charts/" 2>/dev/null)" ]; then
        return 0
    fi
    # Chart.yaml modified after lock was generated → dep version bumped
    [ "${chart}Chart.yaml" -nt "${chart}Chart.lock" ] && return 0
    return 1  # charts/ populated and lock is current — skip
}

# ── Changed-charts detection ──────────────────────────────────────────
changed_charts() {
    local base="${K8S_LINT_BASE:-main}"
    local merge_base
    merge_base="$(git merge-base HEAD "origin/$base" 2>/dev/null \
               || git merge-base HEAD "$base" 2>/dev/null \
               || echo "HEAD~1")"

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

# ── Phase 2: smart dependency build ──────────────────────────────────
echo ""
echo "=== Phase 2: dependency build (smart) ==="
dep_list="$tmp_dir/deps.list"
skipped=0
while IFS= read -r chart; do
    if needs_dep_build "$chart"; then
        printf '%s\n' "$chart" >> "$dep_list"
    else
        skipped=$((skipped + 1))
    fi
done < "$charts_list"

if [ -s "$dep_list" 2>/dev/null ]; then
    need="$(wc -l < "$dep_list" | tr -d ' ')"
    echo "  building: ${need} chart(s), skipped: ${skipped} (already up-to-date)"
    parallel="${K8S_LINT_PARALLEL:-4}"
    # Use helm dep build (deterministic from Chart.lock) instead of helm dep update
    xargs -P "$parallel" -I{} sh -c 'echo "  dep build: {}"; helm dependency build "{}" >/dev/null' < "$dep_list"
else
    echo "  all ${skipped} chart(s) up-to-date — no dependency builds needed"
fi

# ── Phase 3: template + kubeconform + kube-linter ────────────────────
echo ""
echo "=== Phase 3: template + validate ==="
while IFS= read -r chart; do
    name="$(basename "$chart")"
    out="$tmp_dir/${name}.yaml"

    echo "  template: $chart"
    helm template "$name" "$chart" --namespace "$name" --include-crds > "$out"

    echo "  kubeconform: $name"
    kubeconform -strict -ignore-missing-schemas -summary "$out"

    if [ "${K8S_LINT_KUBE_LINTER:-1}" -eq 1 ]; then
        if command -v kube-linter >/dev/null 2>&1; then
            echo "  kube-linter: $name"
            kube-linter lint --config tools/ci/kube-linter.yaml "$out"
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
    xargs -0 -r kubeconform -strict -ignore-missing-schemas -summary < "$raw_list"
else
    echo "  no raw manifests found, skipping"
fi

echo ""
echo "=== All checks passed ==="
