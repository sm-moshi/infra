#!/bin/sh
set -eu

show_help() {
  cat <<'EOF'
Usage: tools/ci/ansible-idempotency.sh [--require-checker] [--strict] [--summary] <playbook...>

Runs the idempotency checker if present at:
  tools/m0sh1-devops/scripts/check_idempotency.py

Default behavior:
  - If the checker is missing, the hook SKIPS (exit 0).
  - If no playbooks are passed, it checks ansible/playbooks/*.yml|*.yaml.

Options:
  --require-checker  Fail if the checker script is missing
  --strict           Passed through to the checker
  --summary          Passed through to the checker
  -h, --help         Show this help message
EOF
}

require_checker=0

case "${1:-}" in
-h | --help)
  show_help
  exit 0
  ;;
esac

if [ "${1:-}" = "--require-checker" ]; then
  require_checker=1
  shift
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required." >&2
  exit 1
fi

checker="tools/m0sh1-devops/scripts/check_idempotency.py"

if [ ! -f "$checker" ]; then
  if [ "$require_checker" -eq 1 ]; then
    echo "ERROR: checker script not found at ${checker}" >&2
    exit 1
  fi
  echo "ansible-idempotency: checker not present (${checker}); skipping."
  exit 0
fi

# If playbooks were provided, run directly
if [ "$#" -gt 0 ]; then
  exec python3 "$checker" "$@"
fi

# Otherwise gather playbooks automatically
if [ ! -d "ansible/playbooks" ]; then
  echo "ansible-idempotency: no ansible/playbooks directory found; skipping."
  exit 0
fi

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

find ansible/playbooks -type f \( -name "*.yml" -o -name "*.yaml" \) -print >"$tmp_list"

if [ ! -s "$tmp_list" ]; then
  echo "ansible-idempotency: no Ansible playbooks found; skipping."
  exit 0
fi

set --
while IFS= read -r path; do
  [ -n "$path" ] || continue
  set -- "$@" "$path"
done <"$tmp_list"

exec python3 "$checker" "$@"
