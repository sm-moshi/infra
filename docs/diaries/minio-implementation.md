# MinIO OSS Operator + Tenant Implementation (RustFS migration)

Status: In progress (operator + tenant deployed; ingress TLS fix pending)
Date: 2026-02-02

## Decision

- Use separate ArgoCD apps for operator and tenant to keep lifecycle and rollbacks independent.
- Replace RustFS with MinIO OSS Operator + Tenant.
- Add NVMe object tier for S3 scale without shrinking the SATA general tier.

## References

- <https://github.com/minio/operator/wiki/Deploy-MinIO-Operator-with-Helm>
- <https://raw.githubusercontent.com/minio/operator/refs/heads/master/helm/operator/README.md>
- <https://raw.githubusercontent.com/minio/operator/refs/heads/master/helm/tenant/README.md>

## Scope

- New ZFS dataset and Proxmox storage ID: rpool/k8s-nvme-object -> k8s-nvme-object
- New StorageClass: proxmox-csi-zfs-nvme-object-retain
- MinIO OSS operator (minio/operator) and tenant (minio/tenant)
- Replace RustFS S3 endpoint for CNPG backups

## Prerequisites

- Proxmox CSI operational and StorageClasses available.
- CoreDNS static Proxmox host entries already pinned (no wrapper chart).
- SealedSecrets controller healthy; secrets centralized.
- RustFS data can be discarded (no migration required).

## Storage changes (Proxmox + ZFS)

Create the new dataset on each Proxmox node (pve-01, pve-02, pve-03):

```bash
# Create NVMe object dataset (idempotent)
if ! zfs list -H rpool/k8s-nvme-object >/dev/null 2>&1; then
  zfs create \
    -o recordsize=1M \
    -o compression=zstd \
    -o atime=off \
    -o xattr=sa \
    -o acltype=posixacl \
    -o redundant_metadata=most \
    rpool/k8s-nvme-object
fi

# Ensure properties
zfs set recordsize=1M compression=zstd atime=off xattr=sa acltype=posixacl \
  redundant_metadata=most rpool/k8s-nvme-object
```

Adjust SATA quotas (object -> 75G, general -> 25G) on each node:

```bash
zfs set quota=75G sata-ssd/k8s-sata-object
zfs set quota=25G sata-ssd/k8s-sata-general
```

Note: if the SATA object dataset has a 75G zvol in use, the quota reduction will fail until that zvol is removed.
Add the Proxmox storage ID once (cluster-wide) from any node:

```bash
pvesm add zfspool k8s-nvme-object \
  --pool rpool/k8s-nvme-object \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03
```

Verify:

```bash
pvesm status | rg -w k8s-nvme-object
zfs get recordsize,compression,atime,xattr,acltype,redundant_metadata \
  rpool/k8s-nvme-object
zfs get quota sata-ssd/k8s-sata-object sata-ssd/k8s-sata-general
```

## Proxmox CSI chart updates (GitOps)

- apps/cluster/proxmox-csi/values.yaml:
  - Add storageIds.nvme_object: k8s-nvme-object
  - Add cacheByClass.nvme_object: none
- apps/cluster/proxmox-csi/templates/storageclasses.yaml:
  - Add StorageClass proxmox-csi-zfs-nvme-object-retain
- Bump apps/cluster/proxmox-csi/Chart.yaml version

## ArgoCD apps (separate)

Create two ArgoCD Applications:

- minio-operator (namespace: minio-operator, sync wave before tenant)
- minio-tenant (namespace: minio-tenant, depends on operator CRDs)
  - Set minio-operator sync wave: 21
  - Set minio-tenant sync wave: 22
  - Bump CNPG sync wave to 23 to ensure MinIO is ready first

Helm repo + chart names (reference only, GitOps will render):

- Repo: <https://operator.min.io/>
- Charts: minio/operator and minio/tenant

## Operator wrapper chart

- Path: apps/cluster/minio-operator/
- Namespace: minio-operator
- Values: keep defaults unless RBAC or securityContext hardening required.

## Tenant wrapper chart

- Path: apps/cluster/minio-tenant/
- Namespace: minio-tenant
- StorageClass: proxmox-csi-zfs-nvme-object-retain
- Size: set to match desired quota (example 200Gi)
- Erasure set: align with node count (3 nodes -> prefer 4 drives minimum if possible)
- Use existingSecret for root credentials (SealedSecrets in secrets-cluster)

Ingress:

- S3 endpoint: s3.m0sh1.cc (LAN), optional tunnel for external
- Console endpoint: s3-console.m0sh1.cc
- TLS: wildcard-s3-m0sh1-cc or wildcard-m0sh1-cc

## Secrets

- Create SealedSecret for MinIO root credentials in secrets-cluster.
- Create SealedSecret for CNPG backup credentials (access key + secret) if rotating.
  - The MinIO secret must include a `config.env` key, for example:

```text
config.env: |-
  export MINIO_ROOT_USER=CHANGEME
  export MINIO_ROOT_PASSWORD=CHANGEME
```

## Cutover from RustFS (no data migration)

1) Disable RustFS ArgoCD app (move to argocd/disabled/cluster).
2) Let ArgoCD prune RustFS resources and PVCs.
   - If resources remain, delete the rustfs namespace manually:
     `kubectl delete namespace rustfs`
3) Verify zvols are gone on each node:

```bash
zfs list -r sata-ssd/k8s-sata-object -o name,used,volsize
```

1) If SATA object quota reduction failed earlier, retry after PVCs are gone:

```bash
zfs set quota=75G sata-ssd/k8s-sata-object
```

## CNPG update (Barman Cloud plugin)

- Update ObjectStore endpoint to MinIO service (minio-tenant or ingress FQDN).
- Ensure TLS/CA settings match the endpoint (in-cluster service or TLS ingress).
- Confirm ScheduledBackup still points to the updated ObjectStore.

## Current issues (2026-02-02) — Resolved

- Backend TLS verification failures fixed by applying Traefik service annotations on the MinIO Services (not the Ingress):
  - `traefik.ingress.kubernetes.io/service.serversscheme: https`
  - `traefik.ingress.kubernetes.io/service.serverstransport: minio-tenant-minio-transport@kubernetescrd`
- `s3-console.m0sh1.cc` returns `200` and `s3.m0sh1.cc` returns `400` for unauthenticated HEAD (expected).
- Remaining: create `cnpg-backups` bucket and verify CNPG backups land in MinIO.

## Validation

- Operator pod Running (minio-operator namespace)
- Tenant pods Running (minio-tenant namespace)
- PVCs bound to proxmox-csi-zfs-nvme-object-retain
- MinIO console reachable (s3-console.m0sh1.cc)
- S3 API reachable (s3.m0sh1.cc)
- `mc` access works; bucket creation and object list succeed
- CNPG manual backup succeeds and writes to MinIO bucket

## Rollback

- Re-enable RustFS app if MinIO fails.
- Restore ObjectStore endpoint to RustFS.
- Verify CNPG backups land in RustFS again.

## mc quickstart (S3 verification)

```bash
# Alias (replace access/secret)
mc alias set minio https://s3.m0sh1.cc ACCESS_KEY SECRET_KEY

# List buckets
mc ls minio

# Create bucket for CNPG backups
mc mb minio/cnpg-backups

# List objects
mc ls --recursive minio/cnpg-backups
```

## Current state (2026-02-02)

- Created rpool/k8s-nvme-object on pve-01/02/03 and added storage ID k8s-nvme-object.
- Set sata-ssd/k8s-sata-general quota to 25G on all nodes.
- Set sata-ssd/k8s-sata-object quota to 75G on pve-01 and pve-03.
- pve-02 quota now reduced to 75G after deleting the leftover 75G zvol.
- Proxmox CSI synced; new StorageClass proxmox-csi-zfs-nvme-object-retain available.
- RustFS app disabled/synced; PVCs removed; zvols cleaned up on pve-02.
- RustFS namespace deleted; in-cluster resources removed.
- Created minio-operator and minio-tenant wrapper charts and ArgoCD apps (sync waves 21/22).
- Sealed minio-root-credentials with config.env (MINIO_ROOT_USER/MINIO_ROOT_PASSWORD).
- MinIO operator and tenant apps synced; tenant PVCs bound (6x50Gi on proxmox-csi-zfs-nvme-object-retain).
- Ingresses for s3.m0sh1.cc and s3-console.m0sh1.cc created; TLS fixed via Service annotations and ServersTransport (console 200, S3 400 unauthenticated).
