# Network VLAN Architecture

**Status:** ✅ Operational
**Updated:** 2026-02-01
**Purpose:** Complete 4-VLAN network design for m0sh1.cc lab

## DNS Resolution Strategy

**k3s CoreDNS Configuration**:

- **NodeHosts**: Kubernetes nodes (lab-ctrl, horse01-04) resolved via k3s built-in
- **Proxmox hosts**: Static entries via CoreDNS wrapper chart (apps/cluster/coredns/)
  - pve01/02/03.m0sh1.cc → 10.0.0.11-13 (management) + 10.0.10.11-13 (infra VLAN)
  - Fixes Proxmox CSI DNS failures (controller requires reliable pve host resolution)
- **External domains**: Forward to OPNsense (10.0.10.1) then upstream

**Why static Proxmox entries needed**: OPNsense DNS unreliable under sustained load, causing Proxmox CSI API calls to fail with "no such host" errors. CoreDNS wrapper chart provides 100% reliable resolution for critical infrastructure.

Remote Access & Trust Model (Tailscale + Split DNS)

Status: ✅ Operational (2026-02-01)

This lab uses Tailscale as the access plane and DNS-based trust separation to provide secure remote access without relying on ISP router features or exposing internal services directly.

High-Level Model
    •    Tailscale provides authenticated network access and subnet routing.
    •    OPNsense remains the single routing and firewall authority for all VLANs.
    •    Cloudflare Access protects public entry points when outside the tailnet.
    •    Split DNS ensures the same hostname resolves differently depending on trust context.

This creates a clean separation between:
    •    Trusted access (on Tailscale)
    •    Untrusted/public access (via Cloudflare)

Subnet Routing
    •    Subnet router: pve-01
    •    Advertised routes:
    •    10.0.10.0/24 (Infrastructure)
    •    10.0.20.0/24 (Kubernetes)
    •    10.0.30.0/24 (Ingress / Services)

Routes are advertised via Tailscale and auto-approved using ACLs.

No static routes or firewall exceptions are required on the Speedport router.

DNS Behavior by Context

On Tailscale (Trusted)

argocd.m0sh1.cc
  → Tailscale DNS (100.100.100.100)
  → OPNsense Unbound (10.0.10.1)
  → A record: 10.0.30.10
  → Traefik Ingress (VLAN 30)

```text
•	Cloudflare is intentionally bypassed.    •    Cloudflare is intentionally bypassed.
    •    No AAAA record is served internally to avoid IPv6 preference issues.
    •    Access control is enforced by Tailscale ACLs, not Cloudflare.

Off Tailscale (Untrusted / Public)

argocd.m0sh1.cc
  → Public DNS
  → Cloudflare Anycast
  → Cloudflare Access (SSO / Zero Trust)

```

•    Same hostname.    •    Same hostname.
    •    Different resolution path.
    •    Cloudflare Access remains authoritative outside the tailnet.

Unbound DNS Overrides

Configured on OPNsense → Unbound DNS Overrides:

argocd.m0sh1.cc → 10.0.30.10

Additional internal services may be added individually.

Wildcard overrides are intentionally avoided to prevent accidental exposure of services that should remain behind Cloudflare Access.

Client Requirements

Clients accessing the lab via Tailscale must:
    •    Have Tailscale installed
    •    Enable Use Tailscale DNS settings
    •    Enable Accept subnet routes

If routes or DNS do not apply after configuration changes:

sudo tailscale up --reset --accept-routes=true

Security Notes
    •    Being on the Tailscale tailnet is treated as being inside the trusted perimeter.
    •    Cloudflare Access is bypassed only when DNS resolution is internal.
    •    Tailscale ACLs are the primary access control for internal services.
    •    OPNsense does not run Tailscale and does not need to.
    •    Kubernetes ingress is not used as an authentication boundary.

Rationale

This access model was chosen to:
    •    Avoid ISP router limitations
    •    Keep OPNsense firewall rules minimal and auditable
    •    Prevent Kubernetes ingress from becoming an access-control surface
    •    Enable seamless access from laptops and mobile devices (e.g. Nautik)
    •    Allow the same FQDN to work everywhere without user-side hacks

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
- `.20-.24`: K8s nodes primary interfaces (static)

| Name | Type | IP (eth0) | VMID | Node | Role |
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
- `.50-.59`: K8s nodes secondary interfaces (MetalLB L2)

| Name | Type | IP | Purpose |
|------|------|----|--------------------|
| opnsense-v30 | VLAN interface | 10.0.30.1 | Default gateway VLAN 30 |
| traefik-vip | MetalLB LB | 10.0.30.10 | Traefik ingress controller |
| (reserved) | MetalLB LB | 10.0.30.11-49 | Additional LoadBalancer services |
| labctrl-v30 | VM interface (eth1) | 10.0.30.50 | K8s node secondary NIC (MetalLB speaker) |
| horse01-v30 | VM interface (eth1) | 10.0.30.51 | K8s node secondary NIC (MetalLB speaker) |
| horse02-v30 | VM interface (eth1) | 10.0.30.52 | K8s node secondary NIC (MetalLB speaker) |
| horse03-v30 | VM interface (eth1) | 10.0.30.53 | K8s node secondary NIC (MetalLB speaker) |
| horse04-v30 | VM interface (eth1) | 10.0.30.54 | K8s node secondary NIC (MetalLB speaker) |

## MetalLB Configuration

**Status:** ✅ Operational (2026-01-29)

**Single-pool design** (VLAN 30 only):

- **Pool**: `services-vlan30`
- **Range**: `10.0.30.10-10.0.30.49`
- **Type**: L2Advertisement
- **Purpose**: All exposed services (Ingress + selected LoadBalancers)
- **Current Assignment**: 10.0.30.10 → traefik-lan LoadBalancer

**Dual-NIC K8s Nodes:**

- **Primary NIC (eth0)**: VLAN 20 (10.0.20.0/24) - Pod network, cluster communication
- **Secondary NIC (eth1)**: VLAN 30 (10.0.30.0/24) - MetalLB L2Advertisement interface
- **Why dual-NIC**: MetalLB L2 mode requires nodes to ARP on the same VLAN as LoadBalancer IPs
- **MetalLB behavior**: Speaker pods automatically detect eth1 and advertise VIPs on VLAN 30

**External Access Strategy:**

- **Internal (LAN)**: Direct access via traefik-lan (10.0.30.10) - MetalLB LoadBalancer
- **External (Internet)**: Cloudflared tunnel (future)
  - Tunnel in OPNsense + K8s Cloudflared deployment
  - No Tailscale operator (deferred for simplicity)
- **Traefik Services**:
  - `traefik`: LoadBalancer with `loadBalancerClass: tailscale` (pending - intentional, operator disabled)
  - `traefik-lan`: LoadBalancer with MetalLB → 10.0.30.10 (operational)

## DNS () Configuration

All DNS rewrites configured in: OPNsense -> Unbound DNS Overrides

### Infrastructure Access (VLAN 10 - Direct)

```yaml
opn.m0sh1.cc      → 10.0.10.1
switch.m0sh1.cc   → 10.0.0.2 (???)
pve01.m0sh1.cc      → 10.0.10.11
pve02.m0sh1.cc      → 10.0.10.12
pve03.m0sh1.cc      → 10.0.10.13
dns01.m0sh1.cc       → 10.0.10.21
dns02.m0sh1.cc       → 10.0.10.22
pbs.m0sh1.cc      → 10.0.10.14
smb.m0sh1.cc         → 10.0.10.23
apt.m0sh1.cc         → 10.0.10.24
bastion.m0sh1.cc     → 10.0.10.15
```

### Kubernetes Nodes (VLAN 20 - Direct)

```yaml
labctrl.m0sh1.cc    → 10.0.20.20
horse01.m0sh1.cc    → 10.0.20.21
horse02.m0sh1.cc    → 10.0.20.22
horse03.m0sh1.cc    → 10.0.20.23
horse04.m0sh1.cc    → 10.0.20.24
```

### Applications (VLAN 30 - via Traefik)

**All apps point to single Traefik VIP:**

```yaml
traefik.m0sh1.cc    → 10.0.30.10
argocd.m0sh1.cc     → 10.0.30.10
harbor.m0sh1.cc     → 10.0.30.10
git.m0sh1.cc        → 10.0.30.10
semaphore.m0sh1.cc  → 10.0.30.10
home.m0sh1.cc       → 10.0.30.10
headlamp.m0sh1.cc   → 10.0.30.10
pgadmin.m0sh1.cc    → 10.0.30.10
uptime.m0sh1.cc     → 10.0.30.10
guard.m0sh1.cc      → 10.0.30.10
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

- **Dual NIC configuration**:
  - **eth0 (net0)**: `vmbr0` with VLAN 20 tag → 10.0.20.20-24
    - Purpose: Pod network, cluster communication, default route
    - Gateway: 10.0.20.1 (OPNsense)
  - **eth1 (net1)**: `vmbr0` with VLAN 30 tag → 10.0.30.50-54
    - Purpose: MetalLB L2Advertisement (ARP for LoadBalancer VIPs)
    - No gateway configured (static route only)

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
dig @10.0.10.10 argocd.m0sh1.cc

# Test DNS from infrastructure VLAN
ssh root@pve01
dig @10.0.10.10 harbor.m0sh1.cc
```

### Inter-VLAN Routing Issues

```bash
# From K8s node, test connectivity to infrastructure
ssh root@labctrl
ping 10.0.10.10  # dns01
ping 10.0.10.1   # OPNsense gateway

# From infrastructure, test connectivity to services
ssh root@pve01
curl -k https://traefik.m0sh1.cc # Should resolve to 10.0.30.10
```

## Related Files

- Terraform: `terraform/envs/lab/{main.tf,lxcs.tf,vms.tf}`
- MetalLB: `apps/cluster/metallb/values.yaml`
- Traefik: `apps/cluster/traefik/values.yaml`
- DNS: `ansible/roles/adguard/defaults/main.yaml`
- Architecture diagram: `docs/terraform-vlan-rebuild.md`
