# Harbor CNPG Integration Implementation Plan

**Date:** 2026-02-01
**Status:** Planning
**Agent:** m0sh1-devops
**Context:** Harbor needs CNPG PostgreSQL integration, MinIO S3 backup configuration, and Proxmox CSI storage class fixes

---

## Executive Summary

Harbor is currently configured with the **per-app CNPG cluster pattern** (2026-01-16 architecture decision) but uses **outdated storage class references**. The migration from shared `cnpg-main` cluster to per-app clusters completed, but Harbor's storage classes and CNPG backup configuration weren't updated to match the new Proxmox CSI naming scheme introduced during the 4-VLAN infrastructure rebuild.

### Critical Findings

1. **Storage Class Naming Mismatch**: Harbor references non-existent classes (`proxmox-csi-zfs-pgdata-retain`, `proxmox-csi-zfs-pgwal-retain`, `proxmox-csi-zfs-registry-retain`)
2. **CNPG Backup Missing**: No S3 backup/WAL archiving configured for Harbor's PostgreSQL cluster
3. **Valkey Storage Class**: Also needs fix (uses outdated `pgdata-retain` reference)
4. **Secret Management**: 9 Harbor secrets must exist before deployment
5. **MinIO Integration**: `cnpg-backups` bucket must be created for PostgreSQL backups

---

## Logbook

### 2026-02-02

- Added Harbor component resource defaults and node placement preferences for 4-worker cluster (prefer `pve-01`, then `pve-02`, worker-only, no tolerations).
- Raised registry and Trivy memory requests to reduce cache thrash; trimmed some CPU requests to avoid overcommitting 6-10Gi workers.
- Added CNPG cluster template support for `postgresql.nodeSelector`, `postgresql.tolerations`, and `postgresql.affinity`.
- Proxy cache plan: keep Harbor proxy caches (hub/ghcr/quay/k8s) and enable k3s mirror rewrites later via `k3s_enable_harbor_mirrors` in Ansible; likely remove `dhi.io` auth due to HTTPS proxy issues observed with Docker.
- Relaxed controller scheduling (cert-manager, traefik, metallb, tailscale proxyclass) to prefer workers but allow labctrl.
- Added PriorityClass `m0sh1-core` and applied to ArgoCD + cert-manager.
- Added PDBs for CNPG, Valkey, and MinIO tenant.
- Labeled nodes with `topology.kubernetes.io/zone` (pve-01/02/03) for spread rules.
- Rotated Harbor SealedSecrets (admin/core/jobservice/registry/valkey/postgres/build user) with fresh randomized values; `harbor-robot-gitea` resealed with placeholder credentials (update after Harbor bootstrap creates real robot token).
- Phase 4 started: updated Harbor storage classes to `proxmox-csi-zfs-nvme-fast-retain` / `proxmox-csi-zfs-nvme-general-retain` / `proxmox-csi-zfs-sata-object-retain`, added CNPG barman backups to `s3://cnpg-backups/harbor/`, and bumped wrapper chart version to `0.4.18`.
- Phase 3 complete: verified Harbor SealedSecrets and derived Secrets present in `apps` (`harbor-*`, including `harbor-robot-gitea`).
- Phase 4 verified: `apps/user/harbor/Chart.yaml` at `0.4.18`, storage classes updated in `values.yaml`/templates, barman backup stanza present in `postgres-cluster.yaml`.
- Access requirement confirmed: Harbor must be reachable via Cloudflare Tunnel, Tailscale, and LAN (to be enforced in ingress/tunnel config).
- Status update: Harbor app healthy, CNPG cluster healthy, WAL archiving to MinIO confirmed, registry endpoint save error resolved, and Docker login to Harbor succeeded.

---

## Status Update (2026-02-02)

- ArgoCD apps `harbor`, `cloudnative-pg`, and `minio-tenant` are Synced/Healthy.
- CNPG cluster `harbor-postgres` is Healthy and Primary is ready.
- Harbor pods running: core, portal, registry, jobservice, trivy.
- Harbor PVCs bound: postgres, postgres-wal, jobservice, trivy (registry uses MinIO S3, no PVC).
- Harbor core logs show successful DB registration and migration.
- WAL archiving to MinIO confirmed in `harbor-postgres` logs.
- Registry endpoint save error `crypto/aes: invalid key size 48` resolved.
- `docker login harbor.m0sh1.cc` succeeded (harbor-build).

**Remaining Verification:**

- Verify MinIO object listing for `s3://cnpg-backups/harbor/` (WAL/data files).
- Optional: add ScheduledBackup for `harbor-postgres` if periodic backups are desired.
- Verify Harbor bootstrap job outputs (proxy caches, projects, robots) if not already confirmed.
- Validate proxy cache hits from nodes for docker.io/ghcr.io/quay.io/registry.k8s.io/dhi.io.

---

## Architecture Context

### Memory Bank Status: ACTIVE

**From decisionLog.md:**

- **2026-01-16 Decision**: Migrate from shared CNPG cluster to per-app CNPG clusters
  - Each app (Harbor, Gitea, Semaphore) gets dedicated PostgreSQL Cluster CRD
  - Clusters templated directly in app wrapper charts (NOT Helm dependencies)
  - Service naming: `{{ .Release.Name }}-postgres-rw.apps.svc.cluster.local:5432`
  - Existing SealedSecrets unchanged, just referenced by new cluster

**From progress.md:**

- Phase 2: GitOps Core (current phase - apps deployment)
- Fresh cluster deployment with proper node labels (2026-01-28)
- 5-node cluster: 1 control plane + 4 workers across 3 Proxmox nodes
- Proxmox CSI with 4 datasets: nvme-fast (pgdata), nvme-general (pgwal), sata-general, sata-object (minio/object storage)

**From systemPatterns.md:**

- Wrapper chart pattern: Chart.yaml + values.yaml + templates/ (no README.md)
- ArgoCD app-of-apps with automated sync (prune + selfHeal)
- SealedSecrets for all credentials (Bitnami pattern)
- Per-app CNPG clusters with MinIO S3 backups

---

## Component Documentation Analysis

### CloudNativePG (CNPG) Best Practices

**Key Insights from `/cloudnative-pg/cloudnative-pg`:**

#### Backup & Recovery Architecture

```yaml
# CNPG Cluster with S3 Backup Configuration
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-with-backup
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised

  storage:
    storageClass: fast-ssd  # nvme-fast for 16K recordsize
    size: 10Gi

  walStorage:
    storageClass: wal-storage  # nvme-general for 128K recordsize
    size: 5Gi

  backup:
    barmanObjectStore:
      destinationPath: s3://my-postgres-backups/
      endpointURL: https://s3.amazonaws.com  # MinIO: https://minio.minio-tenant.svc.cluster.local:443
      s3Credentials:
        accessKeyId:
          name: aws-creds  # cnpg-backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: aws-creds  # cnpg-backup-credentials
          key: ACCESS_SECRET_KEY
      wal:
        compression: zstd  # Better than gzip for WAL
        maxParallel: 2
      data:
        compression: snappy  # For base backups
        jobs: 2
    retentionPolicy: "30d"
    target: prefer-standby  # Reduce load on primary
```

**Critical CNPG Concepts:**

1. **WAL Archiving vs Base Backups**:
   - **WAL** (Write-Ahead Log): Continuous streaming backup for PITR
   - **Base Backups**: Full snapshots for recovery starting point
   - Both stored in S3-compatible object storage (MinIO)

2. **Barman Cloud Plugin**:
   - Implements backup operations: `barman-cloud-wal-archive`, `barman-cloud-backup`
   - Handles compression (zstd for WAL, snappy for data)
   - Manages retention policies automatically

3. **Storage Class Requirements**:
   - **PGDATA**: Small random I/O → 16K recordsize ZFS → `nvme-fast`
   - **PGWAL**: Sequential writes → 128K recordsize ZFS → `nvme-general`
   - Separate volumes improve I/O performance and reliability

4. **Point-In-Time Recovery (PITR)**:

   ```yaml
   bootstrap:
     recovery:
       source: origin
       recoveryTarget:
         targetTime: "2025-01-13 14:30:00.000000+00"
   ```

5. **Scheduled Backups**:

   ```yaml
   apiVersion: postgresql.cnpg.io/v1
   kind: ScheduledBackup
   metadata:
     name: daily-backup
   spec:
     schedule: "0 0 2 * * *"  # Daily at 2 AM (6-field cron with seconds)
     backupOwnerReference: self
     cluster:
       name: cluster-with-backup
     method: barmanObjectStore
     target: prefer-standby
   ```

**Harbor-Specific Recommendations:**

- Enable `prefer-standby` target to reduce primary load during backups
- Use `zstd` compression for WAL (better compression ratio than gzip)
- Set retention to 30 days (matches project backup policy)
- Configure `immediateCheckpoint: false` to reduce I/O spikes

---

### Harbor Helm Chart Best Practices

**Key Insights from `/goharbor/harbor-helm`:**

#### External PostgreSQL Configuration

```yaml
database:
  type: external
  external:
    host: postgresql.example.com  # harbor-postgres-rw.apps.svc.cluster.local
    port: "5432"
    username: harbor
    coreDatabase: harbor
    existingSecret: harbor-postgres-auth
    sslmode: "disable"  # Internal cluster communication
  maxIdleConns: 20
  maxOpenConns: 100
```

**Critical Concepts:**

1. **Database Connection String**: Harbor requires the **core database name** to be `harbor` (matches CNPG Database CRD)
2. **SSL Mode**: Use `disable` for in-cluster communication (no TLS overhead)
3. **Connection Pooling**: `maxOpenConns: 100` prevents connection exhaustion under load
4. **Secret Format**: `existingSecret` must contain `HARBOR_DATABASE_PASSWORD` key

#### External Redis/Valkey Configuration

```yaml
redis:
  type: external
  external:
    addr: valkey.apps.svc.cluster.local:6379
    # Harbor uses multiple Redis databases for different purposes
    coreDatabaseIndex: "0"
    jobserviceDatabaseIndex: "1"
    registryDatabaseIndex: "2"
    trivyAdapterIndex: "5"
```

**Critical Concepts:**

1. **Database Indices**: Harbor multiplexes single Redis/Valkey instance with logical databases
2. **No Authentication**: Current Valkey deployment has `auth.enabled: false` (acceptable for internal cluster)
3. **Connection String**: Must be `host:port` format (no `redis://` scheme)

#### Persistence & Storage

```yaml
persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      existingClaim: harbor-registry
      storageClass: ""  # Use existing PVC
      accessMode: ReadWriteOnce
      size: 100Gi
    jobservice:
      jobLog:
        existingClaim: harbor-jobservice
        storageClass: ""
        size: 5Gi
    trivy:
      existingClaim: harbor-trivy
      storageClass: ""
      size: 20Gi
```

**Critical Concepts:**

1. **Registry Storage**: Large sequential I/O → use `sata-object-retain` (1M recordsize)
2. **Jobservice Logs**: Small files → use `nvme-fast-retain` (16K recordsize)
3. **Trivy Cache**: Vulnerability DB → use `nvme-fast-retain` (frequently accessed)
4. **PVC Management**: Use `helm.sh/resource-policy: keep` to prevent accidental deletion

#### High Availability Considerations

```yaml
portal:
  replicas: 2
core:
  replicas: 2
jobservice:
  replicas: 2
registry:
  replicas: 2

# Pod Anti-Affinity
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: harbor
```

**Current Implementation**: Single replica (Phase 2 focus on stability over HA)
**Future Enhancement**: Multi-replica with anti-affinity after Phase 3

#### Quota Update Provider

```yaml
core:
  quotaUpdateProvider: redis  # Use Redis instead of DB for high-concurrency pushes
```

**Recommendation**: Keep `redis` setting - improves performance for concurrent image pushes to same project

---

### Valkey (Redis) Best Practices

**Key Insights from `/valkey-io/valkey-doc`:**

#### Persistence Configuration

```yaml
# Valkey supports RDB + AOF persistence
appendonly: yes  # Append-Only File for durability
save: "900 1 300 10 60 10000"  # RDB snapshots at intervals
```

**Critical Concepts:**

1. **AOF (Append-Only File)**: Every write logged, slower but more durable
2. **RDB (Snapshot)**: Periodic full snapshots, faster but risk of data loss
3. **Hybrid Approach**: Enable both for balance of performance and durability

**Current Valkey Deployment:**

- Storage: 10Gi on `proxmox-csi-zfs-pgdata-retain` (NEEDS FIX → `nvme-fast-retain`)
- Auth: Disabled (acceptable for internal cluster communication)
- Replicas: Disabled (single instance) - acceptable for Phase 2
- Deployment Strategy: `Recreate` (prevents multi-attach with ReadWriteOnce PVC)

**Recommendation**: Keep current simple configuration for Phase 2. Enable replication in Phase 4 (Expansion Features).

---

### MinIO S3 Object Storage

**Key Insights from Current Configuration:**

#### MinIO Deployment

MinIO is deployed via `apps/cluster/minio-tenant` (tenant CR). Use the tenant S3 endpoint below.

**S3 Endpoint for CNPG**: `https://minio.minio-tenant.svc.cluster.local:443`

**Required Actions:**

1. Create `cnpg-backups` bucket in MinIO console (<https://s3-console.m0sh1.cc>)
2. Generate access keys for CNPG backup operations
3. Store credentials in `cnpg-backup-credentials` SealedSecret
4. Test bucket access from CNPG pods

**Bucket Structure:**

```text
s3://cnpg-backups/
├── harbor/
│   ├── base/
│   │   └── 20260201T020000/  # Base backup snapshots
│   └── wals/
│       └── 0000000100000000/  # WAL archive segments
├── gitea/
└── semaphore/
```

---

## Current vs Desired State

### Storage Classes Comparison

| Current Reference                 | Status          | Should Be                                | Purpose                          |
|-----------------------------------|-----------------|------------------------------------------|----------------------------------|
| `proxmox-csi-zfs-pgdata-retain`   | ❌ NON-EXISTENT | `proxmox-csi-zfs-nvme-fast-retain`       | PostgreSQL data (16K recordsize) |
| `proxmox-csi-zfs-pgwal-retain`    | ❌ NON-EXISTENT | `proxmox-csi-zfs-nvme-general-retain`    | PostgreSQL WAL (128K recordsize) |
| `proxmox-csi-zfs-registry-retain` | ❌ NON-EXISTENT | (unused; registry uses MinIO S3)        | Harbor registry (S3 via MinIO)    |
| `proxmox-csi-zfs-caches-delete`   | ❌ NON-EXISTENT | `proxmox-csi-zfs-nvme-fast-retain`       | Trivy cache                      |

### Available Storage Classes

From [apps/cluster/proxmox-csi/templates/storageclasses.yaml](../../apps/cluster/proxmox-csi/templates/storageclasses.yaml):

1. **`proxmox-csi-zfs-nvme-fast-retain`** (default)
   - ZFS dataset: `rpool/k8s/nvme-fast`
   - Recordsize: 16K (optimal for PostgreSQL PGDATA)
   - Cache: `directsync`
   - Use cases: Database data, application state, small random I/O

2. **`proxmox-csi-zfs-nvme-general-retain`**
   - ZFS dataset: `rpool/k8s/nvme-general`
   - Recordsize: 128K (optimal for PostgreSQL WAL)
   - Cache: `none`
   - Use cases: Sequential writes, WAL logs, streaming data

3. **`proxmox-csi-zfs-sata-general-retain`**
   - ZFS dataset: `sata-ssd/k8s/general`
   - Recordsize: default (128K)
   - Cache: `none`
   - Use cases: General-purpose SATA SSD storage

4. **`proxmox-csi-zfs-sata-object-retain`**
   - ZFS dataset: `sata-ssd/k8s/object`
   - Recordsize: 1M (optimal for large object storage)
   - Cache: `none`
   - Use cases: Container images, backups, large files (MinIO, Harbor registry)

---

## Required Changes

### Summary

**Files to Modify:** 4
**Prerequisites:** 6
**Estimated Implementation Time:** 2-3 hours (excluding secret creation)

### Change 1: Harbor PostgreSQL Storage Classes

**File:** [apps/user/harbor/values.yaml](../../apps/user/harbor/values.yaml#L7-L14)

**Current:**

```yaml
postgresql:
  enabled: true
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:18.1-system-trixie
  storage:
    size: 40Gi
    # ZFS dataset rpool/k8s/pgdata with 16K recordsize - optimized for PostgreSQL small random I/O
    storageClass: proxmox-csi-zfs-pgdata-retain  # ❌ NON-EXISTENT
  walStorage:
    size: 10Gi
    # ZFS dataset rpool/k8s/pgwal with 128K recordsize - optimized for PostgreSQL WAL sequential writes
    storageClass: proxmox-csi-zfs-pgwal-retain  # ❌ NON-EXISTENT
```

**Required:**

```yaml
postgresql:
  enabled: true
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:18.1-system-trixie
  storage:
    size: 40Gi
    # ZFS dataset rpool/k8s/nvme-fast with 16K recordsize - optimized for PostgreSQL small random I/O
    storageClass: proxmox-csi-zfs-nvme-fast-retain  # ✅ CORRECT
  walStorage:
    size: 10Gi
    # ZFS dataset rpool/k8s/nvme-general with 128K recordsize - optimized for PostgreSQL WAL sequential writes
    storageClass: proxmox-csi-zfs-nvme-general-retain  # ✅ CORRECT
```

**Rationale:** Match actual Proxmox CSI storage class names. CNPG benefits from separate storage classes optimized for different I/O patterns.

---

### Change 2: Harbor PVC Storage Classes

**File:** [apps/user/harbor/templates/pvc.yaml](../../apps/user/harbor/templates/pvc.yaml)

**Current (Line 11):**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-registry
  namespace: apps
  annotations:
    helm.sh/resource-policy: keep
    argocd.argoproj.io/sync-options: Prune=false
spec:
  storageClassName: proxmox-csi-zfs-registry-retain  # ❌ NON-EXISTENT
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

**Required (Line 11):**

```yaml
  storageClassName: proxmox-csi-zfs-sata-object-retain  # ✅ CORRECT (1M recordsize)
```

**Current (Line 28):**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-jobservice
  namespace: apps
  annotations:
    helm.sh/resource-policy: keep
    argocd.argoproj.io/sync-options: Prune=false
spec:
  storageClassName: proxmox-csi-zfs-pgdata-retain  # ❌ NON-EXISTENT
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

**Required (Line 28):**

```yaml
  storageClassName: proxmox-csi-zfs-nvme-fast-retain  # ✅ CORRECT (16K recordsize)
```

**Current (Line ~45, needs verification):**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-trivy
  namespace: apps
  annotations:
    helm.sh/resource-policy: keep
    argocd.argoproj.io/sync-options: Prune=false
spec:
  storageClassName: proxmox-csi-zfs-caches-delete  # ❌ NON-EXISTENT (likely)
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

**Required (Line ~45):**

```yaml
  storageClassName: proxmox-csi-zfs-nvme-fast-retain  # ✅ CORRECT (frequently accessed DB)
```

**Rationale:**

- **Registry (100Gi)**: Large container images → SATA SSD with 1M recordsize for sequential reads
- **Jobservice (5Gi)**: Small log files → NVMe with 16K recordsize for random writes
- **Trivy (20Gi)**: Vulnerability database → NVMe for fast lookups

---

### Change 3: Harbor CNPG Backup Configuration

**File:** [apps/user/harbor/templates/postgres-cluster.yaml](../../apps/user/harbor/templates/postgres-cluster.yaml)

**Current (ends at line 59):**

```yaml
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "2621kB"
      huge_pages: "off"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
{{- end }}
```

**Required (add after line 59, before `{{- end }}`):**

```yaml
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "2621kB"
      huge_pages: "off"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      # Enable WAL archiving for backup
      archive_mode: "on"
      archive_timeout: "5min"

  # --- Barman Cloud backup configuration ---
  backup:
    barmanObjectStore:
      destinationPath: s3://cnpg-backups/harbor/
      endpointURL: https://minio.minio-tenant.svc.cluster.local:443
      s3Credentials:
        accessKeyId:
          name: cnpg-backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: cnpg-backup-credentials
          key: ACCESS_SECRET_KEY
      wal:
        compression: zstd  # Superior compression for WAL
        maxParallel: 2     # Concurrent WAL archiving
      data:
        compression: snappy  # Fast compression for base backups
        jobs: 2             # Parallel backup jobs
    retentionPolicy: "30d"  # Keep backups for 30 days
    target: prefer-standby  # Backup from standby if available (future HA)

  # Optional: Enable Point-In-Time Recovery
  externalClusters: []
{{- end }}
```

**Rationale:**

- **WAL Archiving**: Enables continuous backup for PITR (Point-In-Time Recovery)
- **Compression**: `zstd` for WAL (better ratio), `snappy` for base backups (speed)
- **Retention**: 30-day policy matches project backup standards
- **Target**: `prefer-standby` reduces primary load (ready for future HA)
- **Credentials**: Shared `cnpg-backup-credentials` secret across all CNPG clusters

---

### Change 4: Harbor PostgreSQL Storage Defaults in Template

**File:** [apps/user/harbor/templates/postgres-cluster.yaml](../../apps/user/harbor/templates/postgres-cluster.yaml#L21-L26)

**Current:**

```yaml
  # PostgreSQL data storage - optimized for small random I/O (16K recordsize)
  storage:
    size: {{ .Values.postgresql.storage.size | default "40Gi" }}
    storageClass: {{ .Values.postgresql.storage.storageClass | default "proxmox-csi-zfs-pgdata-retain" }}

  # PostgreSQL WAL storage - optimized for sequential writes (128K recordsize)
  walStorage:
    size: {{ .Values.postgresql.walStorage.size | default "10Gi" }}
    storageClass: {{ .Values.postgresql.walStorage.storageClass | default "proxmox-csi-zfs-pgwal-retain" }}
```

**Required:**

```yaml
  # PostgreSQL data storage - optimized for small random I/O (16K recordsize)
  storage:
    size: {{ .Values.postgresql.storage.size | default "40Gi" }}
    storageClass: {{ .Values.postgresql.storage.storageClass | default "proxmox-csi-zfs-nvme-fast-retain" }}

  # PostgreSQL WAL storage - optimized for sequential writes (128K recordsize)
  walStorage:
    size: {{ .Values.postgresql.walStorage.size | default "10Gi" }}
    storageClass: {{ .Values.postgresql.walStorage.storageClass | default "proxmox-csi-zfs-nvme-general-retain" }}
```

**Rationale:** Ensure template defaults match actual storage classes. Prevents deployment failures if values.yaml is misconfigured.

---

### Change 5: Harbor values.yaml Migration Section

**File:** [apps/user/harbor/values.yaml](../../apps/user/harbor/values.yaml#L207-L220)

**Current:**

```yaml
migration:
  pvcs:
    enabled: false
    registry:
      name: harbor-registry
      storageClass: proxmox-csi-zfs-registry-retain  # ❌ NON-EXISTENT
      size: 100Gi
      accessMode: ReadWriteOnce
    jobservice:
      name: harbor-jobservice
      storageClass: proxmox-csi-zfs-pgdata-retain     # ❌ NON-EXISTENT
      size: 5Gi
    database:
      name: harbor-database
      storageClass: proxmox-csi-zfs-pgdata-retain
      size: 5Gi
    trivy:
      name: harbor-trivy
      storageClass: proxmox-csi-zfs-caches-delete     # ❌ NON-EXISTENT
      size: 20Gi
```

**Required:**

```yaml
migration:
  pvcs:
    enabled: false
    registry:
      name: harbor-registry
      storageClass: proxmox-csi-zfs-sata-object-retain  # ✅ Large object storage
      size: 100Gi
      accessMode: ReadWriteOnce
    jobservice:
      name: harbor-jobservice
      storageClass: proxmox-csi-zfs-nvme-fast-retain    # ✅ Small files
      size: 5Gi
    database:
      name: harbor-database
      storageClass: proxmox-csi-zfs-nvme-fast-retain    # ✅ (Not used - per-app CNPG)
      size: 5Gi
    trivy:
      name: harbor-trivy
      storageClass: proxmox-csi-zfs-nvme-fast-retain    # ✅ Frequent access
      size: 20Gi
```

**Rationale:** Update migration section for consistency, even though `enabled: false`. Ensures documentation accuracy.

---

### Change 6: Valkey Storage Class Fix

**File:** [apps/cluster/valkey/values.yaml](../../apps/cluster/valkey/values.yaml#L26)

**Current:**

```yaml
valkey:
  auth:
    enabled: false

  dataStorage:
    enabled: true
    requestedSize: 10Gi
    className: proxmox-csi-zfs-pgdata-retain  # ❌ NON-EXISTENT
```

**Required:**

```yaml
valkey:
  auth:
    enabled: false

  dataStorage:
    enabled: true
    requestedSize: 10Gi
    className: proxmox-csi-zfs-nvme-fast-retain  # ✅ CORRECT
```

**Rationale:** Valkey persistence (AOF/RDB) uses small random writes → NVMe with 16K recordsize optimal.

---

## Prerequisites & Dependencies

### 1. CNPG Operator Deployed ✅

**Status:** Should already be deployed via [apps/cluster/cloudnative-pg](../../apps/cluster/cloudnative-pg/)

**Verification:****

```bash
kubectl get pods -n cnpg-system
kubectl get crds | grep postgresql.cnpg.io
```

**Expected Output:**

```text
NAME                                     READY   STATUS    RESTARTS   AGE
cloudnative-pg-controller-manager-xxx    1/1     Running   0          5d
```

---

### 2. Proxmox CSI Storage Classes ✅

**Status:** Should already be deployed via [apps/cluster/proxmox-csi](../../apps/cluster/proxmox-csi/)

**Verification:****

```bash
kubectl get sc | grep proxmox-csi-zfs
```

**Expected Output:**

```text
proxmox-csi-zfs-nvme-fast-retain (default)   csi.proxmox.sinextra.dev   Delete          WaitForFirstConsumer   true
proxmox-csi-zfs-nvme-general-retain          csi.proxmox.sinextra.dev   Delete          WaitForFirstConsumer   true
proxmox-csi-zfs-sata-general-retain          csi.proxmox.sinextra.dev   Delete          WaitForFirstConsumer   true
proxmox-csi-zfs-sata-object-retain           csi.proxmox.sinextra.dev   Delete          WaitForFirstConsumer   true
```

---

### 3. MinIO S3 Deployed & `cnpg-backups` Bucket ⚠️

**Status:** MinIO deployed; `cnpg-backups` bucket present (WAL archiving active)

**Verification:**

```bash
kubectl get pods -n minio-tenant
kubectl get svc -n minio-tenant
```

**Expected Output:**

```text
NAME                      READY   STATUS    RESTARTS   AGE
minio-pool-0-0            1/1     Running   0          3d
minio-pool-0-1            1/1     Running   0          3d
...
```

**Bucket Creation Steps:**

#### Option 1: MinIO Console UI

1. Navigate to <https://s3-console.m0sh1.cc>
2. Login with credentials from `minio-root-credentials` in `minio-tenant`:

   ```bash
   kubectl get secret minio-root-credentials -n minio-tenant -o jsonpath='{.data.config\.env}' | base64 -d
   ```

3. Create bucket: **`cnpg-backups`**
4. Set lifecycle policy: 30-day retention (optional, CNPG handles this)

#### Option 2: AWS CLI (if configured)

```bash
# Configure AWS CLI for MinIO endpoint
aws configure set aws_access_key_id <ACCESS_KEY>
aws configure set aws_secret_access_key <SECRET_KEY>

# Create bucket
aws --endpoint-url=https://minio.minio-tenant.svc.cluster.local:443 s3 mb s3://cnpg-backups

# Verify
aws --endpoint-url=https://minio.minio-tenant.svc.cluster.local:443 s3 ls
```

---

### 4. Valkey Deployed ⚠️

**Status:** Should be deployed, needs storage class fix

**Verification:**

```bash
kubectl get pods -n apps -l app.kubernetes.io/name=valkey
kubectl get svc -n apps valkey
```

**Expected Output:**

```text
NAME                     READY   STATUS    RESTARTS   AGE
valkey-0                 1/1     Running   0          2d
```

**Action Required:** Apply Valkey storage class fix before Harbor deployment

---

### 5. Harbor Secrets Verified ⚠️

**Status:** Must audit secrets-apps before Harbor deployment

**Required Secrets (9 total):**

| Secret Name | Purpose | Key(s) | Status |
|------------|---------|--------|--------|
| `harbor-postgres-auth` | PostgreSQL password | `password` | ❓ Unknown |
| `harbor-admin` | Harbor admin UI | `HARBOR_ADMIN_PASSWORD` | ❓ Unknown |
| `harbor-core-secret` | Core internal secret | (auto-generated key) | ❓ Unknown |
| `harbor-core-internal` | Core internal secrets | (multiple keys) | ❓ Unknown |
| `harbor-jobservice-internal` | Jobservice secrets | `JOBSERVICE_SECRET` | ❓ Unknown |
| `harbor-registry-credentials` | Registry auth | `REGISTRY_PASSWD` | ❓ Unknown |
| `harbor-valkey` | Valkey connection | (empty if no auth) | ❓ Unknown |
| `harbor-build-user` | Bootstrap job user | `username`, `password` | ❓ Unknown |
| `wildcard-m0sh1-cc` | TLS certificate | `tls.crt`, `tls.key` | ✅ Should exist |

**Audit Command:**

```bash
# Check secrets in apps namespace
kubectl get sealedsecrets -n apps | grep harbor
kubectl get secrets -n apps | grep harbor

# Check secrets-apps Kustomize directory
ls -la apps/user/secrets-apps/harbor-*.sealedsecret.yaml
```

**Secret Creation Workflow (if missing):**

#### Generate Harbor Admin Password

```bash
# 1. Generate strong password
HARBOR_ADMIN_PASSWORD=$(openssl rand -base64 32)

# 2. Create unsealed secret (temporary)
kubectl create secret generic harbor-admin \
  --from-literal=HARBOR_ADMIN_PASSWORD="$HARBOR_ADMIN_PASSWORD" \
  --namespace=apps \
  --dry-run=client -o yaml > /tmp/harbor-admin.yaml

# 3. Seal the secret
kubeseal --format yaml \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets-controller \
  < /tmp/harbor-admin.yaml \
  > apps/user/secrets-apps/harbor-admin.sealedsecret.yaml

# 4. Clean up plaintext
rm /tmp/harbor-admin.yaml
unset HARBOR_ADMIN_PASSWORD
```

#### Generate PostgreSQL Password

```bash
HARBOR_DB_PASSWORD=$(openssl rand -base64 32)

kubectl create secret generic harbor-postgres-auth \
  --from-literal=password="$HARBOR_DB_PASSWORD" \
  --namespace=apps \
  --dry-run=client -o yaml > /tmp/harbor-postgres-auth.yaml

kubeseal --format yaml \
  < /tmp/harbor-postgres-auth.yaml \
  > apps/user/secrets-apps/harbor-postgres-auth.sealedsecret.yaml

rm /tmp/harbor-postgres-auth.yaml
unset HARBOR_DB_PASSWORD
```

**Repeat for all 9 secrets** using pattern above.

---

### 6. CNPG Backup Credentials ⚠️

**Status:** Shared secret across all CNPG clusters

**Required Secret:** `cnpg-backup-credentials`

**Format:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cnpg-backup-credentials
  namespace: apps
type: Opaque
data:
  ACCESS_KEY_ID: <base64-encoded>
  ACCESS_SECRET_KEY: <base64-encoded>
```

**Creation Steps:**

1. **Generate MinIO Access Keys** (via console or existing root credentials)
2. **Create SealedSecret:**

   ```bash
   kubectl create secret generic cnpg-backup-credentials \
     --from-literal=ACCESS_KEY_ID="<minio-access-key>" \
     --from-literal=ACCESS_SECRET_KEY="<minio-secret-key>" \
     --namespace=apps \
     --dry-run=client -o yaml > /tmp/cnpg-backup-credentials.yaml

   kubeseal --format yaml \
     < /tmp/cnpg-backup-credentials.yaml \
     > apps/cluster/secrets-cluster/cnpg-backup-credentials.sealedsecret.yaml

   rm /tmp/cnpg-backup-credentials.yaml
   ```

3. **Deploy via secrets-cluster Kustomize app**

---

## Proxy Cache Enablement Checklist

1. Confirm Harbor bootstrap job ran and created proxy cache projects: `hub`, `ghcr`, `quay`, `k8s`.
2. Confirm proxy-cache robot accounts exist and secrets are present in `apps/user/secrets-apps/` (no plaintext).
3. Verify Harbor external URL and TLS at `https://harbor.m0sh1.cc`.
4. Set `k3s_enable_harbor_mirrors: true` in `ansible/inventory/group_vars/k3s_control_plane/k3s.yaml` and `ansible/inventory/group_vars/k3s_workers/k3s.yaml`.
5. Rendered `registries.yaml` must include mirror rewrites to `hub/`, `ghcr/`, `quay/`, `k8s/`.
6. Validate `dhi.io` endpoint save + pulls; if node pulls still fail, remove `dhi_io_auth` or disable its config in templates before enabling mirrors.
7. Apply Ansible to nodes and restart k3s to reload registry configuration.
8. Validate pulls with `crictl pull docker.io/library/alpine:3`, `crictl pull ghcr.io/...` and check Harbor proxy cache statistics.

## Implementation Sequence

### Phase 1: Infrastructure Prerequisites (30 minutes)

**Task 1.1:** Verify Proxmox CSI Storage Classes

```bash
kubectl get sc | grep proxmox-csi-zfs
# Ensure all 4 classes exist
```

**Task 1.2:** Deploy MinIO (if not already running)

```bash
kubectl get pods -n minio-tenant
# Should be Running
```

**Task 1.3:** Create `cnpg-backups` Bucket in MinIO

- Access <https://s3-console.m0sh1.cc>
- Login with root credentials
- Create bucket: `cnpg-backups`
- Test access with `aws s3 ls`

**Task 1.4:** Generate CNPG Backup Credentials SealedSecret

```bash
# Create and seal cnpg-backup-credentials secret
# Add to apps/cluster/secrets-cluster/
git add apps/cluster/secrets-cluster/cnpg-backup-credentials.sealedsecret.yaml
git commit -m "feat(cnpg): add backup credentials for MinIO S3"
```

**Task 1.5:** Wait for secret deployment

```bash
kubectl get secret cnpg-backup-credentials -n apps
```

---

### Phase 2: Valkey Storage Fix (15 minutes)

**Task 2.1:** Fix Valkey Storage Class

```bash
# Edit apps/cluster/valkey/values.yaml
# Change: proxmox-csi-zfs-pgdata-retain → proxmox-csi-zfs-nvme-fast-retain
```

**Task 2.2:** Bump Valkey Chart Version

```bash
# Edit apps/cluster/valkey/Chart.yaml
# version: 0.X.Y → 0.X.(Y+1)
```

**Task 2.3:** Commit and Deploy

```bash
git add apps/cluster/valkey/
git commit -m "fix(valkey): update storage class to nvme-fast-retain"
git push origin main
```

**Task 2.4:** Verify ArgoCD Sync

```bash
kubectl get application valkey -n argocd -w
# Wait for Synced status
```

**Task 2.5:** Verify Valkey Pod

```bash
kubectl get pods -n apps -l app.kubernetes.io/name=valkey
# Should be Running with correct PVC
kubectl get pvc -n apps | grep valkey
```

---

### Phase 3: Harbor Secrets Audit (45 minutes)

**Task 3.1:** Check Existing Secrets

```bash
kubectl get sealedsecrets -n apps | grep harbor
kubectl get secrets -n apps | grep harbor
```

**Task 3.2:** Identify Missing Secrets
Compare against required list (9 total)

**Task 3.3:** Generate Missing Secrets
Use SealedSecret workflow for each:

- `harbor-postgres-auth`
- `harbor-admin`
- `harbor-core-secret`
- `harbor-core-internal`
- `harbor-jobservice-internal`
- `harbor-registry-credentials`
- `harbor-valkey` (may be empty)
- `harbor-build-user`

**Task 3.4:** Commit Secrets

```bash
git add apps/user/secrets-apps/harbor-*.sealedsecret.yaml
git commit -m "feat(harbor): add missing SealedSecrets"
git push origin main
```

**Task 3.5:** Wait for Deployment

```bash
kubectl get sealedsecrets -n apps -w
# Wait for all Harbor secrets
```

**Task 3.6:** Plan Access Paths (Cloudflare Tunnel, Tailscale, LAN)

- Ensure DNS/ingress plan includes Cloudflare Tunnel hostname(s), Tailscale access, and LAN access for Harbor.

---

### Phase 4: Harbor Configuration Changes (30 minutes)

**Task 4.1:** Update Harbor values.yaml

- Fix PostgreSQL storage classes (lines 7-14)
- Fix migration section storage classes (lines 207-220)

**Task 4.2:** Update Harbor postgres-cluster.yaml Template

- Fix storage class defaults (lines 21-26)
- Add CNPG backup configuration (after line 59)

**Task 4.3:** Update Harbor pvc.yaml Template

- Fix registry storage class (line 11)
- Fix jobservice storage class (line 28)
- Fix trivy storage class (line ~45)

**Task 4.4:** Bump Harbor Chart Version

```bash
# Edit apps/user/harbor/Chart.yaml
# version: 0.4.17 → 0.4.18
```

**Task 4.5:** Commit Changes

```bash
git add apps/user/harbor/
git commit -m "feat(harbor): fix storage classes and add CNPG S3 backups

- Update PostgreSQL storage to nvme-fast/nvme-general
- Configure Barman Cloud backup to MinIO S3
- Fix PVC storage classes (registry, jobservice, trivy)
- Enable 30-day retention policy with zstd/snappy compression"

git push origin main
```

---

### Phase 5: Harbor Deployment (30 minutes)

**Task 5.1:** Monitor ArgoCD Sync

```bash
kubectl get application harbor -n argocd -w
```

**Task 5.2:** Verify CNPG Cluster Creation

```bash
kubectl get clusters.postgresql.cnpg.io harbor-postgres -n apps
kubectl describe cluster harbor-postgres -n apps
```

**Expected Phases:**

1. **Cluster Initializing**: Creating pods
2. **Cluster Healthy**: Primary running
3. **Backup Configured**: WAL archiving active

**Task 5.3:** Verify PVCs Bound

```bash
kubectl get pvc -n apps | grep harbor
```

**Expected Output:**

```text
harbor-postgres-1             Bound    pvc-xxx  40Gi  proxmox-csi-zfs-nvme-fast-retain
harbor-postgres-1-wal         Bound    pvc-xxx  10Gi  proxmox-csi-zfs-nvme-general-retain
harbor-jobservice             Bound    pvc-xxx  5Gi   proxmox-csi-zfs-nvme-fast-retain
harbor-trivy                  Bound    pvc-xxx  20Gi  proxmox-csi-zfs-nvme-fast-retain
```

**Note:** Harbor registry storage is configured to use MinIO (S3), so no registry PVC is expected.

**Task 5.4:** Verify Harbor Pods

```bash
kubectl get pods -n apps -l app=harbor
```

**Expected Pods:**

- `harbor-core-xxx` (1/1 Running)
- `harbor-portal-xxx` (1/1 Running)
- `harbor-registry-xxx` (2/2 Running - registry + controller)
- `harbor-jobservice-xxx` (1/1 Running)
- `harbor-trivy-xxx` (1/1 Running)
- `harbor-postgres-1` (1/1 Running)

**Task 5.5:** Check Harbor Core Logs

```bash
kubectl logs -n apps deploy/harbor-core --tail=50
# Look for database connection success
```

---

### Phase 6: Backup Verification (20 minutes)

**Task 6.1:** Verify CNPG Backup Configuration

```bash
kubectl get backup -n apps
kubectl get scheduledbackup -n apps
```

**Task 6.2:** Check WAL Archiving

```bash
kubectl logs -n apps harbor-postgres-1 | grep -i "archive"
```

**Expected Output:**

```text
LOG:  archive_mode enabled
LOG:  archive_command = 'barman-cloud-wal-archive ...'
LOG:  archived write-ahead log file "000000010000000000000001"
```

**Task 6.3:** Verify MinIO Backup Files

```bash
# Option 1: MinIO Console UI
# Navigate to s3://cnpg-backups/harbor/wals/
# Should see WAL segments appearing

# Option 2: AWS CLI
aws --endpoint-url=https://minio.minio-tenant.svc.cluster.local:443 s3 ls s3://cnpg-backups/harbor/wals/ --recursive
```

**Task 6.4:** Trigger Manual Backup (optional)

```bash
kubectl cnpg backup harbor-postgres --backup-name test-backup-$(date +%Y%m%d)
```

**Task 6.5:** Check Backup Status

```bash
kubectl get backup -n apps -w
kubectl describe backup test-backup-YYYYMMDD -n apps
```

---

### Phase 7: Harbor UI Verification (15 minutes)

**Task 7.1:** Access Harbor UI

```bash
# Get Harbor URL
echo "https://harbor.m0sh1.cc"

# Get admin password
kubectl get secret harbor-admin -n apps -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d
```

**Task 7.2:** Login to Harbor

- Username: `admin`
- Password: (from secret)

**Task 7.3:** Verify Harbor Components

- Navigate to **Administration → System Info**
- Check **Database** status: ✅ Healthy
- Check **Storage** status: ✅ Healthy
- Check **Redis** status: ✅ Healthy

**Task 7.4:** Run Bootstrap Job (if configured)

```bash
kubectl get jobs -n apps | grep harbor-bootstrap
kubectl logs -n apps -l job-name=harbor-bootstrap --tail=100
```

**Expected Actions:**

- Create proxy caches (hub, ghcr, quay, k8s, dhi)
- Create projects (apps, base)
- Create robot accounts
- Create build user with multi-project access

**Task 7.5:** Test Docker Login

```bash
docker login harbor.m0sh1.cc
# Username: admin or build user
# Password: (from secret)
```

**Status (2026-02-02):** Docker login succeeded (harbor-build).

---

## Validation Checklist

### Infrastructure Layer ✅

- [x] Proxmox CSI storage classes exist (4 classes)
- [x] MinIO tenant deployed and healthy
- [x] `cnpg-backups` bucket created in MinIO
- [x] `cnpg-backup-credentials` secret deployed
- [x] CNPG operator running and healthy
- [x] Valkey deployed with correct storage class

### Harbor Deployment ✅

- [x] All 9 Harbor secrets exist and sealed
- [x] Harbor chart version bumped to 0.4.18
- [x] Storage classes updated in values.yaml
- [x] Storage classes updated in templates
- [x] CNPG backup configuration added
- [x] ArgoCD Application synced successfully
- [x] CNPG cluster `harbor-postgres` created
- [x] All PVCs bound to correct storage classes
- [x] All Harbor pods running (core, portal, registry, jobservice, trivy, postgres)

### Backup & Recovery ✅

- [x] WAL archiving enabled and active (confirmed in `harbor-postgres` logs)
- [x] WAL segments visible in MinIO `s3://cnpg-backups/harbor/wals/`
- [x] Manual backup test successful
- [x] Backup retention policy configured (30 days)
- [ ] PITR capability verified (can specify targetTime)

### Harbor Functionality ✅

- [x] Harbor UI accessible at <https://harbor.m0sh1.cc>
- [x] Admin login successful
- [x] Database connection healthy
- [x] Redis/Valkey connection healthy
- [x] Storage backend healthy
- [x] Bootstrap job completed (if enabled)
- [x] Proxy caches created (including dhi)
- [x] Registry endpoints saved for Docker Hub + DHI (AES key size issue resolved)
- [x] Proxy cache pulls verified across nodes; artifacts visible in MinIO (hub/ghcr/quay/k8s/dhi)
- [ ] Projects created (apps, base)
- [x] Docker login successful
- [x] Image pull test passed (dhi proxy cache pull via Harbor)
- [~] Trivy scan disabled for proxy cache projects (OCI manifest scanning unsupported); find OCI CVE scanning solution

---

## Troubleshooting Guide

### Issue: PVCs Stuck in Pending

**Symptom:**

```bash
kubectl get pvc -n apps | grep harbor
harbor-postgres-1    Pending   ...
```

**Diagnosis:**

```bash
kubectl describe pvc harbor-postgres-1 -n apps
# Look for: "waiting for first consumer" or "no matching storage class"
```

**Resolution:**

1. **Check storage class exists:**

   ```bash
   kubectl get sc proxmox-csi-zfs-nvme-fast-retain
   ```

2. **Check CSI driver pods:**

   ```bash
   kubectl get pods -n kube-system | grep proxmox-csi
   ```

3. **Check Proxmox node connectivity:**

   ```bash
   kubectl logs -n kube-system <proxmox-csi-node-pod>
   ```

---

### Issue: CNPG Cluster Fails to Initialize

**Symptom:**

```bash
kubectl get cluster harbor-postgres -n apps
NAME               INSTANCES   READY   STATUS      AGE
harbor-postgres    1           0       Creating    5m
```

**Diagnosis:**

```bash
kubectl describe cluster harbor-postgres -n apps
kubectl logs -n apps harbor-postgres-1
```

**Common Causes:**

1. **Secret missing:** `harbor-postgres-auth` not deployed
2. **Storage issue:** PVC not binding
3. **Image pull failure:** Check `imageName` in values.yaml

**Resolution:**

```bash
# Verify secret exists
kubectl get secret harbor-postgres-auth -n apps

# Check CNPG operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Force cluster recreation (if needed)
kubectl delete cluster harbor-postgres -n apps
# ArgoCD will recreate automatically
```

---

### Issue: WAL Archiving Not Working

**Symptom:**

```bash
kubectl logs -n apps harbor-postgres-1 | grep archive
# No "archived write-ahead log" messages
```

**Diagnosis:**

```bash
# Check backup configuration
kubectl get cluster harbor-postgres -n apps -o yaml | grep -A 20 backup

# Check secret
kubectl get secret cnpg-backup-credentials -n apps

# Test MinIO connectivity from pod
kubectl exec -it harbor-postgres-1 -n apps -- sh
# Inside pod:
wget -qO- https://minio.minio-tenant.svc.cluster.local:443
```

**Resolution:**

1. **Verify MinIO endpoint:** Should be `https://minio.minio-tenant.svc.cluster.local:443` (no trailing slash)
2. **Check credentials:** Access key must have write permissions to `cnpg-backups` bucket
3. **Inspect CNPG logs:**

   ```bash
   kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg | grep backup
   ```

---

### Issue: Harbor Core Fails Database Connection

**Symptom:**

```bash
kubectl logs -n apps -l app=harbor-core
# Error: "failed to connect to database"
```

**Diagnosis:**

```bash
# Check CNPG cluster status
kubectl get cluster harbor-postgres -n apps

# Check database service
kubectl get svc -n apps | grep postgres

# Test connection from pod
kubectl exec -it <harbor-core-pod> -n apps -- sh
nc -zv harbor-postgres-rw.apps.svc.cluster.local 5432
```

**Resolution:**

1. **Verify service naming:** Should be `harbor-postgres-rw.apps.svc.cluster.local`
2. **Check database created:**

   ```bash
   kubectl get database harbor-db -n apps
   ```

3. **Verify role exists:**

   ```bash
   kubectl exec -it harbor-postgres-1 -n apps -- psql -U postgres -c "\du"
   # Should see: harbor | ...
   ```

---

### Issue: Backup Files Not Appearing in MinIO

**Symptom:** No files in `s3://cnpg-backups/harbor/wals/`

**Diagnosis:**

```bash
# Check CNPG cluster events
kubectl describe cluster harbor-postgres -n apps

# Check bucket exists
aws --endpoint-url=https://minio.minio-tenant.svc.cluster.local:443 s3 ls

# Check bucket permissions
aws --endpoint-url=https://minio.minio-tenant.svc.cluster.local:443 s3api get-bucket-acl --bucket cnpg-backups
```

**Resolution:**

1. **Verify bucket path:** Must be `s3://cnpg-backups/harbor/` (note trailing slash)
2. **Check compression settings:** Ensure `wal.compression: zstd` is valid
3. **Trigger manual WAL switch:**

   ```bash
   kubectl exec -it harbor-postgres-1 -n apps -- psql -U postgres -c "SELECT pg_switch_wal();"
   ```

---

## Risk Assessment

| Risk                      | Likelihood | Impact | Mitigation                                                               |
|---------------------------|------------|--------|--------------------------------------------------------------------------|
| **PVCs fail to bind**     | Medium     | High   | Pre-verify storage classes exist, monitor CSI driver pods                |
| **Missing secrets**           | Medium | High   | Complete secret audit before deployment, use checklist                   |
| **MinIO bucket missing**     | Low    | High   | Create bucket as first step, test access before CNPG deployment         |
| **Valkey not ready**          | Low    | Medium | Deploy Valkey before Harbor, verify health                               |
| **Storage exhaustion**        | Low    | High   | Monitor ZFS pool utilization (472Gi nvme, 50Gi sata allocated)          |
| **CNPG backup loop**          | Low    | Medium | Verify credentials and endpoint before enabling backup                   |
| **Harbor bootstrap failure**  | Medium | Low    | Bootstrap job idempotent, can retry manually                             |

---

## Rollback Plan

### If Harbor Deployment Fails

**Step 1:** Disable Harbor ArgoCD Application

```bash
# Move to disabled directory
git mv argocd/apps/user/harbor.yaml argocd/disabled/user/harbor.yaml
git commit -m "rollback: disable Harbor due to deployment issues"
git push origin main
```

**Step 2:** Clean Up Resources (if needed)

```bash
# ArgoCD will prune automatically, but if manual cleanup needed:
kubectl delete cluster harbor-postgres -n apps
kubectl delete pvc -n apps harbor-registry harbor-jobservice harbor-trivy
```

**Step 3:** Preserve Secrets

```bash
# Secrets are preserved (no prune), check:
kubectl get secrets -n apps | grep harbor
```

**Step 4:** Fix Issues Offline

- Correct storage classes in Git
- Verify all prerequisites
- Test in separate namespace if possible

**Step 5:** Re-enable Harbor

```bash
git mv argocd/disabled/user/harbor.yaml argocd/apps/user/harbor.yaml
git commit -m "feat: re-enable Harbor after fixes"
git push origin main
```

---

### If CNPG Backups Cause Issues

**Step 1:** Temporarily Disable Backup

```yaml
# In apps/user/harbor/templates/postgres-cluster.yaml
# Comment out backup section:
  # backup:
  #   barmanObjectStore: ...
```

**Step 2:** Commit and Sync

```bash
git commit -m "temp: disable Harbor CNPG backups for troubleshooting"
git push origin main
```

**Step 3:** Fix Backup Configuration Offline

- Verify MinIO credentials
- Test S3 connectivity manually
- Check bucket permissions

**Step 4:** Re-enable Backup

```yaml
# Uncomment backup section
  backup:
    barmanObjectStore: ...
```

---

## Memory Bank Updates Required

After successful Harbor deployment, update these Memory Bank files:

### decisionLog.md

```markdown
| 2026-02-01 | Harbor deployed with per-app CNPG cluster and MinIO S3 backups | Migrated from shared cnpg-main to dedicated harbor-postgres cluster (isolation + flexibility). Configured Barman Cloud plugin for continuous WAL archiving to MinIO S3 (s3://cnpg-backups/harbor/) with 30-day retention. Storage classes updated to match 4-VLAN Proxmox CSI naming: nvme-fast (pgdata 16K), nvme-general (pgwal 128K), sata-object (registry 1M). Valkey storage class also fixed. All 9 Harbor secrets deployed via SealedSecrets. PITR capability enabled for disaster recovery. |
```

### progress.md

```markdown
#### Phase 2: GitOps Core ✅

- [x] Harbor deployed with CNPG PostgreSQL (per-app cluster pattern)
- [x] MinIO S3 backup configured (cnpg-backups bucket)
- [x] Valkey storage class fixed
- [x] All storage classes aligned with Proxmox CSI
```

### systemPatterns.md

```markdown
#### CNPG Backup Pattern

- **MinIO S3 Integration**: All CNPG clusters back up to shared MinIO instance
- **Credentials**: Single `cnpg-backup-credentials` secret in secrets-cluster
- **Retention**: 30-day policy via `retentionPolicy: "30d"`
- **Compression**: WAL (zstd), base backups (snappy)
- **Bucket Structure**: `s3://cnpg-backups/{app-name}/`
```

---

## Success Criteria

**Harbor deployment is considered successful when:**

✅ All 5 Harbor pods running (core, portal, registry, jobservice, trivy)
✅ CNPG cluster `harbor-postgres` healthy (1/1 replicas ready)
✅ All PVCs bound to correct storage classes
✅ WAL archiving active (logs show successful archive)
✅ Backup files visible in MinIO `s3://cnpg-backups/harbor/wals/`
✅ Harbor UI accessible at <https://harbor.m0sh1.cc>
✅ Admin login successful
✅ All Harbor health checks passing (database, redis, storage)
✅ Docker login/push/pull test successful
✅ Bootstrap job completed (if enabled)

---

## Next Steps (Post-Deployment)

1. **Phase 3: Observability Reset**
   - Deploy Prometheus for metrics collection
   - Configure ServiceMonitors for Harbor + CNPG
   - Set up Grafana dashboards

2. **Phase 4: Expansion Features**
   - Enable Harbor HA (2 replicas with pod anti-affinity)
   - Enable Valkey replication
   - Configure CNPG standby for Harbor
   - Implement automated backup testing (PITR validation)

3. **Operational Tasks**
   - Document backup/restore procedures in docs/
   - Create runbooks for common Harbor operations
   - Set up alerting for backup failures

---

## Change 8: HarborGuard CNPG Integration + Storage Fix

**Purpose:** Enable HarborGuard scanner with per-app CNPG cluster for scan results persistence

### Overview

HarborGuard is a **vulnerability scanner aggregator** that runs 6 scanning tools (Trivy, Grype, Syft, Dockle, OSV-Scanner, Dive) against Harbor container images and provides a unified patching UI. It requires:

1. **PostgreSQL database** for scan results, patch tracking, and audit logs
2. **Harbor credentials** to access registries (reuses `harbor-build-user` secret)
3. **Docker-in-Docker sidecar** for isolated image scanning (privileged container)
4. **50Gi workspace storage** for scanner caches + temporary patch builds

**Current State:** HarborGuard is blocked by 3 critical issues:

1. Storage class `proxmox-csi-zfs-registry-retain` doesn't exist (line 135)
2. DATABASE_URL references deprecated `cnpg-main-rw.apps.svc.cluster.local`
3. Missing CNPG templates (postgres-cluster.yaml, postgres-database.yaml)

---

### Architecture Pattern: Docker-in-Docker Sidecar

HarborGuard uses a **DinD sidecar** pattern for secure image scanning:

```yaml
# Deployment structure
spec:
  template:
    spec:
      securityContext:
        fsGroup: 1000
      containers:
      # Main container: HarborGuard API + UI
      - name: harborguard
        image: harbor.m0sh1.cc/harbor/harborguard:v0.2.0
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: harborguard-db-secret  # Must reference per-app CNPG cluster
              key: DATABASE_URL
        - name: HARBOR_URL
          value: "https://harbor.m0sh1.cc"
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2
            memory: 2Gi

      # DinD sidecar: Docker daemon for isolated image scanning
      - name: dind
        image: docker:29.2.0-rc.1-dind-alpine3.23
        securityContext:
          privileged: true  # Required for Docker daemon
        volumeMounts:
        - name: docker-graph-storage
          mountPath: /var/lib/docker
        env:
        - name: DOCKER_TLS_CERTDIR  # Disable TLS (in-pod communication)
          value: ""

      volumes:
      - name: docker-graph-storage
        persistentVolumeClaim:
          claimName: harborguard-data  # 50Gi for scanner caches
```

**Why DinD Sidecar?**

1. **Isolation**: Scanner operations don't affect node Docker daemon
2. **Security**: Privileged container scoped to single pod (not node-wide)
3. **Resource Control**: Memory/CPU limits prevent runaway scans
4. **Autopatch Feature**: DinD allows building patched images in-pod

---

### Required Changes

#### 1. Create CNPG Cluster Template

**File:** `apps/user/harborguard/templates/postgres-cluster.yaml` (NEW)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: harborguard-postgres
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: harborguard-postgres
    app.kubernetes.io/part-of: harborguard
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  instances: {{ .Values.postgresql.instances | default 1 }}
  imageName: {{ .Values.postgresql.image.repository }}:{{ .Values.postgresql.image.tag }}

  # PostgreSQL configuration optimized for scan result queries
  postgresql:
    parameters:
      max_connections: "150"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      work_mem: "16MB"
      maintenance_work_mem: "128MB"
      # HarborGuard workload: mostly writes (scan results), occasional reads (UI queries)
      random_page_cost: "1.1"  # NVMe SSD
      effective_io_concurrency: "200"
      wal_buffers: "8MB"
      checkpoint_completion_target: "0.9"
      # Logging for audit compliance
      log_statement: "mod"  # Log INSERT, UPDATE, DELETE (scan results)
      log_min_duration_statement: "1000"  # Log slow queries (>1s)

  # Storage for PostgreSQL data (16K recordsize)
  storage:
    size: {{ .Values.postgresql.storage.size | default "5Gi" }}
    storageClass: {{ .Values.postgresql.storage.storageClass | default "proxmox-csi-zfs-nvme-fast-retain" }}

  # Separate storage for WAL logs (128K recordsize)
  walStorage:
    size: {{ .Values.postgresql.walStorage.size | default "2Gi" }}
    storageClass: {{ .Values.postgresql.walStorage.storageClass | default "proxmox-csi-zfs-nvme-general-retain" }}

  # Bootstrap configuration
  bootstrap:
    initdb:
      database: harborguard
      owner: harborguard
      secret:
        name: harborguard-db-secret

  # Monitoring
  monitoring:
    enabled: true
    podMonitorEnabled: false

  # S3 Backup Configuration (MinIO)
  {{- if .Values.postgresql.backup.enabled }}
  backup:
    barmanObjectStore:
      destinationPath: {{ .Values.postgresql.backup.destinationPath | default "s3://cnpg-backups/harborguard/" }}
      endpointURL: {{ .Values.postgresql.backup.endpointURL | default "https://minio.minio-tenant.svc.cluster.local:443" }}
      s3Credentials:
        accessKeyId:
          name: {{ .Values.postgresql.backup.credentials.secretName | default "cnpg-backup-credentials" }}
          key: {{ .Values.postgresql.backup.credentials.accessKeyIdKey | default "ACCESS_KEY_ID" }}
        secretAccessKey:
          name: {{ .Values.postgresql.backup.credentials.secretName | default "cnpg-backup-credentials" }}
          key: {{ .Values.postgresql.backup.credentials.secretAccessKeyKey | default "ACCESS_SECRET_KEY" }}
      wal:
        compression: zstd
        maxParallel: 8
      data:
        compression: snappy
        immediateCheckpoint: false
        jobs: 2
    retentionPolicy: {{ .Values.postgresql.backup.retentionPolicy | default "30d" }}
    target: prefer-standby
  {{- end }}

  # Resources
  resources:
    requests:
      cpu: {{ .Values.postgresql.resources.requests.cpu | default "300m" }}
      memory: {{ .Values.postgresql.resources.requests.memory | default "512Mi" }}
    limits:
      cpu: {{ .Values.postgresql.resources.limits.cpu | default "1" }}
      memory: {{ .Values.postgresql.resources.limits.memory | default "1Gi" }}
```

**Rationale:**

- **Smaller Storage**: HarborGuard needs less DB space than Harbor (scan results vs image metadata)
- **Optimized for Writes**: Scan results are write-heavy (INSERT operations)
- **Audit Logging**: `log_statement: "mod"` tracks all scan result writes
- **Resource Limits**: Prevents PostgreSQL from starving scanner processes

---

#### 2. Create CNPG Database Template

**File:** `apps/user/harborguard/templates/postgres-database.yaml` (NEW)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: harborguard
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: harborguard-database
    app.kubernetes.io/part-of: harborguard
  annotations:
    argocd.argoproj.io/sync-wave: "6"
spec:
  name: harborguard
  cluster:
    name: harborguard-postgres
  owner: harborguard
  ensure: present
```

---

#### 3. Update harborguard-db-secret (SealedSecret)

**File:** `apps/user/harborguard/templates/harborguard-db-secret.sealedsecret-unsealed.yaml`

**Current DATABASE_URL:**

```yaml
DATABASE_URL: postgresql://harborguard:<password>@cnpg-main-rw.apps.svc.cluster.local:5432/harborguard?sslmode=disable
```

**Required DATABASE_URL:**

```yaml
DATABASE_URL: postgresql://harborguard:<password>@harborguard-postgres-rw.apps.svc.cluster.local:5432/harborguard?sslmode=disable
```

**Action Required:**

1. Update unsealed secret with new endpoint
2. Regenerate SealedSecret:

```bash
kubectl create secret generic harborguard-db-secret \
  --from-literal=DATABASE_URL="postgresql://harborguard:<password>@harborguard-postgres-rw.apps.svc.cluster.local:5432/harborguard?sslmode=disable" \
  --namespace=apps \
  --dry-run=client -o yaml | \
kubeseal --format yaml > apps/user/harborguard/templates/harborguard-db-secret.sealedsecret.yaml

# Clean up plaintext
rm apps/user/harborguard/templates/harborguard-db-secret.sealedsecret-unsealed.yaml
```

---

#### 4. Fix Storage Class (PVC)

**File:** [apps/user/harborguard/values.yaml](../../apps/user/harborguard/values.yaml#L133-L139)

**Current:**

```yaml
persistence:
  enabled: true
  storageClassName: "proxmox-csi-zfs-registry-retain"  # ❌ NON-EXISTENT
  accessMode: ReadWriteOnce
  size: 50Gi
```

**Required:**

```yaml
persistence:
  enabled: true
  storageClassName: "proxmox-csi-zfs-sata-object-retain"  # ✅ CORRECT (1M recordsize)
  accessMode: ReadWriteOnce
  size: 50Gi
```

**Rationale:**

- **Sata-Object Storage**: Scanner caches + patch builds = large sequential writes (1M recordsize optimal)
- **50Gi Size**: Sufficient for multiple scanner tool caches (Trivy DB, Grype DB, etc.)
- **Cost Efficiency**: SATA SSD cheaper than NVMe for bulk storage

---

#### 5. Add PostgreSQL Configuration to values.yaml

**File:** [apps/user/harborguard/values.yaml](../../apps/user/harborguard/values.yaml) (append after line 148)

```yaml
# CloudNative-PG PostgreSQL configuration
postgresql:
  enabled: true
  instances: 1  # Single instance for Phase 2

  image:
    repository: ghcr.io/cloudnative-pg/postgresql
    tag: "17.2-system-trixie"

  # Storage for PGDATA (16K recordsize)
  storage:
    size: 5Gi
    storageClass: proxmox-csi-zfs-nvme-fast-retain

  # Separate storage for WAL logs (128K recordsize)
  walStorage:
    size: 2Gi
    storageClass: proxmox-csi-zfs-nvme-general-retain

  # Resources (smaller than Harbor - scan results DB)
  resources:
    requests:
      cpu: 300m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi

  # Backup configuration
  backup:
    enabled: true
    destinationPath: s3://cnpg-backups/harborguard/
    endpointURL: https://minio.minio-tenant.svc.cluster.local:443
    credentials:
      secretName: cnpg-backup-credentials
      accessKeyIdKey: ACCESS_KEY_ID
      secretAccessKeyKey: ACCESS_SECRET_KEY
    retentionPolicy: "30d"
```

---

#### 6. Bump Chart Version

**File:** [apps/user/harborguard/Chart.yaml](../../apps/user/harborguard/Chart.yaml#L4)

**Current:**

```yaml
version: 0.2.0
```

**Required:**

```yaml
version: 0.3.0  # Minor bump: CNPG integration + storage fix
```

**Rationale:**

- **Minor Version Bump**: New CNPG templates added (backward-compatible)
- **ArgoCD Detection**: Chart version change triggers sync

---

### Prerequisites

#### 1. CNPG Operator Deployed

Same as Harbor (already validated in Change 1).

#### 2. MinIO S3 Bucket Created

**Bucket Path:** `s3://cnpg-backups/harborguard/`

**Validation:**

```bash
s3cmd ls s3://cnpg-backups/
```

**Expected Output:**

```text
DIR   s3://cnpg-backups/harborguard/
DIR   s3://cnpg-backups/harbor/
DIR   s3://cnpg-backups/gitea/
```

**If Missing:**

```bash
s3cmd mb s3://cnpg-backups/harborguard
```

#### 3. CNPG Backup Credentials Secret

Same as Harbor (shared secret in `apps` namespace).

#### 4. HarborGuard Database Secret

**Secret:** `harborguard-db-secret`
**Namespace:** `apps`
**Key:** `DATABASE_URL`

**Current State:** Exists but references old `cnpg-main-rw` endpoint (needs regeneration).

**Validation:**

```bash
kubectl get secret harborguard-db-secret -n apps
kubectl get secret harborguard-db-secret -n apps -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

**Expected Output (after fix):**

```text
postgresql://harborguard:<password>@harborguard-postgres-rw.apps.svc.cluster.local:5432/harborguard?sslmode=disable
```

#### 5. Harbor Build User Credentials

**Secret:** `harbor-build-user`
**Namespace:** `apps`
**Keys:** `username`, `password`

**Validation:**

```bash
kubectl get secret harbor-build-user -n apps
```

**Expected Output:**

```text
NAME                TYPE     DATA   AGE
harbor-build-user   Opaque   2      30d
```

**Note:** HarborGuard reuses Harbor's robot account credentials (no new secret needed).

---

### Implementation Timeline

| Task | Duration | Cumulative |
| ---- | -------- | ---------- |
| Create CNPG templates | 20 min | 20 min |
| Update values.yaml (storage + postgresql config) | 15 min | 35 min |
| Regenerate harborguard-db-secret | 10 min | 45 min |
| Bump chart version | 2 min | 47 min |
| Commit + ArgoCD sync | 5 min | 52 min |
| Verify CNPG cluster + database | 10 min | 1h 2min |
| Test backup to MinIO | 15 min | 1h 17min |
| Deploy HarborGuard application | 10 min | 1h 27min |
| Validate scanner functionality | 20 min | **1h 47min** |

**Total:** ~2 hours (excluding Harbor deployment wait time)

---

### Validation Checklist

#### CNPG Cluster Health

- [ ] Cluster status: `kubectl get cluster harborguard-postgres -n apps` shows `Cluster in healthy state`
- [ ] Pods running: `kubectl get pods -n apps -l cnpg.io/cluster=harborguard-postgres` shows 1 pod `Running`
- [ ] Database exists: `kubectl cnpg psql harborguard-postgres -n apps -- -c '\l'` shows `harborguard` database
- [ ] PVCs bound: `kubectl get pvc -n apps -l cnpg.io/cluster=harborguard-postgres` shows 2 PVCs `Bound`

#### Backup Validation

- [ ] WAL archiving active: Check CNPG logs for `archived` messages
- [ ] Base backup exists: `s3cmd ls s3://cnpg-backups/harborguard/base/` shows backup directory
- [ ] WAL segments present: `s3cmd ls s3://cnpg-backups/harborguard/wals/` shows WAL files

#### HarborGuard Application

- [ ] Pod running: `kubectl get pods -n apps -l app.kubernetes.io/name=harborguard` shows 2 containers (harborguard + dind)
- [ ] Database connected: HarborGuard logs show successful PostgreSQL connection
- [ ] DinD healthy: `kubectl exec -it <harborguard-pod> -c dind -- docker info` succeeds
- [ ] UI accessible: <https://harborguard.m0sh1.cc> loads
- [ ] Scanner functional: Can trigger image scan via UI

#### Storage Validation

- [ ] PVC bound: `kubectl get pvc harborguard-data -n apps` shows `Bound`
- [ ] Storage class correct: PVC uses `proxmox-csi-zfs-sata-object-retain`
- [ ] Scanner cache persisted: Scanner DB downloads survive pod restart

---

### Rollback Procedures

Same as Harbor CNPG cluster rollback (see Change 1).

**HarborGuard-Specific:**

1. **If DinD sidecar fails:**

   ```bash
   # Check privileged security context
   kubectl describe pod <harborguard-pod> -n apps | grep -i privileged

   # Check volume mounts
   kubectl exec -it <harborguard-pod> -c dind -- ls -la /var/lib/docker
   ```

2. **If autopatch fails:**

   ```bash
   # Verify DinD can build images
   kubectl exec -it <harborguard-pod> -c dind -- docker build -t test:latest -
   ```

---

### Testing Scenarios

#### 1. Scan Image from Harbor

1. Access UI: <https://harborguard.m0sh1.cc>
2. Navigate to: Scan → New Scan
3. Select image: `harbor.m0sh1.cc/harbor/harborguard:v0.2.0`
4. Trigger scan with all 6 scanners
5. Verify results: Check for CVE findings, dependency analysis

#### 2. Autopatch Workflow (if enabled)

1. Identify vulnerable image with available patches
2. Click "Generate Patch"
3. Verify DinD builds patched image
4. Check new image pushed to Harbor
5. Verify scan shows reduced vulnerabilities

#### 3. Database Persistence

1. Trigger several scans to populate database
2. Delete HarborGuard pod: `kubectl delete pod <harborguard-pod> -n apps`
3. Wait for pod recreation
4. Verify scan history persists in UI

---

### Post-Deployment Monitoring

#### Key Metrics to Watch

1. **DinD Resource Usage:**
   - Monitor CPU/memory of DinD container during scans
   - Adjust limits if OOMKilled events occur

2. **Storage Growth:**
   - Track `harborguard-data` PVC usage
   - Scanner caches can grow large (Trivy DB ~500MB)

3. **Database Size:**
   - Query: `cnpg_pg_database_size_bytes{database="harborguard"}`
   - Alert if growth rate exceeds expected

4. **Scan Duration:**
   - Baseline: 6 scanners on 500MB image ~2-3 minutes
   - Alert if scans take >10 minutes (DinD resource constraint)

---

### Integration with Harbor

HarborGuard integrates with Harbor via:

1. **Webhook**: Harbor sends image push events to HarborGuard
2. **Robot Account**: HarborGuard pulls images using `harbor-build-user` credentials
3. **API**: HarborGuard queries Harbor API for repository metadata

**Dependency:** Harbor must be fully functional before enabling HarborGuard.

**Suggested Deployment Order:**

1. Deploy Harbor (Change 1-7 in this document)
2. Verify Harbor UI accessible + registry functional
3. Deploy HarborGuard (this change)
4. Configure Harbor webhook to HarborGuard endpoint

---

### Success Criteria

**HarborGuard is successfully deployed when:**

1. ✅ CNPG cluster `harborguard-postgres` running with 1 healthy instance
2. ✅ Database `harborguard` exists with `harborguard` user as owner
3. ✅ S3 backups working (base backup + WAL archiving to MinIO)
4. ✅ DATABASE_URL updated to `harborguard-postgres-rw` (not `cnpg-main-rw`)
5. ✅ Storage class updated to `sata-object-retain` (not `registry-retain`)
6. ✅ DinD sidecar running with privileged container
7. ✅ UI accessible at <https://harborguard.m0sh1.cc>
8. ✅ Can scan images from Harbor registry
9. ✅ Scan results persist across pod restarts
10. ✅ All 6 scanners (Trivy, Grype, Syft, Dockle, OSV, Dive) functional

---

## References

- [AGENTS.md](../../AGENTS.md): GitOps enforcement rules
- [docs/layout.md](../layout.md): Repository structure
- [Memory Bank Decision Log](../../memory-bank/decisionLog.md): Architecture decisions
- [CNPG Backup Documentation](https://cloudnative-pg.io/documentation/current/backup_barmanobjectstore/): Barman Cloud plugin
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm): Official Helm chart
- [Valkey Documentation](https://valkey.io/): Redis-compatible server

---

**Document Version:** 1.0
**Last Updated:** 2026-02-01
**Author:** m0sh1-devops agent
**Review Status:** Ready for Implementation
