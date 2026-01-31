# Proxmox CSI Setup Guide

## Prerequisites

Before enabling Proxmox CSI in the cluster, you must:

1. Create ZFS datasets on **each Proxmox node**
2. Configure Proxmox storage IDs
3. **CRITICAL**: Ensure stable DNS resolution for Proxmox hosts in Kubernetes cluster

## DNS Resolution Requirements

**CRITICAL**: Proxmox CSI controller requires 100% reliable DNS resolution for Proxmox hosts.

**Problem**: k3s CoreDNS forwards unknown domains to OPNsense, which can cause CSI API calls to fail with "dial tcp: lookup pve03.m0sh1.cc ... no such host" when Proxmox hostnames are not pinned in CoreDNS.

**Solution**: Manage static Proxmox host entries in Git at `cluster/environments/lab/coredns-configmap.yaml` and sync `lab-env`.

```text
hosts {
    10.0.10.11 pve01.m0sh1.cc pve01
    10.0.10.12 pve02.m0sh1.cc pve02
    10.0.10.13 pve03.m0sh1.cc pve03
    10.0.10.11 pve01-vlan10.m0sh1.cc
    10.0.10.12 pve02-vlan10.m0sh1.cc
    10.0.10.13 pve03-vlan10.m0sh1.cc
    fallthrough
}
```

Apply via GitOps:

```bash
argocd app sync lab-env
# Optional if CoreDNS doesn't reload immediately:
kubectl rollout restart deployment/coredns -n kube-system
```

**Why NOT use a CoreDNS wrapper chart**: k3s manages CoreDNS with immutable Deployment selectors. Deploying a wrapper chart creates selector conflicts and breaks cluster DNS completely.

**Verification**:

```bash
# Test DNS resolution from CSI controller
kubectl exec -n csi-proxmox deployment/proxmox-csi-plugin-controller \
  -c proxmox-csi-plugin-controller -- getent hosts pve03.m0sh1.cc

# Expected: 10.0.10.13 pve03.m0sh1.cc
# Should NEVER fail with "no such host"
```

## Required ZFS Datasets

Based on `apps/cluster/proxmox-csi/values.yaml`, the following storage IDs are configured:

```yaml
storageIds:
  nvme_fast: k8s-nvme-fast        # Fast tier (16K recordsize)
  nvme_general: k8s-nvme-general  # General NVMe (128K recordsize)
  sata_general: k8s-sata-general  # General SATA (128K recordsize)
  sata_object: k8s-sata-object    # Object storage (1M recordsize)
```

## ZFS Dataset Creation

### On Each Proxmox Node (pve-01, pve-02, pve-03)

Run these commands as root on **each node**:

```bash
# Fast tier (latency-sensitive)
zfs create -o recordsize=16K rpool/k8s-nvme-fast

# General NVMe tier
zfs create -o recordsize=128K rpool/k8s-nvme-general

# General SATA tier
zfs create -o recordsize=128K sata-ssd/k8s-sata-general

# Object storage tier (large objects)
zfs create \
  -o recordsize=1M \
  -o compression=zstd \
  -o atime=off \
  -o xattr=sa \
  -o acltype=posixacl \
  -o redundant_metadata=most \
  sata-ssd/k8s-sata-object
```

**Note on SATA object storage:**

- Uses dedicated `sata-ssd` pool (128GB SSD per node)
- 1M recordsize optimized for large object storage workloads
- Zstd compression provides good performance/ratio balance
- atime=off reduces metadata write overhead
- xattr=sa stores extended attributes efficiently
- acltype=posixacl enables POSIX ACL support
- redundant_metadata=most enhances data integrity

### Verify Datasets

```bash
# List NVMe datasets
zfs list -r rpool | rg 'k8s-nvme-(fast|general)'

# List SATA datasets
zfs list -r sata-ssd | rg 'k8s-sata-(general|object)'

# Check recordsize settings
zfs get recordsize rpool/k8s-nvme-fast
zfs get recordsize rpool/k8s-nvme-general
zfs get recordsize sata-ssd/k8s-sata-general
zfs get recordsize sata-ssd/k8s-sata-object

# Verify SATA object tuning
zfs get compression,atime,xattr,redundant_metadata -r sata-ssd/k8s-sata-object
```

Expected output:

```text
# rpool datasets (nvme)
NAME                       USED  AVAIL     REFER  MOUNTPOINT
rpool/k8s-nvme-fast         XXX   XXX       XXX    /rpool/k8s-nvme-fast
rpool/k8s-nvme-general      XXX   XXX       XXX    /rpool/k8s-nvme-general

# sata-ssd datasets
NAME                       USED  AVAIL     REFER  MOUNTPOINT
sata-ssd/k8s-sata-general  XXX   XXX       XXX    /sata-ssd/k8s-sata-general
sata-ssd/k8s-sata-object   XXX   XXX       XXX    /sata-ssd/k8s-sata-object
```

## Proxmox Storage Configuration

The Proxmox CSI plugin expects these datasets to be configured as ZFS storage in Proxmox.

### Add Storage via Proxmox Web UI

For each node:

1. Navigate to **Datacenter → Storage → Add → ZFS**
2. Configure storage:

```yaml
ID: k8s-nvme-fast
ZFS Pool: rpool/k8s-nvme-fast
Content: Disk image, Container
Nodes: pve-01,pve-02,pve-03
Thin provision: Yes
```

Repeat for:

- `k8s-nvme-general` (pool: `rpool/k8s-nvme-general`)
- `k8s-sata-general` (pool: `sata-ssd/k8s-sata-general`)
- `k8s-sata-object` (pool: `sata-ssd/k8s-sata-object`)

### Or via CLI (on each node)

```bash
# Add k8s-nvme-fast storage (nvme rpool)
pvesm add zfspool k8s-nvme-fast \
  --pool rpool/k8s-nvme-fast \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-nvme-general storage
pvesm add zfspool k8s-nvme-general \
  --pool rpool/k8s-nvme-general \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-sata-general storage
pvesm add zfspool k8s-sata-general \
  --pool sata-ssd/k8s-sata-general \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03

# Add k8s-sata-object storage
pvesm add zfspool k8s-sata-object \
  --pool sata-ssd/k8s-sata-object \
  --content images,rootdir \
  --nodes pve-01,pve-02,pve-03
```

### Verify Proxmox Storage

```bash
pvesm status | grep k8s
```

Expected output:

```text
k8s-nvme-fast     zfspool          1      XXX GiB    XXX GiB
k8s-nvme-general  zfspool          1      XXX GiB    XXX GiB
k8s-sata-general  zfspool          1      XXX GiB    XXX GiB
k8s-sata-object   zfspool          1      XXX GiB    XXX GiB
```

## Proxmox CSI Secret Configuration

The CSI plugin connects to Proxmox API via `apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret.yaml`.

### Unsealed Secret Format

The sealed secret contains a `config.yaml` with Proxmox cluster configuration:

```yaml
clusters:
  - url: https://pve01.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: m0sh1-cc-lab
  - url: https://pve02.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: m0sh1-cc-lab
  - url: https://pve03.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET"
    region: m0sh1-cc-lab
```

**Critical Configuration**:

- **Use DNS names** (pve01.m0sh1.cc) instead of IPs - requires CoreDNS static hosts in `cluster/environments/lab/coredns-configmap.yaml`
- **All nodes same region**: `region: m0sh1-cc-lab` identifies the Proxmox cluster
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
| `proxmox-csi-zfs-nvme-fast-retain` | k8s-nvme-fast | Retain | Fast tier (DB WAL / latency-sensitive) |
| `proxmox-csi-zfs-nvme-general-retain` | k8s-nvme-general | Retain | General NVMe-backed PVCs |
| `proxmox-csi-zfs-sata-general-retain` | k8s-sata-general | Retain | Lower-priority SATA PVCs |
| `proxmox-csi-zfs-sata-object-retain` | k8s-sata-object | Retain | Object storage backing |

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
     storageClassName: proxmox-csi-zfs-nvme-fast-retain
   EOF

   kubectl get pvc test-pvc
   kubectl delete pvc test-pvc
   ```

## Troubleshooting

### DNS Resolution Failures (CRITICAL)

**Symptom**: PVCs stuck Pending with error: "dial tcp: lookup pve03.m0sh1.cc on 10.43.0.10:53: no such host"

**Root Cause**: CoreDNS missing static Proxmox host entries (or wrong VLAN IPs).

**Fix**:

1. Update CoreDNS hosts in Git (`cluster/environments/lab/coredns-configmap.yaml`) to map:
   - `pve01.m0sh1.cc` → `10.0.10.11`
   - `pve02.m0sh1.cc` → `10.0.10.12`
   - `pve03.m0sh1.cc` → `10.0.10.13`

2. Sync and reload CoreDNS:

   ```bash
   argocd app sync lab-env
   kubectl rollout restart deployment/coredns -n kube-system
   kubectl rollout status deployment/coredns -n kube-system --timeout=60s
   ```

3. Test DNS resolution from CSI controller:

   ```bash
   kubectl exec -n csi-proxmox deployment/proxmox-csi-plugin-controller \
     -c proxmox-csi-plugin-controller -- getent hosts pve03.m0sh1.cc
   ```

4. Restart CSI controller if DNS now stable:

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

- `apps/cluster/proxmox-csi/values.yaml` - CSI configuration
- `apps/cluster/proxmox-csi/templates/storageclasses.yaml` - StorageClass definitions
- `argocd/apps/cluster/proxmox-csi.yaml` - ArgoCD Application
- [docs/guides/network-vlan-architecture.md](./network-vlan-architecture.md) - VLAN 10 infrastructure network

## Regenerating CSI Secret

If you need to regenerate the Proxmox CSI SealedSecret (e.g., after token rotation or region config fix):

```fish
# 1. Create unsealed config (Fish shell)
cat > /tmp/proxmox-csi-config.yaml <<'EOF'
clusters:
  - url: https://pve01.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: m0sh1-cc-lab
  - url: https://pve02.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: m0sh1-cc-lab
  - url: https://pve03.m0sh1.cc:8006/api2/json
    insecure: false
    token_id: "smeya@pve!csi"
    token_secret: "YOUR_API_TOKEN_SECRET_HERE"
    region: m0sh1-cc-lab
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

Expected output shows `topology.kubernetes.io/region=m0sh1-cc-lab` and `topology.kubernetes.io/zone=pve-01` (and pve-02/pve-03).

**Check CSI secret config:**

```fish
kubectl get secret -n csi-proxmox proxmox-csi-plugin -o jsonpath='{.data.config\.yaml}' | base64 -d
```

**Resolution**: Ensure all Proxmox nodes in the secret use `region: m0sh1-cc-lab` (matching node labels), not individual node names like `pve-01`. See "Regenerating CSI Secret" section above.

**Why this happens**: The CSI driver uses `region` to identify the Proxmox **cluster** (all nodes share same region) and `zone` to select which specific **Proxmox node** provisions each volume. Nodes get zone labels from kubelet registration, but region must match what's configured in the CSI secret.

## When to Enable

Enable Proxmox CSI **after** k3s bootstrap but **before** deploying applications that require persistent storage:

1. ✅ k3s cluster operational
2. ✅ ArgoCD bootstrapped
3. ✅ ZFS datasets created on all nodes
4. ✅ Proxmox storage configured
5. ✅ Node topology labels correct (region=m0sh1-cc-lab, zone=pve-01/02/03)
6. → **Enable Proxmox CSI** (regenerate secret if needed)
7. → Deploy CNPG (requires pgdata/pgwal StorageClasses)
8. → Deploy Harbor, Gitea, etc. (require registry StorageClass)
