#!/usr/bin/env fish
# seal-secret.fish - Helper script to encode plaintext values and seal them into SealedSecrets
#
# Usage:
#   seal-secret.fish <namespace> <secret-name> <key1>=<value1> [<key2>=<value2> ...]
#
# Example:
#   seal-secret.fish minio minio-root-credentials rootUser=admin rootPassword=secret123
#
# Output:
#   Generates sealed secret YAML to stdout (redirect to file as needed)

set -l namespace $argv[1]
set -l secret_name $argv[2]

if test (count $argv) -lt 3
    echo "Usage: seal-secret.fish <namespace> <secret-name> <key1>=<value1> [<key2>=<value2> ...]" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  seal-secret.fish minio minio-root-credentials rootUser=admin rootPassword=secret123" >&2
    exit 1
end

# Build --from-literal arguments
set -l literal_args
for arg in $argv[3..-1]
    set literal_args $literal_args --from-literal=$arg
end

# Fetch current sealing certificate
echo "Fetching sealed-secrets certificate..." >&2
set -l cert_file /tmp/sealed-secrets-cert-$fish_pid.pem
kubectl get secret -n sealed-secrets \
    -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
    -o jsonpath='{.items[0].data.tls\.crt}' \
    | base64 -d >$cert_file

if test $status -ne 0
    echo "Error: Failed to fetch sealed-secrets certificate" >&2
    rm -f $cert_file
    exit 1
end

# Create and seal the secret
echo "Creating and sealing secret '$secret_name' in namespace '$namespace'..." >&2
kubectl create secret generic $secret_name \
    --namespace=$namespace \
    $literal_args \
    --dry-run=client -o yaml \
    | kubeseal --cert=$cert_file --format=yaml

# Cleanup
rm -f $cert_file

echo "" >&2
echo "✅ SealedSecret generated successfully!" >&2
echo "💡 Tip: Redirect output to file, e.g.: seal-secret.fish ... > path/to/secret.yaml" >&2
