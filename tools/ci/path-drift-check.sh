#!/usr/bin/env sh

set -eu

## tools/ci/path-drift-check.sh

##

## Guardrails

## 1) Enforce a top-level allowlist (repo skeleton contract)

## 2) Block forbidden top-level dirs (secrets/, tooling/)

## 3) Detect deprecated path references from the old repo layout

##

## Notes

## - This script is intentionally strict to keep the repo public-safe

## - Update the ALLOWLIST when you intentionally add new top-level entries

## - When you update the allowlist, also update docs/layout.md

if ! command -v rg >/dev/null 2>&1; then
    echo "ERROR: rg (ripgrep) is required." >&2
    exit 2
fi

fail=0

die() {
    echo "$*" >&2
    fail=1
}

## Prefer staged paths (pre-commit), otherwise use tracked files (CI)

if git diff --cached --name-only >/dev/null 2>&1; then
    changed="$(git diff --cached --name-only)"
    if [ -z "${changed}" ]; then
        changed="$(git ls-files)"
    fi
else
    changed="$(git ls-files)"
fi

## ---------------------------

## 1) Top-level allowlist

## ---------------------------

## Allowed top-level entries (dirs and files)

## Keep this aligned with docs/layout.md

ALLOWLIST_RE='^(ansible/?|apps/?|argocd/?|cluster/?|docs/?|terraform/?|tools/?|memory-bank/?|\.gitea/?|\.github/?|\.vscode/?|\.devcontainer/?|\.contextstream/?|\.editorconfig|\.envrc|\.gitattributes|\.gitignore|\.pre-commit-config\.yaml|\.rumdl\.toml|\.yamllint|\.dcignore|\.kube-linter\.yaml|AGENTS\.md|CODEOWNERS|README\.md|SECURITY\.md|WARP\.md|cliff\.toml|config\.yaml|config\.yaml\.example|mise\.toml|renovate\.json|.sonarlint/?)$'

## Determine top-level entries touched (or tracked if nothing staged)

top_level="$(printf '%s\n' "$changed" | rg -U -o '^[^/]+/?' | rg -v '^\.$' | sort -u)"

## If a top-level entry is not allowlisted, fail

printf '%s\n' "$top_level" | while IFS= read -r entry; do

    ## Normalize directories to include trailing slash

    case "$entry" in
        */) norm="$entry" ;;
        *) norm="$entry" ;;
    esac

    ## Special-case: if "foo/" is listed, "foo" won't appear; and vice-versa

    ## So we check both representations

    if ! printf '%s\n' "$norm" | rg -q "$ALLOWLIST_RE"; then

        # try without trailing slash

        no_slash="$(printf '%s' "$norm" | sed 's:/$::')"
        if ! printf '%s\n' "$no_slash" | rg -q "$ALLOWLIST_RE"; then
            die "❌ New top-level entry not allowed: $no_slash
            If intentional: update tools/ci/path-drift-check.sh allowlist AND docs/layout.md"
        fi
    fi
done

## ---------------------------

## 2) Forbidden top-level dirs

## ---------------------------

if printf '%s\n' "$top_level" | rg -q '^secrets/?$'; then
    die "❌ Forbidden top-level directory tracked: secrets/"
fi
if printf '%s\n' "$top_level" | rg -q '^tooling/?$'; then
    die "❌ Forbidden top-level directory tracked: tooling/"
fi

## ---------------------------

## 3) Deprecated references scan

## ---------------------------

## Only scan tracked/changed files, and exclude this script (otherwise it self-matches)

## Also skip docs/history.md because it may intentionally mention old paths

scan_glob_args="--glob !tools/ci/path-drift-check.sh --glob !docs/history.md"

check_ref() {
    label="$1"
    pattern="$2"
    if ! printf '%s\n' "$changed" | rg -n "$pattern" "$scan_glob_args" >/dev/null 2>&1; then
        return 0
    fi

    echo "❌ Found deprecated repo references: $label" >&2
    printf '%s\n' "$changed" | rg -n "$pattern" "$scan_glob_args" >&2 || true
    fail=1
}

## Old layout fragments that should not reappear

check_ref "old apps/argocd tree (migrated to top-level argocd/)" '^apps/argocd/'
check_ref "old apps/*/helm wrapper root (no longer used)" '^apps/[^/]+/helm/'
check_ref "old disabled location (migrated to argocd/disabled/)" '^apps/argocd/disabled/'
check_ref "forbidden top-level secrets directory" '(^|[^a-zA-Z0-9_/.-])secrets/'
check_ref "forbidden top-level tooling directory" '(^|[^a-zA-Z0-9_/.-])tooling/'
check_ref "ansible/op.env (do not keep env files in repo)" '(^|[^a-zA-Z0-9_/.-])ansible/op\.env($|[^a-zA-Z0-9_.-])'
check_ref "terraform/op.env (do not keep env files in repo)" '(^|[^a-zA-Z0-9_/.-])terraform/op\.env($|[^a-zA-Z0-9_.-])'
check_ref "legacy apps/(cluster|user)/secrets/ directories" '^apps/(cluster|user)/secrets/'

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "path-drift-check: ok"
