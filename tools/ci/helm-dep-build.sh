#!/usr/bin/env bash
set -euo pipefail

# helm-dep-build.sh — shared Helm dependency build logic
#
# Usage:
#   tools/ci/helm-dep-build.sh <chart_dir> [<chart_dir> ...]
#   tools/ci/helm-dep-build.sh --all
#   tools/ci/helm-dep-build.sh --update <chart_dir> [<chart_dir> ...]
#   tools/ci/helm-dep-build.sh --update --all
#
# Flags:
#   --all       Process all wrapper charts under apps/{cluster,user}/
#   --update    Use `helm dependency update` instead of `helm dependency build`
#   --quiet     Suppress per-chart output
#
# Behaviour:
#   1. Skip charts without Chart.lock (no deps)
#   2. Skip charts where all dependency archives already exist
#   3. Try --skip-refresh first; fall back to full refresh on cache miss

mode="build"
quiet=false
all=false
charts=()

while [ $# -gt 0 ]; do
    case "$1" in
        --update)  mode="update"; shift ;;
        --quiet)   quiet=true; shift ;;
        --all)     all=true; shift ;;
        *)         charts+=("${1%/}/"); shift ;;
    esac
done

if $all; then
    for chart in apps/cluster/*/ apps/user/*/; do
        [ -f "${chart}Chart.yaml" ] && charts+=("$chart")
    done
fi

if [ ${#charts[@]} -eq 0 ]; then
    echo "Usage: helm-dep-build.sh [--update] [--all] [chart_dir ...]" >&2
    exit 1
fi

# Check if a chart needs a dependency build.
needs_build() {
    local chart="$1"
    [ -f "${chart}Chart.lock" ] || return 1
    if [ ! -d "${chart}charts" ] || [ -z "$(ls -A "${chart}charts/" 2>/dev/null)" ]; then
        return 0
    fi
    local name version
    while IFS=$'\t' read -r name version; do
        [ -n "$name" ] || continue
        if [ ! -f "${chart}charts/${name}-${version}.tgz" ] && [ ! -d "${chart}charts/${name}" ]; then
            return 0
        fi
    done < <(helm dependency list "$chart" 2>/dev/null | awk 'NR > 1 && NF >= 2 {print $1 "\t" $2}')
    return 1
}

# Build or update a single chart with skip-refresh fallback.
dep_resolve() {
    local chart="$1"
    local cmd="helm dependency $mode"
    if ! $cmd --skip-refresh "$chart" >/dev/null 2>&1; then
        $quiet || echo "  cache miss for $chart — refreshing repos"
        $cmd "$chart" >/dev/null
    fi
}

built=0
skipped=0
for chart in "${charts[@]}"; do
    if needs_build "$chart"; then
        $quiet || echo "  dep $mode: $chart"
        dep_resolve "$chart"
        built=$((built + 1))
    else
        skipped=$((skipped + 1))
    fi
done

$quiet || echo "  done: ${built} built, ${skipped} skipped (up-to-date)"
