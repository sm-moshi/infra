#!/usr/bin/env sh
set -eu

# Path drift guard:
# - Enforces top-level allowlist for tracked paths (staged if present, else all tracked).
# - Rejects tracked top-level forbidden dirs (secrets/, tooling/).
# - Scans tracked/changed files for deprecated references (excluding this script).

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: rg (ripgrep) is required." >&2
  exit 2
fi

fail=0

is_allowed_top_level() {
  case "$1" in
  ansible | apps | certs | cluster | docs | terraform | tools) return 0 ;;
  .github | .gitea | .vscode) return 0 ;;
  .editorconfig | .envrc | .gitattributes | .gitignore | .pre-commit-config.yaml | .rumdl.toml | .yamllint | .dcignore) return 0 ;;
  AGENTS.md | CHANGELOG.md | CODEOWNERS | README.md | SECURITY.md) return 0 ;;
  cliff.toml | config.yaml | config.yaml.example | devfile.yaml | mise.toml | renovate.json) return 0 ;;
  *) return 1 ;;
  esac
}

# Prefer staged paths; fallback to all tracked paths
changed="$(git diff --cached --name-only --diff-filter=ACMR || true)"
if [ -z "$changed" ]; then
  changed="$(git ls-files)"
fi

# ---- Top-level allowlist (guard rail) ----
printf '%s\n' "$changed" |
  awk -F/ 'NF{print $1}' |
  sort -u |
  while IFS= read -r top; do
    [ -n "$top" ] || continue
    if ! is_allowed_top_level "$top"; then
      echo "❌ New top-level entry not allowed: $top" >&2
      echo "   If intentional, add it to tools/ci/path-drift-check.sh AND update docs/layout.md" >&2
      fail=1
    fi
  done

# ---- Forbidden top-level dirs if TRACKED ----
if printf '%s\n' "$changed" | rg -q '^secrets/'; then
  echo "❌ Forbidden tracked top-level directory: secrets/" >&2
  fail=1
fi

if printf '%s\n' "$changed" | rg -q '^tooling/'; then
  echo "❌ Forbidden tracked top-level directory: tooling/" >&2
  fail=1
fi

# ---- Deprecated references scan (TRACKED FILES ONLY) ----
# We scan the set of tracked/changed files for deprecated path references.
# IMPORTANT: exclude this script itself to avoid self-matches.
scan_files="$(printf '%s\n' "$changed" | rg -v '^tools/ci/path-drift-check\.sh$' || true)"

if [ -n "$scan_files" ]; then
  # shellcheck disable=SC2086
  bad_refs="$(printf '%s\n' "$scan_files" |
    rg -n \
      --glob '!.git/**' \
      --glob '!**/.terraform/**' \
      --glob '!**/terraform.tfstate*' \
      --glob '!docs/archive/**' \
      -S \
      '(?m)(^|[^a-zA-Z0-9_/.-])(tooling/|secrets/)' \
      -- $scan_files || true)"

  if [ -n "$bad_refs" ]; then
    echo "❌ Found deprecated repo references:" >&2
    printf '%s\n' "$bad_refs" >&2
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "path-drift-check: ok"
