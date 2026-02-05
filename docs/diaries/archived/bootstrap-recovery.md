# Bootstrap Recovery Guide

This document provides disaster recovery procedures for reinstalling ArgoCD and restoring GitOps operations from the bootstrap manifests.

## When to Use Bootstrap

**Bootstrap is for disaster recovery only** - normal operations use ArgoCD automated sync.

Use bootstrap procedures when:

- ✅ Fresh cluster installation
- ✅ Complete cluster rebuild after catastrophic failure
- ✅ ArgoCD namespace deleted or corrupted
- ✅ ArgoCD CRDs lost or broken

Do NOT use bootstrap for:

- ❌ Normal application deployments (use Git → ArgoCD)
- ❌ Updating existing applications (commit to Git)
- ❌ ArgoCD configuration changes (use `apps/cluster/argocd/` wrapper chart)
- ❌ Adding new applications (create ArgoCD Application manifest)

## Bootstrap Architecture

Bootstrap manifests live in `cluster/bootstrap/`:

```text
cluster/bootstrap/
├── kustomization.yaml       # Aggregates bootstrap resources
├── argocd/
│   ├── namespace.yaml       # ArgoCD namespace (bootstrap must create this)
│   ├── install.yaml         # Minimal ArgoCD installation
│   ├── kustomization.yaml   # Kustomize aggregation
│   └── rendered.yaml        # Full ArgoCD config (generated, not committed)
└── cert-manager/
    └── kustomization.yaml   # Custom cert-manager resources (ClusterIssuer, Certificate)
```

### Key Principles

1. **Minimal scope**: Bootstrap contains only what's needed to get ArgoCD running
2. **Immutable**: Bootstrap manifests rarely change; ArgoCD manages everything after handoff
3. **Reproducible**: `rendered.yaml` is generated from `apps/cluster/argocd/` wrapper chart
4. **Single source of truth**: Wrapper chart is authoritative; bootstrap derives from it
5. **Path separation**: Bootstrap uses `cluster/bootstrap/`, operational app-of-apps uses `argocd/apps/` - these are DIFFERENT paths for DIFFERENT purposes

**CRITICAL**: After bootstrap handoff, infra-root Application **MUST** point to `argocd/apps` (NOT `cluster/bootstrap`). If infra-root has wrong path, it will never discover applications added to Git. Always verify path after bootstrap.

## Prerequisites

Before starting recovery:

1. **Cluster access**: `kubectl cluster-info` succeeds
2. **Repository access**: Clone `https://github.com/sm-moshi/infra.git`
3. **Network architecture**: 4-VLAN design operational (VLANs 10/20/30 with OPNsense routing)
4. **Proxmox CSI storage**: All ZFS datasets created and storage IDs configured
   - nvme rpool: k8s-pgdata, k8s-pgwal, k8s-registry, k8s-caches
   - sata-ssd: minio-data (sata-ssd/minio/data dataset)
   - See [proxmox-csi-setup.md](proxmox-csi-setup.md) for dataset creation steps
5. **Sealed secrets controller**: If redeploying cluster, bootstrap sealed-secrets first
6. **Network connectivity**: Cluster can pull images from registries
   - Nodes on VLAN 20 (10.0.20.0/24)
   - Service VIPs on VLAN 30 (10.0.30.0/24)

## Bootstrap Procedure

### Step 1: Verify Prerequisites

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify nodes ready (should show labctrl, horse01-04)
kubectl get nodes

# Verify Proxmox storage IDs exist on all nodes
# SSH to each Proxmox node and run:
pvesm status | grep -E "k8s-pgdata|k8s-pgwal|k8s-registry|k8s-caches|minio-data"

# Check storage classes available (local-path should exist pre-ArgoCD)
kubectl get storageclass

# Confirm repository current
cd /path/to/infra
git pull origin main
git status
```

### Step 2: Bootstrap ArgoCD

**Note**: cert-manager CRDs are installed automatically by the wrapper chart (`apps/cluster/cert-manager/`) via `installCRDs: true`. No manual CRD installation needed during bootstrap.

**Namespace handling**: Bootstrap creates the `argocd` namespace itself to avoid chicken-and-egg issues. Once ArgoCD is operational, the `apps/cluster/namespaces` wrapper chart manages all other namespaces (the `argocd` entry in that chart becomes a no-op since the namespace already exists).

```bash
# Apply minimal ArgoCD installation
kubectl apply -k cluster/bootstrap/argocd/

# Wait for ArgoCD to be ready
kubectl wait -n argocd \
  --for=condition=available \
  deploy/argocd-server \
  --timeout=300s

# Verify ArgoCD pods running
kubectl get pods -n argocd
```

Expected pods:

- `argocd-application-controller-*`
- `argocd-repo-server-*`
- `argocd-server-*`
- `argocd-redis-*`
- `argocd-dex-server-*` (if using SSO)

### Step 3: Apply Node Role Labels

Node role labels (`node-role.kubernetes.io/*`) cannot be applied via kubelet and must be set via kubectl after cluster bootstrap:

```bash
# Apply node role labels
tools/scripts/apply-node-role-labels.fish

# Verify labels applied
kubectl get nodes --show-labels | grep node-role

# Expected labels:
# - labctrl: node-role.kubernetes.io/control-plane=true
# - horse01-04: node-role.kubernetes.io/worker=true
```

**Why post-bootstrap?** Kubernetes API server rejects `kubernetes.io` namespace labels when applied via kubelet node registration arguments. These must be applied via kubectl with appropriate RBAC permissions.

### Step 4: Deploy Root Application

**CRITICAL**: Verify infra-root points to correct path after deployment.

```bash
# Apply the app-of-apps root
kubectl apply -f argocd/apps/root.yaml

# CRITICAL: Verify infra-root source path
kubectl get application infra-root -n argocd -o yaml | grep "path:"
# Expected: path: argocd/apps
# WRONG: path: cluster/bootstrap

# If wrong path, re-apply to correct it
kubectl apply -f argocd/apps/root.yaml

# Force hard refresh to discover applications
kubectl patch application infra-root -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Watch applications appear (within 3 minutes)
kubectl get applications -n argocd --watch
```

**Why this matters**: Bootstrap creates infra-root with `cluster/bootstrap` path (contains only ArgoCD install manifests). Operational pattern requires `argocd/apps` path (contains all Application manifests). If not corrected, ArgoCD will never discover new applications added to `argocd/apps/cluster/` or `argocd/apps/user/`.

**Symptom of wrong path**: Applications committed to Git don't appear in cluster, `kubectl get application -n argocd` shows only infra-root.

### Step 5: Let ArgoCD Take Over

ArgoCD will now automatically sync all applications via the root app-of-apps pattern.

**Initial monitoring (use kubectl until ArgoCD syncs itself):**

```bash
# View cluster-wide application health
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Watch ArgoCD sync itself (it's now a GitOps-managed app)
kubectl get application -n argocd argocd -w

# Check if ArgoCD has created its own ConfigMaps
kubectl get configmap -n argocd argocd-cm
```

**Once ArgoCD is fully synced** (may take 1-2 minutes), the `argocd` CLI can be used (requires login first):

```bash
# Verify ConfigMap exists
kubectl get configmap -n argocd argocd-cm

# Start port-forward in a separate terminal (forward local 8080 to service's 443)
kubectl port-forward -n argocd svc/argocd-server 8080:443

# In another terminal, get admin password and login (Fish shell)
set ARGOCD_PASSWORD (kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

# Login (works for both shells)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Now CLI commands work
argocd app list
argocd app get infra-root --refresh
```

**Note**: Until MetalLB and Traefik are deployed, using `kubectl` commands is simpler than the `argocd` CLI.

**Port-forward CNI issue**: Port-forwarding to argocd-server may fail with `failed to execute portforward in network namespace` errors (known k3s/Flannel issue). **Workaround**: Change Service to NodePort temporarily:

```bash
# Make argocd-server accessible via NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort"}}'

# Get the NodePort (HTTPS will be 30000-32767 range)
kubectl get svc argocd-server -n argocd

# Access via any node IP + NodePort
# Example: https://10.0.20.20:31684 or http://10.0.20.20:32373
argocd login 10.0.20.20:31684 --username admin --password "$ARGOCD_PASSWORD" --insecure
```

Once MetalLB/Traefik are deployed and working, ArgoCD will be accessible via proper ingress route.

**To speed up ArgoCD self-sync**, manually trigger it:

```bash
# Force ArgoCD to sync itself immediately
kubectl annotate application argocd -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite
```

### Step 6: Verify Critical Applications

After root application syncs, verify critical infrastructure:

```bash
# Check ArgoCD itself (should be managed by GitOps now)
kubectl get application -n argocd argocd

# Verify cert-manager
kubectl get pods -n cert-manager

# Check ingress controller (Traefik should get MetalLB IP 10.0.30.10)
kubectl get pods -n traefik
kubectl get svc -n traefik traefik

# Verify sealed-secrets
kubectl get pods -n sealed-secrets

# Confirm storage provisioners and StorageClasses
kubectl get pods -n proxmox-csi
kubectl get storageclass | grep proxmox-csi-zfs

# Verify MetalLB configured
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
```

## Post-Bootstrap Validation

### ArgoCD UI Access

**During bootstrap** (before MetalLB/Traefik deployed), use port-forwarding:

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward to access UI locally (forward local 8080 to service's 443)
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Access: `https://localhost:8080`
Username: `admin`
Password: (from command above)

**Note**: Keep the port-forward running in a separate terminal while accessing the UI or CLI.

**After MetalLB/Traefik deployed**: Access via `https://argocd.m0sh1.cc`

### Verify Automated Sync

**Using kubectl** (recommended during bootstrap):

```bash
# Check all application sync status
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Check specific app sync policy
kubectl get application valkey -n argocd -o jsonpath='{.spec.syncPolicy}' | jq

# Force sync an application
kubectl patch application <app-name> -n argocd \
  --type merge \
  --patch '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'
```

**Using ArgoCD CLI** (after login):

```bash
# Login first (see "ArgoCD UI Access" section)
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Confirm automated sync policies active
argocd app get valkey -o json | jq '.spec.syncPolicy'

# Check for out-of-sync applications
argocd app list --sync-status OutOfSync

# Force sync if needed
argocd app sync <app-name>
```

### Validate Storage

```bash
# Check StorageClasses created by Proxmox CSI
kubectl get storageclass
# Expected: proxmox-csi-zfs-pgdata-retain (default)
#           proxmox-csi-zfs-pgwal-retain
#           proxmox-csi-zfs-registry-retain
#           proxmox-csi-zfs-caches-retain
#           proxmox-csi-zfs-caches-delete
#           proxmox-csi-zfs-minio-retain

# Check PVCs bound
kubectl get pvc -A

# Verify volumes provisioned
kubectl get pv

# Verify Proxmox CSI plugin healthy
kubectl logs -n proxmox-csi deploy/proxmox-csi-controller

# Test storage with temp pod if needed
kubectl run storage-test --image=busybox \
  --overrides='{"spec":{"volumes":[{"name":"test","persistentVolumeClaim":{"claimName":"test-pvc"}}]}}' \
  --rm -it -- sh
```

## Troubleshooting

### ArgoCD Pods CrashLooping

**Symptom**: `argocd-server` or `argocd-repo-server` in CrashLoopBackOff

**Diagnosis**:

```bash
kubectl logs -n argocd deploy/argocd-server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
```

**Common causes**:

- Missing CRDs (apply bootstrap again)
- Network policies blocking communication
- Insufficient resources (check node memory/CPU)

**Resolution**:

```bash
# Reapply bootstrap manifests
kubectl apply -k cluster/bootstrap/argocd/ --force

# Delete stuck pods
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server
```

### Applications Stuck in OutOfSync

**Symptom**: Applications remain OutOfSync after bootstrap

**Diagnosis**:

```bash
# Using kubectl (always works)
kubectl describe application -n argocd <app-name>
kubectl get application <app-name> -n argocd -o yaml

# Using argocd CLI (if logged in)
argocd app get <app-name>
```

**Common causes**:

- Repository webhook not configured
- Sync interval too long
- Manual changes in cluster

**Resolution**:

```bash
# Force refresh and sync
argocd app sync <app-name> --force

# Check application events
kubectl get events -n argocd --field-selector involvedObject.name=<app-name>
```

### Sealed Secrets Not Decrypting

**Symptom**: SealedSecrets show `SYNCED: False` with error "no key could decrypt secret"

**Root Cause**: Sealed secrets were encrypted with old sealing keys, but controller only has new keys from fresh bootstrap.

**Two Recovery Options:**

#### Option 1: Restore Old Sealing Keys (Fast)

If you have backed up sealing keys (`docs/not-git/certs/main.key`):

```bash
# Apply backed-up keys
kubectl apply -f docs/not-git/certs/main.key

# Restart controller to load new keys
kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets

# Wait for rollout
kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets --timeout=60s

# Verify unsealing
kubectl get sealedsecrets -A
# All should show SYNCED: True

# Verify secrets created
kubectl get secret -n external-dns external-dns-cloudflare
kubectl get secret -n minio minio-root-credentials
kubectl get secret -n csi-proxmox proxmox-csi-plugin
```

**Backup sealing keys for future rebuilds:**

```bash
# Export current sealing keys (do this BEFORE cluster rebuild)
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > docs/not-git/certs/main.key

# Store in 1Password vault as well for redundancy
```

#### Option 2: Regenerate All SealedSecrets (Secure)

If backup keys are unavailable or you want fresh credentials:

1. **Generate fresh credentials** for all services (Cloudflare API tokens, Proxmox tokens, MinIO passwords)
2. **Use regeneration script:**

```bash
# Interactive mode (prompts for each credential)
tools/scripts/regenerate-sealed-secrets.fish

# Non-interactive mode (uses environment variables)
export CF_API_TOKEN="<fresh-cloudflare-token>"
export PROXMOX_TOKEN_SECRET="<fresh-proxmox-token>"
export MINIO_ROOT_PASSWORD="<fresh-minio-password>"
# Optional:
export DISCORD_WEBHOOK_URL="<discord-webhook>"
export GITHUB_TOKEN="<github-token>"
export GITHUB_USERNAME="<github-username>"

tools/scripts/regenerate-sealed-secrets.fish --non-interactive
```

1. **Commit and push** regenerated SealedSecrets
2. **Let ArgoCD sync** - applications will automatically use new secrets

---

### cert-manager Certificate Issuance Failures

**Symptom**: Certificate stuck in "Issuing" state for hours, Challenge shows "error getting cloudflare secret: secrets 'cloudflare-api-token' not found"

**Root Cause**: ClusterIssuer `apiTokenSecretRef` looks for secret in the **namespace where the Certificate resource is deployed**, NOT the cert-manager namespace.

**Solution**: Create separate Cloudflare API token SealedSecret in **cert-manager namespace**:

```bash
# Seal the secret (uses fresh or existing Cloudflare API token)
tools/scripts/seal-secret.fish cert-manager cloudflare-api-token api-token="<your-cloudflare-token>" \
  > apps/cluster/cert-manager/templates/sealed-cloudflare-api-token.yaml

# Commit and push
git add apps/cluster/cert-manager/templates/sealed-cloudflare-api-token.yaml
git commit -m "Add cert-manager Cloudflare API token SealedSecret"
git push

# Force ArgoCD refresh
kubectl annotate application cert-manager -n argocd argocd.argoproj.io/refresh=normal --overwrite

# Delete old challenges to force retry
kubectl delete challenge -n traefik --all
kubectl delete order -n traefik --all
kubectl delete certificaterequest -n traefik --all

# Watch certificate issuance
kubectl get certificate -n traefik wildcard-m0sh1-cc -w
```

**Why separate secrets?** external-dns and origin-ca-issuer use different secret names (`external-dns-cloudflare`, `origin-ca-issuer-cloudflare`) in their own namespaces. cert-manager's ClusterIssuer needs its own secret with the exact name referenced in the `apiTokenSecretRef`.

**Lessons Learned:**

- ClusterIssuers are cluster-scoped but secret references are namespace-scoped
- Each component (external-dns, origin-ca-issuer, cert-manager) needs its own SealedSecret
- Secret key names must match exactly (e.g., `api-token` not `cloudflare_api_token`)

---

### SealedSecrets Decryption Issues

**Symptom**: Pods fail with missing secret errors, SealedSecrets show `SYNCED: False` with "no key could decrypt secret" errors

**Diagnosis**:

```bash
kubectl get sealedsecrets -A
kubectl logs -n sealed-secrets deploy/sealed-secrets-controller
```

**Common causes**:

- Sealed secrets controller not running
- Encryption key lost (cluster rebuild - **most common after fresh bootstrap**)
- SealedSecret version mismatch
- Secrets encrypted with different sealing key than controller has

**Resolution**:

#### Option 1: Restore Old Sealing Keys (Fastest)

If you have the sealing keys backed up (e.g., in `docs/not-git/certs/main.key`):

```bash
# Verify controller running
kubectl get pods -n sealed-secrets

# Apply backed-up keys (YAML containing multiple sealed-secrets-key* secrets)
kubectl apply -f docs/not-git/certs/main.key

# Restart controller to pick up keys
kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets

# Wait for rollout
kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets

# Verify SealedSecrets unsealing
sleep 10
kubectl get sealedsecrets -A
# Should show SYNCED: True for all

# Verify actual secrets created
kubectl get secret -n external-dns external-dns-cloudflare
kubectl get secret -n csi-proxmox proxmox-csi-plugin
kubectl get secret -n minio minio-root-credentials
```

**Important**: The backed-up keys must be stored securely (e.g., `docs/not-git/` which is gitignored, or 1Password vault). The `main.key` file contains multiple `sealed-secrets-key*` secrets as a Kubernetes List.

#### Option 2: Regenerate All SealedSecrets (Fresh Start)

If you don't have the old keys or want fresh secrets with updated API credentials:

```bash
# Use the regeneration script (interactive mode)
tools/scripts/regenerate-sealed-secrets.fish

# Or non-interactive with environment variables
set -x CF_API_TOKEN "your_cloudflare_token"
set -x PROXMOX_TOKEN_SECRET "your_proxmox_token_secret"
set -x MINIO_ROOT_PASSWORD "your_minio_password"
tools/scripts/regenerate-sealed-secrets.fish --non-interactive

# Script generates SealedSecret manifests in /tmp directory
# Copy them to appropriate locations and commit to Git
```

**Secrets to regenerate**:

1. **Cloudflare API tokens** (external-dns, origin-ca-issuer)
2. **Proxmox CSI credentials** (proxmox-csi-plugin config.yaml)
3. **MinIO root password** (minio-root-credentials)
4. **ArgoCD Discord webhook** (argocd-notifications-secret) - optional
5. **GitHub repo credentials** (repo-github-m0sh1-infra) - optional

**Helper scripts** for individual secrets:

```bash
# Seal a new secret (generates SealedSecret YAML)
tools/scripts/seal-secret.fish <namespace> <secret-name> key1=value1 key2=value2

# Unseal/decode an existing secret (displays plaintext values)
tools/scripts/unseal-secret.fish <namespace> <secret-name> [key]
```

**After regenerating**:

1. Delete plaintext config files (e.g., `apps/cluster/proxmox-csi/templates/config.yaml`)
2. Commit SealedSecret manifests to Git
3. Let ArgoCD sync the changes
4. Verify pods recover: `kubectl get pods -n external-dns -n csi-proxmox -n minio`

#### Backup Sealing Keys for Future

To prevent this issue on next rebuild:

```bash
# Export current sealing keys
kubectl get secret -n sealed-secrets \
    -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
    -o yaml > docs/not-git/certs/sealed-secrets-keys-backup.yaml

# Store in 1Password vault or secure location (NOT committed to Git)
```

### Storage PVCs Pending

**Symptom**: PersistentVolumeClaims stuck in Pending

**Diagnosis**:

```bash
kubectl describe pvc <pvc-name> -n <namespace>
kubectl get events -n <namespace> | grep <pvc-name>
```

**Common causes**:

- Storage class not available
- Proxmox CSI not deployed
- Insufficient storage on nodes

**Resolution**:

```bash
# Verify storage class exists
kubectl get storageclass

# Check CSI driver pods
kubectl get pods -n proxmox-csi

# Resync storage provider application
argocd app sync proxmox-csi
```

## Maintenance

### Updating Bootstrap Manifests

Bootstrap manifests should remain static. To update ArgoCD configuration:

1. **Modify wrapper chart**: Edit `apps/cluster/argocd/values.yaml`
2. **Commit to Git**: Push changes to repository
3. **Let ArgoCD sync**: Changes apply automatically via GitOps

**Only update bootstrap if**:

- ArgoCD major version upgrade requires new CRDs
- Namespace or RBAC baseline changes
- Disaster recovery procedure evolves

### Regenerating `rendered.yaml`

`cluster/bootstrap/argocd/rendered.yaml` is generated from the ArgoCD wrapper chart:

```bash
# Regenerate bootstrap manifests (CI does this)
tools/ci/render-bootstrap-argocd.sh

# Review changes
git diff cluster/bootstrap/argocd/rendered.yaml
```

**Note**: `rendered.yaml` is excluded from Git (see `.gitignore`). It's used for local testing and CI validation only.

## Recovery Scenarios

### Scenario 1: Accidental ArgoCD Deletion

1. Reapply bootstrap: `kubectl apply -k cluster/bootstrap/argocd/`
2. Deploy root app: `kubectl apply -f argocd/apps/root.yaml`
3. Verify sync: `argocd app list`

**Expected downtime**: 2-5 minutes

### Scenario 2: Cluster Complete Rebuild

1. Deploy 4-VLAN network infrastructure (Terraform, OPNsense)
2. Provision k3s cluster (control plane + workers on VLAN 20)
3. **CRITICAL**: Create Proxmox CSI ZFS datasets on all nodes (see [proxmox-csi-setup.md](proxmox-csi-setup.md))
   - nvme rpool datasets: pgdata, pgwal, registry, caches
   - sata-ssd dataset: minio-data
   - Configure Proxmox storage IDs
4. Follow full bootstrap procedure (Steps 1-6 above)
5. Restore sealed secrets encryption key (if needed)
6. Wait for all applications to sync

**Expected downtime**: 60-120 minutes (includes infrastructure provisioning)

### Scenario 3: ArgoCD Corrupted Configuration

1. Delete ArgoCD namespace: `kubectl delete namespace argocd --force`
2. Wait for full cleanup: `kubectl get namespace argocd` (should 404)
3. Reapply bootstrap: `kubectl apply -k cluster/bootstrap/argocd/`
4. Deploy root app: `kubectl apply -f argocd/apps/root.yaml`
5. Monitor sync: `kubectl get applications -n argocd --watch`

**Expected downtime**: 5-10 minutes

## Security Considerations

### Secrets Management

- **SealedSecrets encryption key**: Stored in 1Password vault, not in cluster
- **ArgoCD credentials**: Managed via wrapper chart, not bootstrap
- **Certificate keys**: Managed by cert-manager after bootstrap

### Access Control

- **Bootstrap manifests**: Require cluster-admin privileges
- **ArgoCD UI**: Access controlled via wrapper chart SSO/RBAC configuration
- **Repository**: Private GitHub repository with branch protection

### Audit Trail

- All bootstrap operations should be logged
- Git commits track all configuration changes
- ArgoCD maintains operation history

## See Also

- [AGENTS.md](../../../AGENTS.md) - Repository enforcement rules
- [docs/layout.md](../../layout.md) - Repository structure
- Infrastructure phase documentation (archived)
- [apps/cluster/argocd/](../../../apps/cluster/argocd/) - ArgoCD wrapper chart (source of truth)
- [cluster/bootstrap/](../../../cluster/bootstrap/) - Bootstrap manifests (recovery only)
