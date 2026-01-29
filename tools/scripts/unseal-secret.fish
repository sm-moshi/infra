#!/usr/bin/env fish
# unseal-secret.fish - Helper script to decode and display sealed secret values
# NOTE: Operator-only imperative helper (kubectl); do not run in CI. Use for troubleshooting, not steady-state flows.
#
# Usage:
#   unseal-secret.fish <namespace> <secret-name> [<key>]
#
# Example:
#   unseal-secret.fish minio minio-root-credentials           # Show all keys
#   unseal-secret.fish minio minio-root-credentials rootUser  # Show specific key
#
# Output:
#   Displays decoded secret values from the unsealed Kubernetes secret

set -l namespace $argv[1]
set -l secret_name $argv[2]
set -l key $argv[3]

if test (count $argv) -lt 2
    echo "Usage: unseal-secret.fish <namespace> <secret-name> [<key>]" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  unseal-secret.fish minio minio-root-credentials           # Show all keys" >&2
    echo "  unseal-secret.fish minio minio-root-credentials rootUser  # Show specific key" >&2
    exit 1
end

# Check if secret exists
if not kubectl get secret $secret_name -n $namespace &>/dev/null
    echo "❌ Error: Secret '$secret_name' not found in namespace '$namespace'" >&2
    echo "" >&2
    echo "Available secrets in namespace '$namespace':" >&2
    kubectl get secrets -n $namespace -o name | sed 's|^secret/||'
    exit 1
end

echo "📂 Secret: $secret_name (namespace: $namespace)" >&2
echo "" >&2

if test -n "$key"
    # Show specific key
    echo "🔑 Key: $key" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    kubectl get secret $secret_name -n $namespace \
        -o jsonpath="{.data.$key}" \
        | base64 -d
    echo ""
else
    # Show all keys
    echo "🔑 All keys and values:" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    # Get all keys
    set -l keys (kubectl get secret $secret_name -n $namespace -o jsonpath='{.data}' | jq -r 'keys[]')

    for k in $keys
        set -l value (kubectl get secret $secret_name -n $namespace -o jsonpath="{.data.$k}" | base64 -d)
        echo "$k: $value"
    end
end
