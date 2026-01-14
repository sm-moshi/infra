#!/bin/sh
set -eu

PATTERN='(^|/)(config\.yaml)$''|(^|/)(ansible|terraform)/op\.env$''|(^|/)\.env([._-].*)?$''|(^|/)(kubeconfig)(\..*)?$''|(^|/).*id_(rsa|ed25519)(\..*)?$''|(^|/).*\.p12$|(^|/).*\.pfx$''|(^|/).*\.key$''|(^|/).*privkey.*\.pem$|(^|/).*private.*\.pem$''|(^|/).*terraform\.tfstate(\..*)?$''|(^|/).*\.tfstate\..*$''|(^|/).*secrets\.auto\.tfvars$''|(^|/).*\.tfvars$''|(^|/).*-(unsealed)\.ya?ml$|(^|/).*unsealed.*\.ya?ml$'

IGNORE='(^|/)apps/cluster/secrets-cluster/''|(^|/)apps/cluster/sealed-secrets/''|\.sealedsecret\.ya?ml$''|(^|/)docs/archive/''|(^|/)apps/.*/charts/''|(^|/)apps/.*/Chart\.lock$'

FILES="$(git diff --cached --name-only --diff-filter=ACMR || git ls-files)"

MATCHES="$(printf '%s\n' "$FILES" | grep -iE "$PATTERN" || true)"
MATCHES="$(printf '%s\n' "$MATCHES" | grep -ivE "$IGNORE" || true)"
MATCHES="$(printf '%s\n' "$MATCHES" | grep -ivE 'defaults\.auto\.tfvars$' || true)"

if [ -n "$MATCHES" ]; then
    echo "❌ Forbidden sensitive files detected:"
    printf '%s\n' "$MATCHES"
    exit 1
fi

echo "✅ Sensitive file check passed"
