# SealedSecret Helper Scripts

This directory contains Fish shell scripts for managing Kubernetes SealedSecrets.

## Scripts

### seal-secret.fish

Encode plaintext values to base64 and seal them into SealedSecrets.

**Usage:**

```fish
seal-secret.fish <namespace> <secret-name> <key1>=<value1> [<key2>=<value2> ...]
```

**Emit-only (show command, do not execute):**

```fish
seal-secret.fish --emit-only <namespace> <secret-name> <key1>=<value1> [<key2>=<value2> ...]
```

**Example:**

```fish
# Create SealedSecret for MinIO credentials
seal-secret.fish minio minio-root-credentials \
  rootUser=admin \
  rootPassword=secret123 \
  > apps/cluster/minio/templates/minio-root-credentials.sealedsecret.yaml

# Create SealedSecret for Cloudflare API token
seal-secret.fish external-dns external-dns-cloudflare \
  cloudflare_api_token=your_cf_token_here \
  > apps/cluster/external-dns/templates/external-dns-api-token.sealedsecret.yaml
```

### unseal-secret.fish

Decode and display sealed secret values from unsealed Kubernetes secrets.

**Usage:**

```fish
unseal-secret.fish <namespace> <secret-name> [<key>]
```

**Examples:**

```fish
# Show all keys in a secret
unseal-secret.fish minio minio-root-credentials

# Show specific key
unseal-secret.fish minio minio-root-credentials rootPassword

# Show Cloudflare API token
unseal-secret.fish external-dns external-dns-cloudflare cloudflare_api_token
```

### regenerate-sealed-secrets.fish

Regenerate all SealedSecrets with fresh credentials (interactive or non-interactive).

**Usage:**

```fish
# Interactive mode (prompts for all credentials)
tools/scripts/regenerate-sealed-secrets.fish

# Non-interactive mode (from environment variables)
set -x CF_API_TOKEN "your_cloudflare_token"
set -x PROXMOX_TOKEN_SECRET "your_proxmox_token"
set -x MINIO_ROOT_PASSWORD "your_minio_password"
set -x DISCORD_WEBHOOK_URL "your_discord_webhook"  # optional
set -x GitHub_TOKEN "your_GitHub_pat"  # optional
tools/scripts/regenerate-sealed-secrets.fish --non-interactive
```

**Emit-only (show commands, do not execute):**

```fish
tools/scripts/regenerate-sealed-secrets.fish --emit-only
```

**Environment Variables:**

- `CF_API_TOKEN` - Cloudflare API token (Zone:DNS:Edit + Zone:SSL/TLS:Edit)
- `PROXMOX_TOKEN_SECRET` - Proxmox API token secret (for `root@pam!csi`)
- `MINIO_ROOT_PASSWORD` - MinIO root/admin password
- `DISCORD_WEBHOOK_URL` - Discord webhook for ArgoCD notifications (optional)
- `GitHub_TOKEN` - GitHub PAT for private repo access (optional)
- `GitHub_USERNAME` - GitHub username (default: `git`)

**Generated Secrets:**

1. `external-dns-cloudflare` (namespace: external-dns)
2. `origin-ca-issuer-cloudflare` (namespace: origin-ca-issuer)
3. `proxmox-csi-plugin` (namespace: csi-proxmox)
4. `minio-root-credentials` (namespace: minio)
5. `argocd-notifications-secret` (namespace: argocd) - optional
6. `repo-GitHub-m0sh1-infra` (namespace: argocd) - optional

## Workflow

### Initial Setup (Fresh Cluster)

1. Bootstrap ArgoCD and sealed-secrets controller
2. Restore old sealing keys (if available):

   ```fish
   kubectl apply -f docs/not-git/certs/main.key
   kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets
   ```

3. If keys not available, regenerate all SealedSecrets:

   ```fish
   tools/scripts/regenerate-sealed-secrets.fish
   ```

### Creating New SealedSecrets

```fish
# 1. Create plaintext secret and seal it
seal-secret.fish my-namespace my-secret-name key1=value1 key2=value2 \
  > apps/cluster/my-app/templates/my-secret.sealedsecret.yaml

# 2. Review the generated YAML
cat apps/cluster/my-app/templates/my-secret.sealedsecret.yaml

# 3. Commit to Git
git add apps/cluster/my-app/templates/my-secret.sealedsecret.yaml
git commit -m "Add SealedSecret for my-app"

# 4. Let ArgoCD sync
kubectl get sealedsecrets -n my-namespace
```

### Viewing Existing Secrets

```fish
# List all SealedSecrets in cluster
kubectl get sealedsecrets -A

# View specific SealedSecret sync status
kubectl get sealedsecret external-dns-cloudflare -n external-dns

# Decode and view unsealed secret values
unseal-secret.fish external-dns external-dns-cloudflare
```

### Troubleshooting

**SealedSecrets not unsealing:**

```fish
# Check controller logs
kubectl logs -n sealed-secrets deploy/sealed-secrets-controller --tail=50

# Verify sealing keys present
kubectl get secrets -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active

# If keys missing, restore backup
kubectl apply -f docs/not-git/certs/main.key
kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets
```

**Wrong sealing certificate:**

```fish
# Fetch current certificate
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d

# Use with kubeseal
kubectl create secret generic test \
  --from-literal=foo=bar --dry-run=client -o yaml \
  | kubeseal --cert=/tmp/cert.pem --format=yaml
```

## Security Best Practices

1. **Never commit plaintext secrets** to Git
2. **Always use SealedSecrets** for GitOps-managed secrets
3. **Backup sealing keys** to secure location (1Password, not Git)
4. **Rotate credentials** periodically (API tokens, passwords)
5. **Use strong random passwords**: `openssl rand -base64 32`
6. **Delete plaintext config files** after sealing (e.g., `proxmox-csi/templates/config.yaml`)

## See Also

- [bootstrap-recovery.md](../../docs/diaries/bootstrap-recovery.md) - Full bootstrap guide with SealedSecret restoration
- [Bitnami SealedSecrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
