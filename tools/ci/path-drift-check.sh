#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
Usage: tools/ci/path-drift-check.sh

Checks for references to deprecated or moved paths that commonly drift in docs and configs.

Current checks:
  - apps/*/helm/ references (except apps/argocd/helm/)
  - top-level secrets/ directory existence
  - top-level tooling/ directory existence
  - tooling/ references (excluding docs/history.md)
  - ansible/op.env references
  - apps/(cluster|user)/secrets/ references (excluding docs/history.md)
EOF
  exit 0
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) is required for path drift checks." >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

fail=0

check() {
  name="$1"
  pattern="$2"
  exclude_regex="$3"
  shift 3

  matches="$(rg -n --hidden \
    --glob "!.git/**" \
    --glob "!**/.terraform/**" \
    --glob "!**/terraform.tfstate*" \
    --glob "!tools/ci/path-drift-check.sh" \
    "$@" \
    "$pattern" "$ROOT" || true)"

  if [ -n "$exclude_regex" ] && [ -n "$matches" ]; then
    matches="$(printf '%s\n' "$matches" | rg -v "$exclude_regex" || true)"
  fi

  if [ -n "$matches" ]; then
    echo "Found ${name} references:" >&2
    echo "$matches" >&2
    fail=1
  fi
}

check_dir() {
  name="$1"
  path="$2"

  if [ -e "$path" ]; then
    echo "Found ${name} at ${path}" >&2
    fail=1
  fi
}

check_dir "top-level secrets directory (forbidden)" "${ROOT}/secrets"
check_dir "top-level tooling directory (forbidden)" "${ROOT}/tooling"

check "legacy chart paths" "apps/[^[:space:]]+/helm/" "apps/argocd/helm/" --glob "!docs/history.md"
check "tooling path" "tooling/" "" --glob "!docs/history.md"
check "ansible op.env path" "ansible/op.env" ""
check "legacy k8s secrets paths" "apps/(cluster|user)/secrets/" "" --glob "!docs/history.md"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "path-drift-check: ok"
