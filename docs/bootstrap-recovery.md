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
│   ├── install.yaml         # Minimal ArgoCD installation
│   └── rendered.yaml        # Full ArgoCD config (generated, not committed)
└── cert-manager/
    └── crds.yaml            # cert-manager CRDs
```

### Key Principles

1. **Minimal scope**: Bootstrap contains only what's needed to get ArgoCD running
2. **Immutable**: Bootstrap manifests rarely change; ArgoCD manages everything after handoff
3. **Reproducible**: `rendered.yaml` is generated from `apps/cluster/argocd/` wrapper chart
4. **Single source of truth**: Wrapper chart is authoritative; bootstrap derives from it

## Prerequisites

Before starting recovery:

1. **Cluster access**: `kubectl cluster-info` succeeds
2. **Repository access**: Clone `https://github.com/sm-moshi/infra.git`
3. **Sealed secrets controller**: If redeploying cluster, bootstrap sealed-secrets first
4. **Storage classes**: Proxmox CSI or local-path must be available
5. **Network connectivity**: Cluster can pull images from registries

## Bootstrap Procedure

### Step 1: Verify Prerequisites

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify nodes ready
kubectl get nodes

# Check storage classes available
kubectl get storageclass

# Confirm repository current
cd /path/to/infra
git pull origin main
git status
```

### Step 2: Apply cert-manager CRDs (if needed)

```bash
# cert-manager CRDs must exist before ArgoCD installs cert-manager
kubectl apply -f cluster/bootstrap/cert-manager/crds.yaml

# Wait for CRDs to be established
kubectl wait --for=condition=Established \
  crd/certificates.cert-manager.io \
  crd/issuers.cert-manager.io \
  crd/clusterissuers.cert-manager.io \
  --timeout=60s
```

### Step 3: Bootstrap ArgoCD

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

### Step 4: Deploy Root Application

```bash
# Apply the app-of-apps root
kubectl apply -f argocd/apps/root.yaml

# Verify root application created
kubectl get application -n argocd infra-root

# Watch applications appear
kubectl get applications -n argocd --watch
```

### Step 5: Let ArgoCD Take Over

ArgoCD will now automatically sync all applications via the root app-of-apps pattern:

```bash
# Monitor sync progress
argocd app list

# Check for sync errors
argocd app get infra-root --refresh

# View cluster-wide application health
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

### Step 6: Verify Critical Applications

After root application syncs, verify critical infrastructure:

```bash
# Check ArgoCD itself (should be managed by GitOps now)
kubectl get application -n argocd argocd

# Verify cert-manager
kubectl get pods -n cert-manager

# Check ingress controller
kubectl get pods -n traefik

# Verify sealed-secrets
kubectl get pods -n sealed-secrets

# Confirm storage provisioners
kubectl get pods -n proxmox-csi
```

## Post-Bootstrap Validation

### ArgoCD UI Access

```bash
# Get initial admin password (if using default auth)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward to access UI locally
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Access: `https://localhost:8080`

### Verify Automated Sync

```bash
# Confirm automated sync policies active
argocd app get valkey -o json | jq '.spec.syncPolicy'

# Check for out-of-sync applications
argocd app list --sync-status OutOfSync

# Force sync if needed
argocd app sync <app-name>
```

### Validate Storage

```bash
# Check PVCs bound
kubectl get pvc -A

# Verify volumes provisioned
kubectl get pv

# Test storage with temp pod if needed
kubectl run storage-test --image=busybox --rm -it -- sh
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
argocd app get <app-name>
kubectl describe application -n argocd <app-name>
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

**Symptom**: Pods fail with missing secret errors

**Diagnosis**:

```bash
kubectl get sealedsecrets -A
kubectl logs -n sealed-secrets deploy/sealed-secrets-controller
```

**Common causes**:

- Sealed secrets controller not running
- Encryption key lost (cluster rebuild)
- SealedSecret version mismatch

**Resolution**:

```bash
# Verify controller running
kubectl get pods -n sealed-secrets

# Regenerate sealed secrets if key lost (requires 1Password vault)
# ... (detailed regeneration steps would go here)
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

1. Provision new cluster (k3s, Proxmox VMs, networking)
2. Install Proxmox CSI or local-path storage
3. Follow full bootstrap procedure (Steps 1-6 above)
4. Restore sealed secrets encryption key (if needed)
5. Wait for all applications to sync

**Expected downtime**: 30-60 minutes

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

- [AGENTS.md](../AGENTS.md) - Repository enforcement rules
- [docs/layout.md](layout.md) - Repository structure
- [docs/checklist.md](checklist.md) - Infrastructure phases
- [apps/cluster/argocd/](../apps/cluster/argocd/) - ArgoCD wrapper chart (source of truth)
- [cluster/bootstrap/](../cluster/bootstrap/) - Bootstrap manifests (recovery only)
