# Proxmox CSI Setup Guide

## Prerequisites

Before enabling Proxmox CSI in the cluster, you must:

1. Create ZFS datasets on **each Proxmox node**
2. Configure Proxmox storage IDs
3. **CRITICAL**: Ensure stable DNS resolution for Proxmox hosts in Kubernetes cluster

## DNS Resolution Requirements

**CRITICAL**: Proxmox CSI controller requires 100% reliable DNS resolution for Proxmox hosts.

**Problem**: k3s default CoreDNS forwards unknown domains to `/etc/resolv.conf` (OPNsense DNS), which becomes unreliable under sustained load, causing CSI API calls to fail with "dial tcp: lookup pve03.lab.m0sh1.cc on 10.0.0.10:53: no such host".

**Solution**: Add static Proxmox host entries directly to k3s CoreDNS configmap:

```bash
# Patch CoreDNS with static Proxmox hosts
kubectl patch configmap coredns -n kube-system --type=json -p='[{"op":"replace","path":"/data/Corefile","value":".:53 {\n    errors\n    health {\n        lameduck 10s\n    }\n    ready\n    hosts {\n        10.0.0.11 pve01.lab.m0sh1.cc pve01\n        10.0.0.12 pve02.lab.m0sh1.cc pve02\n        10.0.0.13 pve03.lab.m0sh1.cc pve03\n        10.0.10.11 pve01.lab.m0sh1.cc pve01\n        10.0.10.12 pve02.lab.m0sh1.cc pve02\n        10.0.10.13 pve03.lab.m0sh1.cc pve03\n        fallthrough\n    }\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n        pods insecure\n        fallthrough in-addr.arpa ip6.arpa\n        ttl 30\n    }\n    prometheus 0.0.0.0:9153\n    forward . /etc/resolv.conf\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}]'

# Restart CoreDNS to apply changes
kubectl rollout restart deployment/coredns -n kube-system
```

**Why NOT use a CoreDNS wrapper chart**: k3s manages CoreDNS with immutable Deployment selectors. Deploying a wrapper chart creates selector conflicts and breaks cluster DNS completely.

**Verification**:

```bash
# Test DNS resolution from CSI controller
kubectl exec -n csi-proxmox deployment/proxmox-csi-plugin-controller \
  -c proxmox-csi-plugin-controller -- getent hosts pve03.lab.m0sh1.cc

# Expected: 10.0.0.13 pve03.lab.m0sh1.cc OR 10.0.10.13 pve03.lab.m0sh1.cc
# Should NEVER fail with "no such host"
```

## Required ZFS Datasets

Based on [apps/cluster/proxmox-csi/values.yaml](../apps/cluster/proxmox-csi/values.yaml), the following storage IDs are configured:

```yaml
storageIds:
  pgdata: k8s-pgdata    # PostgreSQL data (16K recordsize)
  pgwal: k8s-pgwal      # PostgreSQL WAL (128K recordsize)
  registry: k8s-registry # Container registry data (128K recordsize)
  caches: k8s-caches    # Ephemeral caches (128K recordsize)
  minio-data: minio-data    # MinIO object storage (1M recordsize, sata-ssd pool)
```

## ZFS Dataset Creation

### On Each Proxmox Node (pve-01, pve-02, pve-03)

Run these commands as root on **each node**:

```bash
# PostgreSQL data - optimized for small random I/O
zfs create -o recordsize=16K rpool/k8s/pgdata

# PostgreSQL WAL - optimized for sequential writes
zfs create -o recordsize=128K rpool/k8s/pgwal

# Container registry - large sequential writes
zfs create -o recordsize=128K rpool/k8s/registry

# Ephemeral caches - default settings
zfs create -o recordsize=128K rpool/k8s/caches

# MinIO object storage - optimized for large object I/O (on sata-ssd pool)
zfs create \
  -o recordsize=1M \
  -o compression=zstd \
  -o atime=off \
  -o xattr=sa \
  -o acltype=posixacl \
  -o redundant_metadata=most \
  sata-ssd/minio

zfs create sata-ssd/minio/data
```

**Note on MinIO Storage:**

- Uses dedicated `sata-ssd` pool (128GB SSD per node)
- 1M recordsize optimized for large object storage workloads
- Zstd compression provides good performance/ratio balance
- atime=off reduces metadata write overhead
- xattr=sa stores extended attributes efficiently
- acltype=posixacl enables POSIX ACL support
- redundant_metadata=most enhances data integrity

### Verify Datasets

```bash
# List all k8s datasets (nvme rpool)
zfs list -r rpool/k8s

# List MinIO dataset (sata-ssd pool)
zfs list -r sata-ssd/minio

# Check recordsize settings
zfs get recordsize rpool/k8s/pgdata
zfs get recordsize rpool/k8s/pgwal
zfs get recordsize rpool/k8s/registry
zfs get recordsize rpool/k8s/caches
zfs get recordsize sata-ssd/minio
zfs get recordsize sata-ssd/minio/data

# Verify MinIO ZFS tuning
zfs get compression,atime,xattr,redundant_metadata -r sata-ssd/minio
```

Expected output:

```text
# rpool datasets (nvme)
NAME                   USED  AVAIL     REFER  MOUNTPOINT
rpool/k8s              XXX   XXX       XXX    /rpool/k8s
rpool/k8s/caches       XXX   XXX       XXX    /rpool/k8s/caches
rpool/k8s/pgdata       XXX   XXX       XXX    /rpool/k8s/pgdata
rpool/k8s/pgwal        XXX   XXX       XXX    /rpool/k8s/pgwal
rpool/k8s/registry     XXX   XXX       XXX    /rpool/k8s/registry

# sata-ssd dataset
NAME                   USED  AVAIL     REFER  MOUNTPOINT
sata-ssd/minio         XXX   XXX       XXX    /sata-ssd/minio
sata-ssd/minio/data     XXX   XXX       XXX    /sata-ssd/minio/data
```

## Proxmox Storage Configuration

The Proxmox CSI plugin expects these datasets to be configured as ZFS storage in Proxmox.

### Add Storage via Proxmox Web UI

For each node:

1. Navigate to **Datacenter → Storage → Add → ZFS**
2. Configure storage:

```yaml
ID: k8s-pgdata
ZFS Pool: rpool/k8s/pgdata
Content: Disk image, Container
Nodes: pve-01,pve-02,pve-03
Thin provision: Yes
```

Repeat for:

- `k8s-pgwal`
- `k8s-registry`
- `k8s-caches`
- `minio-data` (using `sata-ssd/minio/data` pool)

### Or via CLI (on each node)

```bash
# Add k8s-pgdata storage (nvme rpool)
pvesm add zfspool k8s-pgdata \
  --pool rpool/k8s/pgdata \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-pgwal storage
pvesm add zfspool k8s-pgwal \
  --pool rpool/k8s/pgwal \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-registry storage
pvesm add zfspool k8s-registry \
  --pool rpool/k8s/registry \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-caches storage
pvesm add zfspool k8s-caches \
  --pool rpool/k8s/caches \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add minio-data storage (sata-ssd pool)
pvesm add zfspool minio-data \
  --pool sata-ssd/minio/data \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03
```

### Verify Proxmox Storage

```bash
pvesm status | grep k8s
```

Expected output:

```text
k8s-caches     zfspool          1      XXX GiB    XXX GiB
minio-data      zfspool          1      XXX GiB    XXX GiB
k8s-pgdata     zfspool          1      XXX GiB    XXX GiB
k8s-pgwal      zfspool          1      XXX GiB    XXX GiB
k8s-registry   zfspool          1      XXX GiB    XXX GiB
```

## Proxmox CSI Secret Configuration

The CSI plugin connects to Proxmox API via [apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret.yaml](../apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret.yaml).

### Unsealed Secret Format

The sealed secret contains a `config.yaml` with Proxmox cluster configuration:

```yaml
clusters:
  - url: https://pve01.lab.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: lab
  - url: https://pve02.lab.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: lab
  - url: https://pve03.lab.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: lab
```

**Critical Configuration**:

- **Use DNS names** (pve01.lab.m0sh1.cc) instead of IPs - requires CoreDNS wrapper chart with static entries
- **All nodes same region**: `region: lab` identifies the Proxmox cluster
- **Token user**: `smeya@pve!csi` (full Administrator permissions required)
- **Zones**: CSI driver uses k8s node labels to map volumes to Proxmox nodes

**Why DNS names**: If DNS resolution fails ("no such host"), CSI controller cannot make API calls. Static CoreDNS entries ensure 100% reliable resolution.

### Creating Proxmox API Token

On each Proxmox node:

```bash
# Create API token for CSI user with full Administrator permissions
pveum user token add smeya@pve csi --privsep 0

# Grant Administrator role at root level
pveum acl modify / --users smeya@pve --roles Administrator

# Verify permissions
pveum user token permissions smeya@pve csi
# Expected: Full access to /, /access, /nodes, /storage, /vms, /pool, /sdn
```

**Important:** Save the token secret securely, then regenerate the SealedSecret using kubeseal (see "Regenerating CSI Secret" section below).

## StorageClasses Created

The wrapper chart creates these StorageClasses:

| StorageClass | Storage ID | Reclaim Policy | Use Case |
|--------------|-----------|----------------|----------|
| `proxmox-csi-zfs-pgdata-retain` | k8s-pgdata | Retain | PostgreSQL data (default) |
| `proxmox-csi-zfs-pgwal-retain` | k8s-pgwal | Retain | PostgreSQL WAL |
| `proxmox-csi-zfs-registry-retain` | k8s-registry | Retain | Container registry |
| `proxmox-csi-zfs-caches-retain` | k8s-caches | Retain | Long-lived caches |
| `proxmox-csi-zfs-caches-delete` | k8s-caches | Delete | Ephemeral caches |
| `proxmox-csi-zfs-minio-retain` | minio-data | Retain | MinIO object storage (SSD) |

## Enabling Proxmox CSI

Once ZFS datasets are created and Proxmox storage is configured:

1. **Move ArgoCD Application from disabled to active**:

   ```bash
   git mv argocd/disabled/cluster/proxmox-csi.yaml argocd/apps/cluster/proxmox-csi.yaml
   git commit -m "feat: Enable Proxmox CSI"
   ```

2. **ArgoCD will automatically sync** and deploy:
   - CSI controller (2 replicas)
   - CSI node DaemonSet (on all workers)
   - StorageClasses
   - VolumeAttributesClass (for backups)

3. **Verify deployment**:

   ```bash
   # Check CSI pods
   kubectl get pods -n csi-proxmox

   # Verify StorageClasses
   kubectl get storageclass | grep proxmox

   # Test provisioning (optional)
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: test-pvc
     namespace: default
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
     storageClassName: proxmox-csi-zfs-pgdata-retain
   EOF

   kubectl get pvc test-pvc
   kubectl delete pvc test-pvc
   ```

## Troubleshooting

### DNS Resolution Failures (CRITICAL)

**Symptom**: PVCs stuck Pending with error: "dial tcp: lookup pve03.lab.m0sh1.cc on 10.43.0.10:53: no such host"

**Root Cause**: k3s CoreDNS forward to external DNS (OPNsense) unreliable under sustained load.

**Fix**:

1. Add static Proxmox host entries to k3s CoreDNS:

   ```bash
   # Patch CoreDNS configmap with Proxmox static hosts
   kubectl patch configmap coredns -n kube-system --type=json -p='[{"op":"replace","path":"/data/Corefile","value":".:53 {\n    errors\n    health {\n        lameduck 10s\n    }\n    ready\n    hosts {\n        10.0.0.11 pve01.lab.m0sh1.cc pve01\n        10.0.0.12 pve02.lab.m0sh1.cc pve02\n        10.0.0.13 pve03.lab.m0sh1.cc pve03\n        10.0.10.11 pve01.lab.m0sh1.cc pve01\n        10.0.10.12 pve02.lab.m0sh1.cc pve02\n        10.0.10.13 pve03.lab.m0sh1.cc pve03\n        fallthrough\n    }\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n        pods insecure\n        fallthrough in-addr.arpa ip6.arpa\n        ttl 30\n    }\n    prometheus 0.0.0.0:9153\n    forward . /etc/resolv.conf\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}]'

   # Restart CoreDNS
   kubectl rollout restart deployment/coredns -n kube-system
   kubectl rollout status deployment/coredns -n kube-system --timeout=60s
   ```

2. Test DNS resolution from CSI controller:

   ```bash
   kubectl exec -n csi-proxmox deployment/proxmox-csi-plugin-controller \
     -c proxmox-csi-plugin-controller -- getent hosts pve03.lab.m0sh1.cc
   ```

3. Restart CSI controller if DNS now stable:

   ```bash
   kubectl rollout restart deployment/proxmox-csi-plugin-controller -n csi-proxmox
   ```

### CSI Controller Pods Fail

**Symptom**: CSI controller pods in CrashLoopBackOff

**Check**:

```bash
kubectl logs -n csi-proxmox deploy/proxmox-csi-plugin-controller -c csi-provisioner
kubectl logs -n csi-proxmox deploy/proxmox-csi-plugin-controller -c proxmox-csi-plugin-controller
```

**Common causes**:

- DNS resolution failures (see above)
- Invalid API token (check token permissions: `pveum user token permissions smeya@pve csi`)
- Storage IDs not configured in Proxmox (verify: `pvesm status | grep k8s-`)
- Proxmox API unreachable (test: `curl -k https://pve01.lab.m0sh1.cc:8006/api2/json/version`)

### PVC Stuck in Pending

**Symptom**: PVC remains Pending after creation

**Check**:

```bash
kubectl describe pvc <pvc-name>
kubectl get events -n <namespace> --field-selector involvedObject.name=<pvc-name>
kubectl logs -n csi-proxmox deploy/proxmox-csi-plugin-controller -c csi-provisioner --tail=50
```

**Common causes**:

1. **DNS failures** - most common, check csi-provisioner logs for "no such host"
2. Storage ID doesn't exist on target node - verify `pvesm status` on all nodes
3. Insufficient space in ZFS pool - check `zfs list -o space rpool/k8s/<storage-id>`
4. CSI node driver not running on worker node - check `kubectl get pods -n csi-proxmox -l app=proxmox-csi-plugin`
5. Wrong region in config - all nodes must have `region: lab`, check sealed secret

### Verify Volume Creation on Proxmox

After PVC binds, check Proxmox for created ZFS volume:

```bash
# SSH to relevant Proxmox node
ssh pve01

# List ZFS volumes for storage pool
zfs list -t volume -r rpool/k8s/pgdata

# Should show: vm-9999-pvc-<uuid> with size matching PVC request
```

If PVC shows Bound but no volume exists, CSI controller successfully created volume metadata but ZFS creation failed - check Proxmox logs: `journalctl -u pve-cluster -f`

### Storage Not Available on Node

**Symptom**: Pod can't start because volume can't be attached

**Check**:

```bash
# On Proxmox node
pvesm status | grep k8s

# Verify dataset exists
zfs list rpool/k8s/<storage-id>
```

**Resolution**:

- Ensure ZFS datasets exist on all nodes hosting workers
- Verify Proxmox storage configuration includes all nodes

## Related Files

- [apps/cluster/proxmox-csi/values.yaml](../apps/cluster/proxmox-csi/values.yaml) - CSI configuration
- [apps/cluster/proxmox-csi/templates/storageclasses.yaml](../apps/cluster/proxmox-csi/templates/storageclasses.yaml) - StorageClass definitions
- [argocd/apps/cluster/proxmox-csi.yaml](../argocd/apps/cluster/proxmox-csi.yaml) - ArgoCD Application
- [docs/network-vlan-architecture.md](network-vlan-architecture.md) - VLAN 10 infrastructure network

## Regenerating CSI Secret

If you need to regenerate the Proxmox CSI SealedSecret (e.g., after token rotation or region config fix):

```fish
# 1. Create unsealed config (Fish shell)
cat > /tmp/proxmox-csi-config.yaml <<'EOF'
clusters:
  - url: https://10.0.10.11:8006/api2/json
    insecure: false
    token_id: "root@pam!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: lab
  - url: https://10.0.10.12:8006/api2/json
    insecure: false
    token_id: "root@pam!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: lab
  - url: https://10.0.10.13:8006/api2/json
    insecure: false
    token_id: "root@pam!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: lab
EOF

# 2. Create Kubernetes Secret manifest
kubectl create secret generic proxmox-csi-plugin \
  --from-file=config.yaml=/tmp/proxmox-csi-config.yaml \
  --namespace=csi-proxmox \
  --dry-run=client -o yaml > /tmp/proxmox-csi-secret.yaml

# 3. Seal the secret
kubeseal --format yaml \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets-controller \
  < /tmp/proxmox-csi-secret.yaml \
  > apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret.yaml

# 4. Clean up temp files
rm /tmp/proxmox-csi-config.yaml /tmp/proxmox-csi-secret.yaml

# 5. Commit and push
git add apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret.yaml
git commit -m "fix(proxmox-csi): Regenerate secret with correct region config"
git push

# 6. Restart CSI controller to reload config
kubectl rollout restart deployment/proxmox-csi-plugin-controller -n csi-proxmox
kubectl rollout status deployment/proxmox-csi-plugin-controller -n csi-proxmox --timeout=60s
```

## Troubleshooting (continued)

### Region Not Found Error

**Symptom**: PVCs stuck in Pending, CSI provisioner logs show `rpc error: code = Internal desc = region not found`

**Root Cause**: Mismatch between node topology labels and CSI secret region configuration.

**Check node labels:**

```fish
kubectl get nodes --show-labels | rg 'topology.kubernetes.io/(region|zone)'
```

Expected output shows `topology.kubernetes.io/region=lab` and `topology.kubernetes.io/zone=pveXX`.

**Check CSI secret config:**

```fish
kubectl get secret -n csi-proxmox proxmox-csi-plugin -o jsonpath='{.data.config\.yaml}' | base64 -d
```

**Resolution**: Ensure all Proxmox nodes in the secret use `region: lab` (matching node labels), not individual node names like `pve-01`. See "Regenerating CSI Secret" section above.

**Why this happens**: The CSI driver uses `region` to identify the Proxmox **cluster** (all nodes share same region) and `zone` to select which specific **Proxmox node** provisions each volume. Nodes get zone labels from kubelet registration, but region must match what's configured in the CSI secret.

## When to Enable

Enable Proxmox CSI **after** k3s bootstrap but **before** deploying applications that require persistent storage:

1. ✅ k3s cluster operational
2. ✅ ArgoCD bootstrapped
3. ✅ ZFS datasets created on all nodes
4. ✅ Proxmox storage configured
5. ✅ Node topology labels correct (region=lab, zone=pveXX)
6. → **Enable Proxmox CSI** (regenerate secret if needed)
7. → Deploy CNPG (requires pgdata/pgwal StorageClasses)
8. → Deploy Harbor, Gitea, etc. (require registry StorageClass)
