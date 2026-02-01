# RustFS S3-Compatible Object Storage Implementation

**Date:** 2026-01-31
**Status:** ✅ Deployed - RustFS running; S3 API LAN-only, console via Cloudflare Tunnel

## Context

Implementing RustFS as S3-compatible object storage to replace MinIO. MinIO has entered maintenance-only mode (focus shifted to paid AIStor product), while RustFS offers superior performance and a more permissive license (Apache 2.0 vs AGPLv3).

## Decision: RustFS vs Garage

After evaluating alternatives to MinIO, chose **RustFS** over Garage based on:

- **Performance**: RustFS is 2.3x faster than MinIO for small objects (4KB)
- **License**: Apache 2.0 (more permissive, no copyleft obligations)
- **Architecture**: Eliminates GC-related latency spikes, more efficient on constrained hardware
- **Active Development**: RustFS actively developed; MinIO in maintenance mode
- **Simplicity**: Easier deployment and operation than Garage's full duplication strategy

### Research Sources

- Official docs: <https://docs.rustfs.com/installation/>
- CloudPirates chart (selected): <https://artifacthub.io/packages/helm/cloudpirates-rustfs/rustfs>
- CloudPirates chart repo: <https://github.com/CloudPirates-io/helm-charts/tree/main/charts/rustfs>
- Upstream chart repo: <https://github.com/rustfs/rustfs/tree/main/helm>
- ArtifactHub (upstream): <https://artifacthub.io/packages/helm/rustfs/rustfs>

## Problem Encountered

While aligning the initial wrapper with the upstream RustFS chart, we hit two structural limits:

1. **Upstream chart lacks extra env support**
   The upstream chart only renders a fixed configmap. Region/domains/OBS/CORS needed extra env vars, which were not template-supported without patching.

2. **Upstream ingress targets console only**
   The upstream chart’s ingress is console-focused. A separate S3 API ingress needed a wrapper template.

Additionally, `RUSTFS_EXTERNAL_ADDRESS` is deprecated and removed from docs; using it behind Traefik (reverse proxy) can cause routing confusion. We avoid it.

## Solution Implemented

### 1. Switch to CloudPirates chart

- Wrapper dependency uses **CloudPirates RustFS chart** (`0.4.1`).
- Image tag pinned to **`1.0.0-alpha.82`** (newer than CloudPirates default `alpha.64`).
- Chart natively supports **extra env vars** and **consoleIngress**, eliminating wrapper ingress templates.

### 2. Values aligned to homelab needs

- **StatefulSet**, `replicaCount: 1` (RWO PVCs on Proxmox CSI).
- **Auth** via existing Secret with keys `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`.
- **Config**:
  - volumes: `/data`
  - address/console address
  - CORS for `s3.m0sh1.cc` and `s3-console.m0sh1.cc`
  - extraEnvVars for region/domains/OBS settings
- **Ingress** and **consoleIngress** via Traefik with wildcard TLS; external-dns ignored for tunneled hostnames.
- **DNS** via Cloudflare Tunnel CNAME (console) + Unbound overrides (LAN).
- **Data/logs persistence** on Proxmox CSI (`sata-object` for data, `sata-general` for logs).
- **Resources** and **nodeSelector** set for worker nodes.

### 3. Optional upstream patch (documented below)

If we revert to the upstream chart, apply the small extraEnv patch to render additional env vars.

## Optional Upstream Patch (extraEnv)

**Why:** Upstream chart cannot render extra env vars (region/domains/OBS/CORS), and `RUSTFS_EXTERNAL_ADDRESS` is deprecated. The patch adds a safe extension point.

Apply after switching the dependency to the upstream chart and running `helm dependency update`; patch the vendored subchart under `apps/cluster/rustfs/charts/rustfs/`.

**Patch (for upstream chart only; not applied while using CloudPirates):**

```diff
# apps/cluster/rustfs/charts/rustfs/values.yaml
rustfs:
  extraEnv: []
```

```diff
# apps/cluster/rustfs/charts/rustfs/templates/deployment.yaml (or statefulset.yaml)
        env:
          # existing env...
          {{- with .Values.rustfs.extraEnv }}
          {{- toYaml . | nindent 12 }}
          {{- end }}
```

## Architecture

### Internal Access (LAN)

```text
┌─────────────────────────────────────────────────────────────┐
│                    Internal Clients                          │
│                  (LAN / VLAN 20, 30, 40)                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Traefik Ingress                           │
│  TLS: wildcard-s3-m0sh1-cc (cert-manager)                   │
│  DNS: Unbound override (LAN) + Cloudflare Tunnel CNAME      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│           RustFS Pod (StatefulSet, 1 replica)                 │
│  - API Service: ClusterIP :9000                              │
│  - Console Service: ClusterIP :9001                          │
│  - Volumes: /data (75Gi PVC)                                │
│  - Logs: /logs (10Gi PVC)                                   │
│  - Resources: 512Mi-2Gi / 250m-1000m                        │
│  - Node: worker nodes only                                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│            Proxmox CSI ZFS SATA Storage                      │
│  StorageClass: proxmox-csi-zfs-sata-object-retain          │
│  Data: 75Gi | Logs: 10Gi                                    │
│  Policy: Retain (preserves data on chart uninstall)         │
└─────────────────────────────────────────────────────────────┘
```

### External Access (via Cloudflare Tunnel)

```text
┌─────────────────────────────────────────────────────────────┐
│                  External Clients                            │
│            (Anywhere with Internet)                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Cloudflare Zero Trust                           │
│  - Access policies (authentication required)                │
│  - DDoS protection & WAF                                     │
│  - Rate limiting & audit logging                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Cloudflare Tunnel (cloudflared)                │
│  Pod: cloudflared (2 replicas)                              │
│  Route: s3-console.m0sh1.cc → traefik-lan:443              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Traefik Ingress                           │
│  Service: traefik-lan.traefik.svc:443                       │
│  TLS: wildcard-s3-m0sh1-cc                                   │
│  Routes: s3-console.m0sh1.cc → rustfs-console:9001         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│               RustFS Console Service                         │
│  Port: 9001                                                  │
│  Namespace: rustfs                                            │
└─────────────────────────────────────────────────────────────┘
```

### Access Methods Summary

| Endpoint | LAN Access | External Access (CF Tunnel) | Purpose |
|----------|-----------|----------------------------|---------|
| **s3.m0sh1.cc:443** | ✅ Yes | ❌ No (internal only) | S3 API (boto3, aws-cli, SDKs) |
| **s3-console.m0sh1.cc:443** | ✅ Yes | ✅ Yes | Console Web UI (management) |
| **\*.s3.m0sh1.cc:443** | ❌ Not configured | ❌ No | Optional virtual-host bucket access (add wildcard ingress + DNS) |

**Security Layers for External Console Access:**

1. **Cloudflare Zero Trust** - Authentication before reaching network
2. **No Open Ports** - Outbound tunnel only, no inbound firewall rules
3. **RustFS Authentication** - Console login still required after CF auth
4. **Rate Limiting** - Both Cloudflare and RustFS (100 RPM) protect against abuse
5. **Session Timeout** - 30-minute idle timeout enforced

## Deployment Configuration

### Mode

- **StatefulSet**: 1 replica + 1 PVC (starting simple, RWO storage)
- **Future**: Can scale to distributed mode (4 or 16 pods) when needed

### Storage Strategy

- **Data**: 75Gi ZFS SATA pool (optimized for object storage)
- **Logs**: 10Gi ZFS SATA pool (general SATA)
- **Record size**: Defaults to ZFS pool settings (likely 128K or 1M for object storage)
- **Retention**: PVCs retained on uninstall (retain policy)

### Network Strategy

- **API Domain**: `s3.m0sh1.cc` - S3-compatible API endpoint
- **Console Domain**: `s3-console.m0sh1.cc` - Web management UI
- **Bucket Access**: Optional (requires wildcard ingress + DNS override if needed)
- **TLS**: Wildcard certificate from cert-manager
- **DNS**: Cloudflare Tunnel CNAME for `s3-console.m0sh1.cc`; Unbound overrides for LAN (`s3.m0sh1.cc`, `s3-console.m0sh1.cc`). external-dns ignored for these hosts.

### Security Configuration

- **Credentials**: SealedSecret (created and deployed)
- **TLS**: Enabled via cert-manager wildcard certificate
- **CORS**: Restricted to specific domains
- **Rate Limiting**: Console limited to 100 RPM
- **Auth Timeout**: Console sessions expire after 30 minutes
- **Node Placement**: Worker nodes only (no control plane)
- **External Access**: Console exposed via Cloudflare Tunnel with Zero Trust authentication

### ArgoCD Integration

- **Application**: `argocd/apps/cluster/rustfs.yaml`
- **Sync Wave**: 21 (after sealed-secrets, cert-manager, traefik)
- **Namespace**: `rustfs` (auto-created)
- **Sync Policy**: Automated with prune and selfHeal
- **Source**: `apps/cluster/rustfs` (wrapper chart)

## Files Changed

```text
Modified:
  apps/cluster/rustfs/Chart.yaml             (switch to CloudPirates chart, bump wrapper)
  apps/cluster/rustfs/Chart.lock             (refresh dependency lock)
  apps/cluster/rustfs/charts/rustfs/         (updated vendored chart)
  apps/cluster/rustfs/values.yaml            (CloudPirates schema + tag 1.0.0-alpha.82)
  docs/diaries/rustfs-implementation.md      (document decisions + patch)

Removed:
  apps/cluster/rustfs/templates/console-ingress.yaml
  apps/cluster/rustfs/templates/endpoint-ingress.yaml

Preserved:
  argocd/apps/cluster/rustfs.yaml  (already correct, no changes needed)
```

## Validation Commands

```bash
# Update dependencies
cd apps/cluster/rustfs
helm dependency update

# Lint the chart
helm lint .

# Render templates (check output)
helm template rustfs . --namespace rustfs

# Validate against Kubernetes schemas
helm template rustfs . --namespace rustfs | kubeconform -

# Run full validation suite
cd ../../..
mise run k8s-lint

# Check for secret leaks
mise run sensitive-files

# Verify repo structure
mise run path-drift
```

## Next Steps

### 1. Generate and Seal Credentials ✅ COMPLETE

**COMPLETED** - SealedSecret created at:
`apps/cluster/secrets-cluster/rustfs-root-credentials.sealedsecret.yaml`

Keys correctly formatted:

- `RUSTFS_ACCESS_KEY` (uppercase with underscores)
- `RUSTFS_SECRET_KEY` (uppercase with underscores)

### 2. Configure Cloudflare Zero Trust ✅ COMPLETE

For external Console access, configure access policy in Cloudflare dashboard:

```text
Application: s3-console.m0sh1.cc
Policy: Require email (your email) OR Require WARP
Session Duration: 8 hours
Optional: Add GitHub OAuth, Google Workspace, or WebAuthn
```

### 3. Commit Changes ✅ COMPLETE

```bash
git add apps/cluster/rustfs/ docs/diaries/rustfs-implementation.md
git commit -m "feat(rustfs): switch to CloudPirates chart

- Use CloudPirates RustFS chart (0.4.1) with image tag 1.0.0-alpha.82
- Configure StatefulSet + Proxmox CSI persistence
- Enable API + console ingresses via Traefik
- Wire existing root credential secret and extra env vars
- Document upstream extraEnv patch option

Replaces MinIO (maintenance mode) with actively developed RustFS.
Performance: 2.3x faster for small objects, Apache 2.0 license."
```

### 4. ArgoCD Sync ✅ COMPLETE

```bash
# ArgoCD will automatically detect and sync both applications
# Watch RustFS progress:
kubectl get application -n argocd rustfs -w

# Watch cloudflared progress:
kubectl get application -n argocd cloudflared -w

# Check RustFS pod status:
kubectl get pods -n rustfs -w

# View RustFS logs:
kubectl logs -n rustfs -l app.kubernetes.io/name=rustfs -f
```

### 5. Verify Deployment 🔄

```bash
# Check ingresses created
kubectl get ingress -n rustfs

# Expected:
# NAME                    HOSTS                 ADDRESS   PORTS
# rustfs                  s3.m0sh1.cc           ...       80,443
# rustfs-console          s3-console.m0sh1.cc   ...       80,443

# Verify DNS (LAN)
dig @10.0.30.1 s3.m0sh1.cc
dig @10.0.30.1 s3-console.m0sh1.cc

# Verify DNS (public) - should resolve to Cloudflare tunnel for console only
dig s3-console.m0sh1.cc

# Test S3 API (LAN)
aws s3 ls --endpoint-url https://s3.m0sh1.cc

# Test S3 API with mc (local port-forward)
# See docs/diaries/mc.md for setup details
mc ls rustfs

# Access Console UI (LAN)
# Open: https://s3-console.m0sh1.cc

# Test external Console access (from outside LAN)
# Open: https://s3-console.m0sh1.cc
# Should be prompted by Cloudflare Zero Trust login
# Then prompted by RustFS Console login

# CNPG backup verification (RustFS)
# Example:
# mc ls --recursive rustfs/cnpg-backups/cnpg-main/
```

## Future Enhancements

### Phase 2: Observability

- [ ] Configure Prometheus metrics scraping
- [ ] Create Grafana dashboards for S3 operations
- [ ] Set up alerting for storage capacity and performance

### Phase 3: High Availability

- [ ] Switch to distributed mode (4 pods with 4 PVCs each)
- [ ] Configure pod anti-affinity across nodes
- [ ] Test failover scenarios

### Phase 4: Encryption at Rest

- [ ] Enable KMS (Key Management Service)
- [ ] Configure Vault backend for KMS
- [ ] Implement encryption for sensitive buckets

### Phase 5: Advanced Features

- [ ] Configure bucket lifecycle policies
- [ ] Set up bucket replication for backups
- [ ] Enable versioning for critical buckets
- [ ] Implement bucket policies and access control

## Lessons Learned

1. **Always verify upstream chart requirements** - Secret key naming conventions vary between charts
2. **Chart capabilities differ** - CloudPirates chart supports extra env vars; upstream requires a small patch
3. **Separate ingresses for separate concerns** - API and Console need different domains/configurations
4. **Avoid deprecated env vars** - `RUSTFS_EXTERNAL_ADDRESS` is deprecated and removed from docs
5. **Resource limits are non-negotiable** - Empty `resources: {}` unsuitable for production
6. **Documentation research is essential** - Checked official docs and multiple charts before implementation
7. **GitOps principles maintained** - No imperative operations, all declarative through Git

## References

- **Official Docs**: <https://docs.rustfs.com/installation/>
- **Helm Chart (CloudPirates)**: <https://artifacthub.io/packages/helm/cloudpirates-rustfs/rustfs> (v0.4.1)
- **GitHub**: <https://github.com/rustfs/rustfs>
- **Context7 Docs**: Retrieved via /rustfs/rustfs library ID
- **Memory Bank**: `/memories/rustfs-implementation.md`
- **ArgoCD Application**: `argocd/apps/cluster/rustfs.yaml`
- **Wrapper Chart**: `apps/cluster/rustfs/` (v0.3.0)
