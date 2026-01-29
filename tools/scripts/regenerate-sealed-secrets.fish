#!/usr/bin/env fish
# regenerate-sealed-secrets.fish - Regenerate all SealedSecrets with fresh credentials
# NOTE: Operator-only imperative helper (kubectl/kubeseal); do not run in CI. Commit only sealed outputs via Git/ArgoCD.
#
# This script creates SealedSecret manifests for all cluster secrets.
# You must provide credentials via environment variables or be prompted interactively.
#
# Usage:
#   # Interactive mode (prompts for all secrets)
#   ./regenerate-sealed-secrets.fish
#
#   # Non-interactive mode (from environment variables)
#   set -x CF_API_TOKEN "your_cloudflare_token"
#   set -x PROXMOX_TOKEN_SECRET "your_proxmox_token"
#   set -x MINIO_ROOT_PASSWORD "your_minio_password"
#   set -x DISCORD_WEBHOOK_URL "your_discord_webhook"
#   set -x GITHUB_TOKEN "your_github_pat"
#   ./regenerate-sealed-secrets.fish --non-interactive
#
#   # Emit-only mode (prints commands, no kubectl/kubeseal)
#   ./regenerate-sealed-secrets.fish --emit-only
#
# Environment variables:
#   CF_API_TOKEN           - Cloudflare API token (Zone:DNS:Edit + Zone:SSL/TLS:Edit)
#   PROXMOX_TOKEN_SECRET   - Proxmox API token secret (for root@pam!csi)
#   MINIO_ROOT_PASSWORD    - MinIO root/admin password
#   DISCORD_WEBHOOK_URL    - Discord webhook for ArgoCD notifications (optional)
#   GITHUB_TOKEN           - GitHub PAT for private repo access (optional)
#   GITHUB_USERNAME        - GitHub username (default: git)

set -l non_interactive 0
set -l emit_only 0
for arg in $argv
    switch $arg
        case --non-interactive
            set non_interactive 1
        case --emit-only
            set emit_only 1
    end
end

# Color output helpers
function echo_info
    echo (set_color cyan)"ℹ️  $argv"(set_color normal) >&2
end

function echo_success
    echo (set_color green)"✅ $argv"(set_color normal) >&2
end

function echo_error
    echo (set_color red)"❌ $argv"(set_color normal) >&2
end

function echo_warn
    echo (set_color yellow)"⚠️  $argv"(set_color normal) >&2
end

if test $emit_only -eq 1
    echo_info "Emit-only mode: showing commands only (no kubectl/kubeseal)."
else
    # Check prerequisites
    echo_info "Checking prerequisites..."

    if not command -v kubectl &>/dev/null
        echo_error "kubectl not found in PATH"
        exit 1
    end

    if not command -v kubeseal &>/dev/null
        echo_error "kubeseal not found in PATH"
        exit 1
    end

    if not kubectl cluster-info &>/dev/null
        echo_error "Cannot connect to Kubernetes cluster"
        exit 1
    end

    # Fetch sealing certificate
    echo_info "Fetching sealed-secrets certificate..."
    set -l cert_file /tmp/sealed-secrets-cert-$fish_pid.pem
    kubectl get secret -n sealed-secrets \
        -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
        -o jsonpath='{.items[0].data.tls\.crt}' \
        | base64 -d >$cert_file

    if test $status -ne 0
        echo_error "Failed to fetch sealed-secrets certificate"
        rm -f $cert_file
        exit 1
    end

    echo_success "Prerequisites OK"
    echo ""
end

# Function to prompt for secret or use environment variable
function get_credential
    set -l var_name $argv[1]
    set -l prompt_text $argv[2]
    set -l is_optional $argv[3]

    # Check environment variable first
    if set -q $var_name
        echo $$var_name
        return 0
    end

    # Interactive mode
    if test $non_interactive -eq 0
        if test "$is_optional" = optional
            read -P "$prompt_text (optional, press Enter to skip): " value
        else
            read -P "$prompt_text: " value
        end
        echo $value
    else
        if test "$is_optional" != optional
            echo_error "Required environment variable $var_name not set"
            return 1
        end
    end
end

if test $emit_only -eq 1
    echo ""
    echo "Commands (use env vars shown):" >&2
    echo 'kubectl get secret -n sealed-secrets \\' >&2
    echo '  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \\' >&2
    echo "  -o jsonpath='{.items[0].data.tls\\.crt}' \\" >&2
    echo '  | base64 -d > /tmp/sealed-secrets-cert.pem' >&2
    echo "" >&2
    echo 'kubectl create secret generic external-dns-cloudflare \\' >&2
    echo '  --from-literal=cloudflare_api_token="$CF_API_TOKEN" \\' >&2
    echo '  --namespace=external-dns \\' >&2
    echo '  --dry-run=client -o yaml \\' >&2
    echo '  | kubeseal --cert=/tmp/sealed-secrets-cert.pem --format=yaml > <OUT>/external-dns-cloudflare.sealedsecret.yaml' >&2
    echo "" >&2
    echo 'kubectl create secret generic origin-ca-issuer-cloudflare \\' >&2
    echo '  --from-literal=cloudflare_api_token="$CF_API_TOKEN" \\' >&2
    echo '  --namespace=origin-ca-issuer \\' >&2
    echo '  --dry-run=client -o yaml \\' >&2
    echo '  | kubeseal --cert=/tmp/sealed-secrets-cert.pem --format=yaml > <OUT>/origin-ca-issuer-cloudflare.sealedsecret.yaml' >&2
    echo "" >&2
    echo '# Proxmox CSI config template' >&2
    echo 'cat > /tmp/proxmox-config.yaml <<"EOF"' >&2
    echo 'clusters:' >&2
    echo '- url: https://10.0.10.11:8006/api2/json' >&2
    echo '  insecure: false' >&2
    echo '  token_id: "root@pam!csi"' >&2
    echo '  token_secret: "$PROXMOX_TOKEN_SECRET"' >&2
    echo '  region: pve-01' >&2
    echo '- url: https://10.0.10.12:8006/api2/json' >&2
    echo '  insecure: false' >&2
    echo '  token_id: "root@pam!csi"' >&2
    echo '  token_secret: "$PROXMOX_TOKEN_SECRET"' >&2
    echo '  region: pve-02' >&2
    echo '- url: https://10.0.10.13:8006/api2/json' >&2
    echo '  insecure: false' >&2
    echo '  token_id: "root@pam!csi"' >&2
    echo '  token_secret: "$PROXMOX_TOKEN_SECRET"' >&2
    echo '  region: pve-03' >&2
    echo EOF >&2
    echo 'kubectl create secret generic proxmox-csi-plugin \\' >&2
    echo '  --from-file=config.yaml=/tmp/proxmox-config.yaml \\' >&2
    echo '  --namespace=csi-proxmox \\' >&2
    echo '  --dry-run=client -o yaml \\' >&2
    echo '  | kubeseal --cert=/tmp/sealed-secrets-cert.pem --format=yaml > <OUT>/proxmox-csi-plugin.sealedsecret.yaml' >&2
    echo "" >&2
    echo 'kubectl create secret generic minio-root-credentials \\' >&2
    echo '  --from-literal=rootUser="admin" \\' >&2
    echo '  --from-literal=rootPassword="$MINIO_ROOT_PASSWORD" \\' >&2
    echo '  --namespace=minio \\' >&2
    echo '  --dry-run=client -o yaml \\' >&2
    echo '  | kubeseal --cert=/tmp/sealed-secrets-cert.pem --format=yaml > <OUT>/minio-root-credentials.sealedsecret.yaml' >&2
    echo "" >&2
    echo '# Optional: ArgoCD notifications secret (if DISCORD_WEBHOOK_URL set)' >&2
    echo '# Optional: ArgoCD repo credentials (if GITHUB_TOKEN set)' >&2
    exit 0
end

# Collect credentials
echo_info "Collecting credentials..."
echo ""

set -l cf_token (get_credential CF_API_TOKEN "Cloudflare API Token (Zone:DNS:Edit + Zone:SSL/TLS:Edit)")
if test -z "$cf_token"
    echo_error "Cloudflare API token is required"
    rm -f $cert_file
    exit 1
end

set -l proxmox_token (get_credential PROXMOX_TOKEN_SECRET "Proxmox API Token Secret (root@pam!csi)")
if test -z "$proxmox_token"
    echo_error "Proxmox API token secret is required"
    rm -f $cert_file
    exit 1
end

set -l minio_password (get_credential MINIO_ROOT_PASSWORD "MinIO Root Password")
if test -z "$minio_password"
    # Generate strong password if not provided
    echo_warn "Generating random MinIO password..."
    set minio_password (openssl rand -base64 32)
    echo_info "Generated password: $minio_password"
    echo_warn "⚠️  SAVE THIS PASSWORD TO 1PASSWORD!"
end

set -l discord_webhook (get_credential DISCORD_WEBHOOK_URL "Discord Webhook URL for ArgoCD notifications" optional)
set -l github_token (get_credential GITHUB_TOKEN "GitHub Personal Access Token" optional)
set -l github_username (get_credential GITHUB_USERNAME "GitHub Username (default: git)" optional)
if test -z "$github_username"
    set github_username git
end

echo ""
echo_success "Credentials collected"
echo ""

# Create temporary directory for sealed secrets
set -l output_dir (mktemp -d)
echo_info "Generating SealedSecrets to: $output_dir"
echo ""

# 1. External DNS - Cloudflare API Token
echo_info "[1/6] Generating external-dns-cloudflare..."
kubectl create secret generic external-dns-cloudflare \
    --from-literal=cloudflare_api_token="$cf_token" \
    --namespace=external-dns \
    --dry-run=client -o yaml \
    | kubeseal --cert=$cert_file --format=yaml >$output_dir/external-dns-cloudflare.sealedsecret.yaml
echo_success "external-dns-cloudflare created"

# 2. Origin CA Issuer - Cloudflare API Token
echo_info "[2/6] Generating origin-ca-issuer-cloudflare..."
kubectl create secret generic origin-ca-issuer-cloudflare \
    --from-literal=cloudflare_api_token="$cf_token" \
    --namespace=origin-ca-issuer \
    --dry-run=client -o yaml \
    | kubeseal --cert=$cert_file --format=yaml >$output_dir/origin-ca-issuer-cloudflare.sealedsecret.yaml
echo_success "origin-ca-issuer-cloudflare created"

# 3. Proxmox CSI Plugin - Config with API credentials
echo_info "[3/6] Generating proxmox-csi-plugin..."
set -l proxmox_config_file /tmp/proxmox-config-$fish_pid.yaml
echo "clusters:
- url: https://10.0.10.11:8006/api2/json
  insecure: false
  token_id: \"root@pam!csi\"
  token_secret: \"$proxmox_token\"
  region: pve-01
- url: https://10.0.10.12:8006/api2/json
  insecure: false
  token_id: \"root@pam!csi\"
  token_secret: \"$proxmox_token\"
  region: pve-02
- url: https://10.0.10.13:8006/api2/json
  insecure: false
  token_id: \"root@pam!csi\"
  token_secret: \"$proxmox_token\"
  region: pve-03" >$proxmox_config_file

kubectl create secret generic proxmox-csi-plugin \
    --from-file=config.yaml=$proxmox_config_file \
    --namespace=csi-proxmox \
    --dry-run=client -o yaml \
    | kubeseal --cert=$cert_file --format=yaml >$output_dir/proxmox-csi-plugin.sealedsecret.yaml
rm -f $proxmox_config_file
echo_success "proxmox-csi-plugin created"

# 4. MinIO Root Credentials
echo_info "[4/6] Generating minio-root-credentials..."
kubectl create secret generic minio-root-credentials \
    --from-literal=rootUser="admin" \
    --from-literal=rootPassword="$minio_password" \
    --namespace=minio \
    --dry-run=client -o yaml \
    | kubeseal --cert=$cert_file --format=yaml >$output_dir/minio-root-credentials.sealedsecret.yaml
echo_success "minio-root-credentials created"

# 5. ArgoCD Notifications Secret (optional)
if test -n "$discord_webhook"
    echo_info "[5/6] Generating argocd-notifications-secret..."
    kubectl create secret generic argocd-notifications-secret \
        --from-literal=discord-webhook-url="$discord_webhook" \
        --namespace=argocd \
        --dry-run=client -o yaml \
        | kubeseal --cert=$cert_file --format=yaml >$output_dir/argocd-notifications-secret.sealedsecret.yaml
    echo_success "argocd-notifications-secret created"
else
    echo_warn "[5/6] Skipping argocd-notifications-secret (no webhook URL provided)"
end

# 6. ArgoCD GitHub Repo Credentials (optional)
if test -n "$github_token"
    echo_info "[6/6] Generating repo-github-m0sh1-infra..."
    kubectl create secret generic repo-github-m0sh1-infra \
        --from-literal=url="https://github.com/sm-moshi/infra.git" \
        --from-literal=username="$github_username" \
        --from-literal=password="$github_token" \
        --from-literal=type="git" \
        --namespace=argocd \
        --dry-run=client -o yaml \
        | kubeseal --cert=$cert_file --format=yaml >$output_dir/repo-github-m0sh1-infra.sealedsecret.yaml

    # Add ArgoCD label
    sed -i '' '/metadata:/a\
\  labels:\
\    argocd.argoproj.io/secret-type: repository
' $output_dir/repo-github-m0sh1-infra.sealedsecret.yaml

    echo_success "repo-github-m0sh1-infra created"
else
    echo_warn "[6/6] Skipping repo-github-m0sh1-infra (no GitHub token provided)"
end

# Cleanup
rm -f $cert_file

echo ""
echo_success "All SealedSecrets generated successfully!"
echo ""
echo_info "Generated files in: $output_dir"
ls -lh $output_dir/

echo ""
echo_info "Next steps:"
echo "  1. Review the generated SealedSecret files"
echo "  2. Copy them to the appropriate locations:"
echo "     cp $output_dir/external-dns-cloudflare.sealedsecret.yaml apps/cluster/external-dns/templates/"
echo "     cp $output_dir/origin-ca-issuer-cloudflare.sealedsecret.yaml apps/cluster/origin-ca-issuer/templates/"
echo "     cp $output_dir/proxmox-csi-plugin.sealedsecret.yaml apps/cluster/proxmox-csi/templates/"
echo "     cp $output_dir/minio-root-credentials.sealedsecret.yaml apps/cluster/minio/templates/"
if test -n "$discord_webhook"
    echo "     cp $output_dir/argocd-notifications-secret.sealedsecret.yaml apps/cluster/secrets-cluster/"
end
if test -n "$github_token"
    echo "     cp $output_dir/repo-github-m0sh1-infra.sealedsecret.yaml apps/cluster/secrets-cluster/"
end
echo "  3. Delete plaintext config.yaml if it exists: rm apps/cluster/proxmox-csi/templates/config.yaml"
echo "  4. Commit changes to Git"
echo "  5. Let ArgoCD sync the changes"
echo ""
echo_warn "⚠️  Remember to save credentials to 1Password vault!"
echo ""
echo_info "Temporary directory: $output_dir"
echo_info "Clean up when done: rm -rf $output_dir"
