#!/usr/bin/env sh

set -eu

# CI/pre-commit entrypoint for Ansible idempotency checks.
# Run the Go tool in-place (do not rely on an untracked compiled binary).

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root/tools/m0sh1-devops/scripts/check-idempotency"

exec go run . "$@"
