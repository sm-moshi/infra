#!/usr/bin/env sh

set -eu

# CI/pre-commit entrypoint for the sensitive files policy.
# This repo intentionally does not track compiled guard binaries; run the Go tool in-place.

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root/tools/m0sh1-devops/scripts/sensitive-files-guard"

exec go run .
