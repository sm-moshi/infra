# Network VLAN Architecture

**Status:** ✅ Operational
**Updated:** 2026-01-29
**Purpose:** Complete 4-VLAN network design for m0sh1.cc lab

## DNS Resolution Strategy

**k3s CoreDNS Configuration**:

- **NodeHosts**: Kubernetes nodes (lab-ctrl, horse01-04) resolved via k3s built-in
- **Proxmox hosts**: Static entries via CoreDNS wrapper chart (apps/cluster/coredns/)
  - pve01/02/03.lab.m0sh1.cc → 10.0.0.11-13 (management) + 10.0.10.11-13 (infra VLAN)
  - Fixes Proxmox CSI DNS failures (controller requires reliable pve host resolution)
- **External domains**: Forward to OPNsense (10.0.10.1) then upstream

**Why static Proxmox entries needed**: OPNsense DNS unreliable under sustained load, causing Proxmox CSI API calls to fail with "no such host" errors. CoreDNS wrapper chart provides 100% reliable resolution for critical infrastructure.

## Network Overview

```text
┌─────────────────────────────────────────────────────────────┐
│ Home / Speedport WiFi (10.0.0.0/24)                         │
│ - WiFi clients, phones, watches, flatmate devices           │
│ - Consumer router (limited inter-VLAN routing)              │
└──────────────────┬──────────────────────────────────────────┘
                   │ (OPNsense WAN via USB NIC)
                   ▼
         ┌─────────────────┐
         │   OPNsense VM   │
         │   (pve-01)      │
         │   VMID 300      │
         └────────┬────────┘
                  │ (VLAN trunk via vmbr0)
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌───────┐    ┌────────┐    ┌────────┐
│VLAN 10│    │VLAN 20 │    │VLAN 30 │
│Infra  │    │K8s     │    │Ingress │
└───────┘    └────────┘    └────────┘
```

## Subnet Design

| Segment | VLAN | Subnet | Gateway (OPNsense) | DHCP Scope | Purpose |
|---------|------|--------|-------------------|------------|---------|
| **Home / Speedport** | none | 10.0.0.0/24 | 10.0.0.1 (Speedport) | 10.0.0.100-199 | WiFi clients, consumer devices |
| **Infrastructure** | 10 | 10.0.10.0/24 | 10.0.10.1 | 10.0.10.50-99 | Proxmox, DNS, PBS, SMB, Bastion |
| **Kubernetes Nodes** | 20 | 10.0.20.0/24 | 10.0.20.1 | 10.0.20.100-149 | K8s control plane + workers |
| **Services/Ingress** | 30 | 10.0.30.0/24 | 10.0.30.1 | 10.0.30.150-199 | Traefik VIP, LoadBalancers |

## Static IP Allocations

### Home / Speedport (10.0.0.0/24)

| Name | Type | IP | Purpose |
|------|------|----|--------------------|
| speedport | Router | 10.0.0.1 | WAN + WiFi gateway |
| opnsense-wan | VM NIC | DHCP (e.g. 10.0.0.10) | OPNsense WAN interface |
| macbook/phones/etc | Devices | DHCP 10.0.0.50+ | Consumer devices |

**Note:** Speedport WiFi clients require OPNsense routing configuration to reach lab VLANs.

### VLAN 10 — Infrastructure (10.0.10.0/24)

**Reserved ranges:**

- `.1`: Gateway (OPNsense)
- `.10-.49`: Core infrastructure (static)
- `.100-.199`: DHCP (optional management devices)

| Name | Type | IP | VMID | Node | Purpose |
|------|------|-------|------|------|---------|
| opnsense-lan | VM interface | 10.0.10.1 | 300 | pve-01 | Default gateway VLAN 10 |
| pve-01 | Proxmox host | 10.0.0.11 + 10.0.10.11 | - | - | Cluster node (mgmt + infra IPs) |
| pve-02 | Proxmox host | 10.0.0.12 + 10.0.10.12 | - | - | Cluster node (mgmt + infra IPs) |
| pve-03 | Proxmox host | 10.0.0.13 + 10.0.10.13 | - | - | Cluster node (mgmt + infra IPs) |
| dns01 | LXC | 10.0.10.21 | 100 | pve-02 | Primary AdGuard Home (DNS) |
| dns02 | LXC | 10.0.10.22 | 101 | pve-03 | Secondary AdGuard Home (DNS) |
| pbs | VM | 10.0.10.14 | 120 | pve-01 | Proxmox Backup Server |
| smb | LXC | 10.0.10.23 | 110 | pve-01 | Samba file server |
| bastion | VM | 10.0.10.15 | 250 | pve-02 | Jump host + IaC tooling |

**Note**: Proxmox hosts have dual IPs - 10.0.0.x (management/corosync) + 10.0.10.x (infra services). Both are registered in CoreDNS for Proxmox CSI compatibility.

### VLAN 20 — Kubernetes Nodes (10.0.20.0/24)

**Reserved ranges:**

- `.1`: Gateway (OPNsense)
- `.200-.250`: K8s nodes (static)

| Name | Type | IP | VMID | Node | Role |
|------|------|-------|------|------|------|
| opnsense-v20 | VLAN interface | 10.0.20.1 | - | - | Default gateway VLAN 20 |
| labctrl | VM | 10.0.20.20 | 201 | pve-01 | Control plane |
| horse01 | VM | 10.0.20.21 | 210 | pve-01 | Worker |
| horse02 | VM | 10.0.20.22 | 211 | pve-02 | Worker |
| horse03 | VM | 10.0.20.23 | 212 | pve-03 | Worker |
| horse04 | VM | 10.0.20.24 | 213 | pve-02 | Worker |

### VLAN 30 — Services/Ingress (10.0.30.0/24)

**Reserved ranges:**

- `.1`: Gateway (OPNsense)
- `.10-.49`: MetalLB pool (LoadBalancers)

| Name | Type | IP | Purpose |
|------|------|----|--------------------|
| opnsense-v30 | VLAN interface | 10.0.30.1 | Default gateway VLAN 30 |
| traefik-vip | MetalLB LB | 10.0.30.10 | Traefik ingress controller |
| (reserved) | MetalLB LB | 10.0.30.11-49 | Additional LoadBalancer services |

## MetalLB Configuration

**Status:** ✅ Operational (2026-01-28)

**Single-pool design** (VLAN 30 only):

- **Pool**: `services-vlan30`
- **Range**: `10.0.30.10-10.0.30.49`
- **Type**: L2Advertisement
- **Purpose**: All exposed services (Ingress + selected LoadBalancers)
- **Current Assignment**: 10.0.30.10 → traefik-lan LoadBalancer

**Why single-pool:**

- Simpler failure modes (single ARP/L2 domain)
- OPNsense handles inter-VLAN routing
- K8s nodes on VLAN 20 advertise VLAN 30 IPs via L2
- Easier to troubleshoot and maintain

**External Access Strategy:**

- **Internal (LAN)**: Direct access via traefik-lan (10.0.30.10) - MetalLB LoadBalancer
- **External (Internet)**: Cloudflared tunnel (future)
  - Tunnel in OPNsense + K8s Cloudflared deployment
  - No Tailscale operator (deferred for simplicity)
- **Traefik Services**:
  - `traefik`: LoadBalancer with `loadBalancerClass: tailscale` (pending - intentional, operator disabled)
  - `traefik-lan`: LoadBalancer with MetalLB → 10.0.30.10 (operational)

## DNS (AdGuard Home) Configuration

All DNS rewrites configured in: `ansible/roles/adguard/defaults/main.yaml`

### Infrastructure Access (VLAN 10 - Direct)

```yaml
opn.lab.m0sh1.cc      → 10.0.10.1
switch.lab.m0sh1.cc   → 10.0.0.2 (???)
pve01.lab.m0sh1.cc      → 10.0.10.11
pve02.lab.m0sh1.cc      → 10.0.10.12
pve03.lab.m0sh1.cc      → 10.0.10.13
dns01.lab.m0sh1.cc       → 10.0.10.21
dns02.lab.m0sh1.cc       → 10.0.10.22
pbs.lab.m0sh1.cc      → 10.0.10.14
smb.lab.m0sh1.cc         → 10.0.10.23
apt.lab.m0sh1.cc         → 10.0.10.24
bastion.lab.m0sh1.cc     → 10.0.10.15
```

### Kubernetes Nodes (VLAN 20 - Direct)

```yaml
labctrl.lab.m0sh1.cc    → 10.0.20.20
horse01.lab.m0sh1.cc    → 10.0.20.21
horse02.lab.m0sh1.cc    → 10.0.20.22
horse03.lab.m0sh1.cc    → 10.0.20.23
horse04.lab.m0sh1.cc    → 10.0.20.24
```

### Applications (VLAN 30 - via Traefik)

**All apps point to single Traefik VIP:**

```yaml
traefik.lab.m0sh1.cc    → 10.0.30.10
argocd.lab.m0sh1.cc     → 10.0.30.10
harbor.lab.m0sh1.cc     → 10.0.30.10
git.lab.m0sh1.cc        → 10.0.30.10
semaphore.lab.m0sh1.cc  → 10.0.30.10
home.lab.m0sh1.cc       → 10.0.30.10
headlamp.lab.m0sh1.cc   → 10.0.30.10
pgadmin.lab.m0sh1.cc    → 10.0.30.10
uptime.lab.m0sh1.cc     → 10.0.30.10
guard.lab.m0sh1.cc      → 10.0.30.10
```

## Traffic Flow

### Client → Application

```text
[Client on any VLAN]
    ↓
[OPNsense routing]
    ↓
[10.0.30.10 - Traefik VIP (VLAN 30)]
    ↓
[MetalLB L2 advertisement]
    ↓
[K8s node on VLAN 20 receives traffic]
    ↓
[kube-proxy → Traefik pod]
    ↓
[Traefik routes to backend pods]
```

### Inter-VLAN Routing Rules (OPNsense)

**Required firewall rules:**

1. **VLAN 10 → VLAN 30**: Infrastructure can access services
2. **VLAN 20 → VLAN 10**: K8s can access infrastructure (DNS, storage)
3. **VLAN 20 → VLAN 30**: K8s can advertise MetalLB IPs
4. **VLAN 30 → VLAN 20**: Service traffic flows to K8s nodes
5. **Home (10.0.0.0/24) → Lab VLANs**: Optional, via static routes on Speedport

## Physical Connectivity

### Proxmox Hosts (pve-01/02/03)

- **Single NIC** → Switch → `vmbr0` (VLAN trunk)
- **VLAN tagging**: Done at VM/LXC level
- **Bridge config**: `vmbr0` carries VLANs 10, 20, 30

### OPNsense VM (VMID 300)

- **WAN NIC (net0)**: `vmbrWAN` → USB NIC → Speedport LAN (10.0.0.x DHCP)
- **LAN NIC (net1)**: `vmbr0` VLAN trunk
  - VLAN 10 interface: 10.0.10.1/24
  - VLAN 20 interface: 10.0.20.1/24
  - VLAN 30 interface: 10.0.30.1/24

### K8s Node VMs

- **Single NIC** → `vmbr0` with VLAN 20 tag
- **Gateway**: 10.0.20.1 (OPNsense)

### Infrastructure LXCs/VMs

- **Single NIC** → `vmbr0` with VLAN 10 tag
- **Gateway**: 10.0.10.1 (OPNsense)

## Deployment Checklist

### Phase 1: Terraform Infrastructure

- [x] Apply Terraform: `cd terraform/envs/lab && terraform apply`
- [x] Verify LXCs/VMs created with correct IPs
- [x] Verify OPNsense VM created (VMID 300)

### Phase 2: OPNsense Configuration

- [x] Boot OPNsense from ISO, complete installation
- [x] Manually add WAN interface (net0) via Proxmox
- [x] Configure LAN interface (10.0.10.1/24)
- [x] Create VLAN interfaces (VLAN 20, VLAN 30)
- [ ] Configure firewall rules (inter-VLAN routing)
- [ ] Test connectivity between VLANs

### Phase 3: Infrastructure Services

- [ ] Deploy AdGuard Home: `ansible-playbook playbooks/adguard.yaml`
- [ ] Configure DNS rewrites via AdGuard UI
- [ ] Deploy PBS, SMB, Bastion as needed
- [ ] Test DNS resolution from all VLANs

### Phase 4: Kubernetes Cluster

- [ ] Deploy K3s control plane: `ansible-playbook playbooks/k3s-control-plane.yaml`
- [ ] Deploy K3s workers: `ansible-playbook playbooks/k3s-workers.yaml`
- [ ] Verify: `kubectl get nodes -o wide`

### Phase 5: GitOps Bootstrap

- [ ] Bootstrap ArgoCD: `kubectl apply -k cluster/bootstrap/argocd/`
- [ ] Wait for ArgoCD ready
- [ ] Deploy root app: `kubectl apply -f argocd/apps/root.yaml`
- [ ] Verify MetalLB assigns 10.0.30.10 to Traefik
- [ ] Test application access via Traefik

## Troubleshooting

### MetalLB Not Assigning IPs

```bash
# Check MetalLB speaker pods
kubectl get pods -n metallb-system

# Check IP pools
kubectl get ipaddresspool -n metallb-system

# Check L2 advertisements
kubectl get l2advertisement -n metallb-system

# Check service events
kubectl describe svc -n traefik traefik-lan
```

### DNS Resolution Issues

```bash
# Test DNS from K8s node
ssh root@labctrl
dig @10.0.10.10 argocd.lab.m0sh1.cc

# Test DNS from infrastructure VLAN
ssh root@pve01
dig @10.0.10.10 harbor.lab.m0sh1.cc
```

### Inter-VLAN Routing Issues

```bash
# From K8s node, test connectivity to infrastructure
ssh root@labctrl
ping 10.0.10.10  # dns01
ping 10.0.10.1   # OPNsense gateway

# From infrastructure, test connectivity to services
ssh root@pve01
curl -k https://traefik.lab.m0sh1.cc # Should resolve to 10.0.30.10
```

## Related Files

- Terraform: `terraform/envs/lab/{main.tf,lxcs.tf,vms.tf}`
- MetalLB: `apps/cluster/metallb/values.yaml`
- Traefik: `apps/cluster/traefik/values.yaml`
- DNS: `ansible/roles/adguard/defaults/main.yaml`
- Architecture diagram: `docs/terraform-vlan-rebuild.md`
