#!/bin/sh
set -eu

show_help() {
    cat <<'EOF'
Usage: tools/ci/sensitive-files-check.sh [--all-files|--staged|--working-tree]
                                         [--pattern REGEX] [--ignore REGEX]

Detects filenames/paths that should never be committed to a public infra repo:
- env files (op.env, .env*)
- terraform state / secrets tfvars
- kubeconfigs
- private keys / pkcs12 bundles
- known repo-specific forbidden files (config.yaml)

Defaults:
  - If staged changes exist, scan staged files only.
  - Else if working tree changes exist, scan those.
  - Else scan tracked files (git ls-files).

Options:
  --all-files      Scan all tracked files (git ls-files)
  --staged         Scan staged files only (git diff --cached)
  --working-tree   Scan working tree changes only (git diff)
  --pattern REGEX  Override default match regex (extended, case-insensitive)
  --ignore REGEX   Skip matches that also match this regex (case-insensitive)
  -h, --help       Show this help

Environment:
  SENSITIVE_FILES_PATTERN  Default regex override
  SENSITIVE_FILES_IGNORE   Ignore regex override
EOF
}

mode=""
pattern="${SENSITIVE_FILES_PATTERN:-}"
ignore="${SENSITIVE_FILES_IGNORE:-}"

while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    --all-files)
        mode="all"
        shift
        ;;
    --staged)
        mode="staged"
        shift
        ;;
    --working-tree)
        mode="work"
        shift
        ;;
    --pattern)
        [ "$#" -ge 2 ] || {
            echo "ERROR: --pattern requires a value" >&2
            exit 1
        }
        pattern="$2"
        shift 2
        ;;
    --ignore)
        [ "$#" -ge 2 ] || {
            echo "ERROR: --ignore requires a value" >&2
            exit 1
        }
        ignore="$2"
        shift 2
        ;;
    *)
        echo "ERROR: Unknown argument: $1" >&2
        show_help >&2
        exit 1
        ;;
    esac
done

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Not a git repository, skipping."
    exit 0
fi

# Default match pattern: filename/path based.
# Keep this strict; false-positives are acceptable for infra policy enforcement.
if [ -z "$pattern" ]; then
    pattern='(^|/)(config\.yaml)$''|(^|/)(ansible|terraform)/op\.env$''|(^|/)\.env([._-].*)?$''|(^|/)(kubeconfig)(\..*)?$''|(^|/).*id_(rsa|ed25519)(\..*)?$''|(^|/).*authorized_keys$''|(^|/).*known_hosts$''|(^|/).*\.p12$|(^|/).*\.pfx$''|(^|/).*\.key$''|(^|/).*privkey.*\.pem$|(^|/).*private.*\.pem$''|(^|/).*terraform\.tfstate(\..*)?$''|(^|/).*\.tfstate\..*$''|(^|/).*secrets\.auto\.tfvars$''|(^|/).*\.tfvars$''|(^|/).*-(unsealed)\.ya?ml$|(^|/).*unsealed.*\.ya?ml$'
fi

# Default ignore pattern: allow sealed-secrets ciphertext and known-safe areas.
if [ -z "$ignore" ]; then
    ignore='(^|/)apps/cluster/sealed-secrets/''|(^|/)apps/cluster/secrets-cluster/''|(^|/)apps/argocd/applications/cluster/(sealed-secrets|secrets-cluster)\.ya?ml$''|\.sealedsecret\.ya?ml$''|(^|/)docs/archive/''|(^|/)apps/.*/charts/''|(^|/)apps/.*/Chart\.lock$''|(^|/)apps/.*/templates/.*\.template\.ya?ml$'
fi

list_cmd=""
case "$mode" in
all)
    list_cmd="git ls-files"
    ;;
staged)
    list_cmd="git diff --cached --name-only --diff-filter=ACMR"
    ;;
work)
    list_cmd="git diff --name-only --diff-filter=ACMR"
    ;;
"")
    staged_count=$(git diff --cached --name-only --diff-filter=ACMR | wc -l | tr -d ' ')
    if [ "$staged_count" -gt 0 ]; then
        list_cmd="git diff --cached --name-only --diff-filter=ACMR"
    else
        work_count=$(git diff --name-only --diff-filter=ACMR | wc -l | tr -d ' ')
        if [ "$work_count" -gt 0 ]; then
            list_cmd="git diff --name-only --diff-filter=ACMR"
        else
            list_cmd="git ls-files"
        fi
    fi
    ;;
*)
    echo "ERROR: Unknown mode: $mode" >&2
    exit 1
    ;;
esac

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

# shellcheck disable=SC2086
eval "$list_cmd" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    printf '%s\n' "$path"
done >"$tmp_list"

if [ ! -s "$tmp_list" ]; then
    echo "No files to scan."
    exit 0
fi

matches="$(grep -iE "$pattern" "$tmp_list" || true)"

# Allow defaults.auto.tfvars explicitly (policy: only this tfvars is allowed tracked)
matches="$(printf '%s\n' "$matches" | grep -ivE '(^|/)defaults\.auto\.tfvars$' || true)"

if [ -n "$ignore" ]; then
    matches="$(printf '%s\n' "$matches" | grep -ivE "$ignore" || true)"
fi

if [ -n "$matches" ]; then
    echo "Sensitive filename/path matches detected:"
    printf '%s\n' "$matches"
    echo ""
    echo "These files should not be committed (public repo policy)."
    echo "If this is a false positive, rename the file or extend SENSITIVE_FILES_IGNORE."
    exit 1
fi

echo "Sensitive filename check passed."
