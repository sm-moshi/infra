#!/usr/bin/env sh

set -eu

if ! command -v rg >/dev/null 2>&1; then
    echo "ERROR: rg (ripgrep) is required." >&2
    exit 2
fi

fail=0

die() {
    echo "$*" >&2
    fail=1
}

apps_root="argocd/apps/apps-root.yaml"

if [ ! -f "$apps_root" ]; then
    die "ERROR: Missing required root application manifest: $apps_root"
else
    if ! rg -q '^  project: root$' "$apps_root"; then
        die "ERROR: apps-root must use ArgoCD project 'root': $apps_root"
    fi

    if ! rg -q '^    automated:$' "$apps_root"; then
        die "ERROR: apps-root must declare automated syncPolicy: $apps_root"
    fi

    if ! rg -q '^      prune: true$' "$apps_root"; then
        die "ERROR: apps-root must declare syncPolicy.automated.prune=true: $apps_root"
    fi

    if ! rg -q '^      selfHeal: true$' "$apps_root"; then
        die "ERROR: apps-root must declare syncPolicy.automated.selfHeal=true: $apps_root"
    fi
fi

if [ -f "argocd/apps/bootstrap-root.yaml" ]; then
    die "ERROR: bootstrap-root must not live under argocd/apps/. Keep it under argocd/disabled/ for recovery-only use."
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "argocd-root-guard: ok"
