# Network VLAN Architecture

**Status:** ✅ Operational
**Updated:** 2026-03-01
**Purpose:** Complete 4-VLAN network design for m0sh1.cc lab

> **See also:** [docs/network-architecture.md](../network-architecture.md) for the comprehensive network architecture covering Cilium CNI, DNS-over-TLS, observability pipeline, and stock k3s comparison.

## Network Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│ Home / Speedport WiFi (10.0.0.0/24)                             │
│ - WiFi clients, phones, watches, flatmate devices               │
│ - Speedport Smart 4 Plus (10.0.0.1) — ISP router, WiFi AP      │
│ - Switch (10.0.0.2) — L2, carries VLAN trunk to Proxmox hosts  │
└──────────────┬──────────────────────────────────────────────────┘
               │ (shared L2 via switch + vmbr0 native VLAN)
               ▼
     ┌─────────────────────┐
     │    OPNsense VM       │
     │    (pve-01, VMID 300)│
     │                      │
     │ WAN: vtnet0           │──→ 10.0.0.100 (vmbrWAN → Speedport)
     │ LAN: vtnet1           │──→ 10.0.0.10  (vmbr0 native, shared L2)
     │  ├─ VLAN 10 (opt1)   │──→ 10.0.10.1  (MGMT_VLAN10)
     │  ├─ VLAN 20 (opt2)   │──→ 10.0.20.1  (MGMT_VLAN20)
     │  ├─ VLAN 30 (opt3)   │──→ 10.0.30.1  (MGMT_VLAN30)
     │  └─ Tailscale (opt4) │──→ 100.120.6.1 (TAIL)
     └─────────────────────┘
               │ (VLAN trunk via vmbr0)
               │
 ┌─────────────┼─────────────┐
 │             │             │
 ▼             ▼             ▼
┌───────┐  ┌────────┐  ┌────────┐
│VLAN 10│  │VLAN 20 │  │VLAN 30 │
│Infra  │  │K8s     │  │Ingress │
└───────┘  └────────┘  └────────┘
```

### OPNsense Interface Mapping

| OPNsense Name | FreeBSD Device | IPv4 | IPv6 ULA | OPNsense Role | Purpose |
|---------------|----------------|------|----------|---------------|---------|
| WAN | vtnet0 | 10.0.0.100 | — | wan | Internet via Speedport |
| LAN | vtnet1 | 10.0.0.10 | fd00:1::1/64 | lan | Home/WiFi gateway + VLAN trunk parent |
| MGMT_VLAN10 | vtnet1_vlan10 | 10.0.10.1 | fd00:1:10::1/64 | opt1 | Infrastructure gateway |
| MGMT_VLAN20 | vtnet1_vlan20 | 10.0.20.1 | fd00:1:20::1/64 | opt2 | Kubernetes gateway |
| MGMT_VLAN30 | vtnet1_vlan30 | 10.0.30.1 | fd00:1:30::1/64 | opt3 | Services/Ingress gateway |
| TAIL | tailscale0 | 100.120.6.1 | — | opt4 | Tailscale overlay |

## Subnet Design

| Segment | VLAN | Subnet | Gateway (OPNsense) | Kea DHCP Pool | DNS Server | NTP Server | Purpose |
|---------|------|--------|---------------------|---------------|------------|------------|---------|
| **Home / Base LAN** | native | 10.0.0.0/24 | 10.0.0.10 (LAN) | 10.0.0.2-240 | 10.0.0.10 | 10.0.0.10 | WiFi clients, consumer devices |
| **Infrastructure** | 10 | 10.0.10.0/24 | 10.0.10.1 | 10.0.10.2-240 | 10.0.10.1 | 10.0.10.1 | Proxmox, PBS, SMB, Bastion |
| **Kubernetes Nodes** | 20 | 10.0.20.0/24 | 10.0.20.1 | 10.0.20.2-240 | 10.0.20.1 | 10.0.20.1 | K8s control plane + workers |
| **Services/Ingress** | 30 | 10.0.30.0/24 | 10.0.30.1 | 10.0.30.2-240 | 10.0.30.1 | 10.0.30.1 | Traefik VIP, LoadBalancers |

All subnets use domain `m0sh1.cc` with search domain `m0sh1.cc`. DHCP provided by **Kea DHCPv4** on OPNsense (lease time: 3600s).

**Important:** The Home/Base LAN gateway is OPNsense (10.0.0.10), **not** the Speedport (10.0.0.1). WiFi clients get their gateway, DNS, and NTP from OPNsense via Kea DHCP. This enables WiFi clients to reach all lab VLANs through OPNsense inter-VLAN routing without any static routes on the Speedport.

### IPv6 ULA Addressing

**Status:** Operational (SLAAC + stateless DHCPv6)
**Prefix:** `fd00:1::/48` — subnet IDs mirror VLAN IDs for readability
**Updated:** 2026-02-27

| Segment | VLAN | IPv6 ULA Subnet | OPNsense Gateway | Kea DHCPv6 Pool | DNS Server |
|---------|------|-----------------|-------------------|-----------------|------------|
| **Home / Base LAN** | native | fd00:1::/64 | fd00:1::1 | fd00:1::100 – fd00:1::1ff | fd00:1::1 |
| **Infrastructure** | 10 | fd00:1:10::/64 | fd00:1:10::1 | fd00:1:10::100 – fd00:1:10::1ff | fd00:1:10::1 |
| **Kubernetes Nodes** | 20 | fd00:1:20::/64 | fd00:1:20::1 | fd00:1:20::100 – fd00:1:20::1ff | fd00:1:20::1 |
| **Services/Ingress** | 30 | fd00:1:30::/64 | fd00:1:30::1 | fd00:1:30::100 – fd00:1:30::1ff | fd00:1:30::1 |

**Router Advertisements (radvd):** Assist mode (O flag) on all interfaces. SLAAC provides addresses; DHCPv6 provides DNS info. `DeprecatePrefix off` + `AdvAutonomous on` ensures SLAAC addresses remain preferred (Android compatibility).

**Kea DHCPv6:** Enabled on `lan,opt1,opt2,opt3`. 256 addresses per pool (::100 to ::1ff). Domain search: `m0sh1.cc`.

**Speedport ULA:** Disabled. The Speedport previously advertised its own ULA prefix (`fd8d:a82b:a42f::/48`) via RAs, which competed with OPNsense on the shared home LAN segment. This was disabled in favor of OPNsense's `fd00:1::/48` scheme.

**Known limitations:**

- WAN has no IPv6 (no DHCPv6-PD from Speedport yet — future phase)
- `DeprecatePrefix` and HA hook workarounds applied directly — may be overwritten by OPNsense template regeneration on service restart. Verify after OPNsense upgrades.

#### Unbound AAAA Records

AAAA host overrides added for all infrastructure and K8s hosts:

```yaml
opn.m0sh1.cc         → fd00:1:10::1
pve01.m0sh1.cc       → fd00:1:10::11
pve02.m0sh1.cc       → fd00:1:10::12
pve03.m0sh1.cc       → fd00:1:10::13
labctrl.m0sh1.cc     → fd00:1:20::20
horse01.m0sh1.cc     → fd00:1:20::21
horse02.m0sh1.cc     → fd00:1:20::22
horse03.m0sh1.cc     → fd00:1:20::23
horse04.m0sh1.cc     → fd00:1:20::24
```

## Static IP Allocations

### Home / Base LAN (10.0.0.0/24)

| Name | Type | IP | MAC | Purpose |
|------|------|----|-----|---------|
| speedport | Router | 10.0.0.1 | DC:F5:1B:08:9F:7C | ISP router + WiFi AP |
| switch | Switch | 10.0.0.2 | 98:DE:D0:F2:6B:B0 | L2 switch (VLAN trunk) |
| sm-watch | Device | 10.0.0.3 | 16:64:47:73:73:8a | Apple Watch |
| mbp-sm-m4 | Laptop (WiFi) | 10.0.0.4 | 5a:47:f0:51:e2:5a | MacBook Pro M4 (WiFi interface) |
| jewishspacelaser | Phone | 10.0.0.5 | ea:9e:cb:ac:95:26 | iPhone |
| s22-von-stuart | Phone | 10.0.0.53 | f2:2e:27:9b:df:93 | Samsung Galaxy S22 |
| opnsense-wan | VM NIC | 10.0.0.100 | BC:24:11:3D:33:2A | OPNsense WAN interface |
| opnsense-lan | VM NIC | 10.0.0.10 | BC:24:11:73:DE:1F | OPNsense LAN interface (home gateway) |

### VLAN 10 — Infrastructure (10.0.10.0/24)

| Name | Type | IP | VMID | Node | Purpose |
|------|------|-------|------|------|---------|
| opnsense | VLAN interface | 10.0.10.1 | 300 | pve-01 | Default gateway VLAN 10 |
| mbp-sm-m4 | Laptop (LAN) | 10.0.10.4 | - | - | MacBook Pro M4 (Ethernet) |
| pve-01 | Proxmox host | 10.0.10.11 | - | - | Cluster node |
| pve-02 | Proxmox host | 10.0.10.12 | - | - | Cluster node |
| pve-03 | Proxmox host | 10.0.10.13 | - | - | Cluster node |
| pbs | VM | 10.0.10.14 | 120 | pve-01 | Proxmox Backup Server |
| bastion | VM | 10.0.10.15 | 250 | pve-02 | Jump host + IaC tooling |
| smb | LXC | 10.0.10.23 | 110 | pve-01 | Samba file server |
| apt | LXC | 10.0.10.24 | - | - | APT mirror |
| scripts | Host | 10.0.10.25 | - | - | Scripts host |

**Note**: Proxmox hosts also have management IPs on the home subnet (10.0.0.11-13) for corosync. Both are registered in Unbound and CoreDNS for Proxmox CSI compatibility.

### VLAN 20 — Kubernetes Nodes (10.0.20.0/24)

| Name | Type | IP (eth0) | VMID | Node | Role |
|------|------|-----------|------|------|------|
| opnsense | VLAN interface | 10.0.20.1 | - | - | Default gateway VLAN 20 |
| pbs | VM (secondary) | 10.0.20.14 | 120 | pve-01 | PBS backup access from K8s |
| labctrl | VM | 10.0.20.20 | 201 | pve-01 | Control plane |
| horse01 | VM | 10.0.20.21 | 210 | pve-01 | Worker |
| horse02 | VM | 10.0.20.22 | 211 | pve-02 | Worker |
| horse03 | VM | 10.0.20.23 | 212 | pve-03 | Worker |
| horse04 | VM | 10.0.20.24 | 213 | pve-02 | Worker |

### VLAN 30 — Services/Ingress (10.0.30.0/24)

| Name | Type | IP | Purpose |
|------|------|----|---------|
| opnsense | VLAN interface | 10.0.30.1 | Default gateway VLAN 30 |
| traefik-vip | Cilium LB | 10.0.30.10, fd00:1:30::10 | Traefik ingress controller (dual-stack) |
| diode-nginx | Cilium LB | 10.0.30.15, fd00:1:30::15 | Diode ingress-nginx controller (dual-stack) |
| alloy-syslog | Cilium LB | 10.0.30.14, fd00:1:30::14 | Alloy syslog receiver (OPNsense logs) |
| (reserved) | Cilium LB | 10.0.30.15-49 | Additional LoadBalancer services |
| labctrl-v30 | VM interface (eth1) | 10.0.30.50 | K8s node secondary NIC (Cilium L2 announcements) |
| horse01-v30 | VM interface (eth1) | 10.0.30.51 | K8s node secondary NIC (Cilium L2 announcements) |
| horse02-v30 | VM interface (eth1) | 10.0.30.52 | K8s node secondary NIC (Cilium L2 announcements) |
| horse03-v30 | VM interface (eth1) | 10.0.30.53 | K8s node secondary NIC (Cilium L2 announcements) |
| horse04-v30 | VM interface (eth1) | 10.0.30.54 | K8s node secondary NIC (Cilium L2 announcements) |

## DNS Configuration

### Unbound DNS (OPNsense)

Unbound listens on **all OPNsense interfaces** including WAN (10.0.0.100) and LAN (10.0.0.10), enabling DNS resolution from any VLAN or the home network.

Zone: `m0sh1.cc` (transparent)

#### Infrastructure (VLAN 10 - Direct)

```yaml
opn.m0sh1.cc        → 10.0.0.10, 10.0.10.1, 10.0.20.1, 10.0.30.1, 10.0.0.100
switch.m0sh1.cc     → 10.0.0.2
speedport.m0sh1.cc  → 10.0.0.1
pve01.m0sh1.cc      → 10.0.10.11
pve02.m0sh1.cc      → 10.0.10.12
pve03.m0sh1.cc      → 10.0.10.13
pbs.m0sh1.cc        → 10.0.10.14
bastion.m0sh1.cc    → 10.0.10.15
smb.m0sh1.cc        → 10.0.10.23
apt.m0sh1.cc        → 10.0.10.24
scripts.m0sh1.cc    → 10.0.10.25
```

#### Kubernetes Nodes (VLAN 20 - Direct)

```yaml
labctrl.m0sh1.cc    → 10.0.20.20
lab-ctrl.m0sh1.cc   → 10.0.20.20   # alias
horse01.m0sh1.cc    → 10.0.20.21
horse02.m0sh1.cc    → 10.0.20.22
horse03.m0sh1.cc    → 10.0.20.23
horse04.m0sh1.cc    → 10.0.20.24
```

#### Applications (VLAN 30 - via Traefik VIP 10.0.30.10)

```yaml
argocd.m0sh1.cc       harbor.m0sh1.cc       grafana.m0sh1.cc
prometheus.m0sh1.cc   auth.m0sh1.cc         netbox.m0sh1.cc
pgadmin.m0sh1.cc      semaphore.m0sh1.cc    headlamp.m0sh1.cc
vault.m0sh1.cc        renovate.m0sh1.cc     uptime.m0sh1.cc
uptime-api.m0sh1.cc   s3.m0sh1.cc           s3-console.m0sh1.cc
basic-memory.m0sh1.cc livesync.m0sh1.cc     scanopy.m0sh1.cc
bremse.m0sh1.cc       menux.m0sh1.cc        termix.m0sh1.cc
termix-api.m0sh1.cc   status.m0sh1.cc       ai.m0sh1.cc
ci.m0sh1.cc
```

#### Home Devices (Base LAN - via Kea reservations)

```yaml
mbp-sm-m4.m0sh1.cc       → 10.0.0.4, 10.0.10.4
jewishspacelaser.m0sh1.cc → 10.0.0.5
sm-watch.m0sh1.cc         → 10.0.0.3
s22-von-stuart.m0sh1.cc   → 10.0.0.53
```

Wildcard overrides are intentionally avoided to prevent accidental exposure of services that should remain behind Cloudflare Access.

### k3s CoreDNS

- **NodeHosts**: Kubernetes nodes (lab-ctrl, horse01-04) resolved via k3s built-in
- **Proxmox hosts**: Static entries via CoreDNS wrapper chart (`apps/cluster/coredns/`)
  - pve01/02/03.m0sh1.cc → 10.0.10.11-13
  - Fixes Proxmox CSI DNS failures (OPNsense Unbound unreliable under sustained load)
- **Upstream forwarding**: 10.0.20.1 (OPNsense Unbound) → DNS-over-TLS → Cloudflare 1.1.1.1 / 1.0.0.1 (port 853, Verify CN: `one.one.one.one`)

## Remote Access & Trust Model

### Tailscale Configuration

**Subnet router: OPNsense** (opn.xerus-nominal.ts.net, 100.120.6.1)

| Setting | Value |
|---------|-------|
| Enabled | ✓ |
| Listen Port | 41641 |
| Advertise Exit Node | ✓ |
| Accept DNS | ✗ |
| Accept Subnet Routes | ✗ |
| Use Exit Node | None |

**Advertised routes (4 subnets):**

- 10.0.0.0/24 (Home / Base LAN)
- 10.0.10.0/24 (Infrastructure)
- 10.0.20.0/24 (Kubernetes)
- 10.0.30.0/24 (Services / Ingress)

Routes are auto-approved via Tailscale ACLs. No static routes or firewall exceptions required on the Speedport.

### Tailnet Members

| Tailscale IP | Hostname | OS | Role |
|-------------|----------|------|------|
| 100.120.6.1 | opn | FreeBSD | Subnet router + exit node |
| 100.120.6.5 | mbp-sm-m4 | macOS | Client |
| 100.120.6.10 | jewishspacelaser | iOS | Client |

### DNS by Trust Context

**On Tailscale (Trusted):**

```text
argocd.m0sh1.cc
  → Tailscale DNS (100.100.100.100)
  → OPNsense Unbound
  → A record: 10.0.30.10
  → Traefik Ingress (VLAN 30)
```

- Cloudflare is intentionally bypassed
- No AAAA record served internally to avoid IPv6 preference issues
- Access control enforced by Tailscale ACLs

**Off Tailscale (Public):**

```text
argocd.m0sh1.cc
  → Public DNS
  → Cloudflare Anycast
  → Cloudflare Access (SSO / Zero Trust)
```

### Client Requirements

Clients accessing the lab via Tailscale must:

- Have Tailscale installed
- Enable "Use Tailscale DNS settings"
- Enable "Accept subnet routes"

```bash
# Reset if routes/DNS not applying
sudo tailscale up --reset --accept-routes=true
```

### macOS Split DNS (Recommended)

To avoid Tailscale DNS timeouts when Tailscale is inactive, create a resolver override:

```bash
sudo mkdir -p /etc/resolver
printf 'nameserver 10.0.10.1\nnameserver 10.0.0.10\nsearch m0sh1.cc\n' | sudo tee /etc/resolver/m0sh1.cc
```

This ensures `*.m0sh1.cc` queries always go directly to OPNsense, regardless of Tailscale state or which network interface is active.

## Firewall Rules (OPNsense pf)

**Current rules (7 total, verified 2026-02-27):**

| # | Interface | Protocol | Source | Destination | Port | Description |
|---|-----------|----------|--------|-------------|------|-------------|
| 1 | Floating (3) | TCP/UDP | VLAN20 net | VLAN10 net | 8006 | Proxmox CSI API bypass (**disabled**) |
| 2 | LAN | * | LAN net | * | * | Default allow LAN to any |
| 3 | MGMT_VLAN10 | * | VLAN10 net | * | * | Pass all |
| 4 | MGMT_VLAN10 | TCP/UDP | VLAN20 net | VLAN10 net | 8006 | Proxmox CSI API bypass |
| 5 | MGMT_VLAN20 | * | VLAN20 net | * | * | Pass all |
| 6 | MGMT_VLAN20 | TCP/UDP | VLAN20 net | VLAN10 net | 8006 | Proxmox CSI API bypass |
| 7 | MGMT_VLAN30 | * | VLAN30 net | * | * | Pass all |

**Design:** Each VLAN has a "pass all from own subnet" rule. The LAN (home WiFi) also has "allow to any", enabling WiFi clients to access all VLANs through OPNsense routing.

**Outbound NAT:** Automatic mode — NAT only on WAN interface. Inter-VLAN traffic is NOT NATed.

## Cilium LB-IPAM Configuration

**Status:** ✅ Operational (Dual-Stack)
**Replaced:** MetalLB (migrated 2026-03-01)

- **Pool**: `services-vlan30` (CiliumLoadBalancerIPPool)
  - IPv4: `10.0.30.10-10.0.30.49`
  - IPv6: `fd00:1:30::10-fd00:1:30::49`
- **L2 Announcements**: CiliumL2AnnouncementPolicy (ARP for IPv4, NDP for IPv6) — all nodes participate
- **Current Assignments**:
  - 10.0.30.10 / fd00:1:30::10 → traefik-lan LoadBalancer
  - 10.0.30.15 / fd00:1:30::15 → diode-nginx LoadBalancer
  - 10.0.30.14 / fd00:1:30::14 → alloy-syslog LoadBalancer
- **IP allocation**: Via `lbipam.cilium.io/ips` annotation on Services (explicit assignment)

**Dual-NIC K8s Nodes:**

- **Primary NIC (eth0)**: VLAN 20 (10.0.20.0/24) — Pod network, cluster communication
- **Secondary NIC (eth1)**: VLAN 30 (10.0.30.0/24) — Cilium L2 announcement interface
- **Why dual-NIC**: L2 announcements require nodes to ARP/NDP on the same VLAN as LoadBalancer IPs

**Note:** ICMP (ping) to LB VIPs works with Cilium eBPF datapath (unlike MetalLB + kube-proxy).

## K3s Dual-Stack

**Status:** Configured (pending Ansible apply)

| Resource | IPv4 | IPv6 ULA |
|----------|------|----------|
| Pod CIDR | 10.42.0.0/16 | fd00:42::/48 |
| Service CIDR | 10.43.0.0/16 | fd00:43::/112 |
| LB-IPAM Pool | 10.0.30.10-49 | fd00:1:30::10-49 |

**Node dual-stack IPs (VLAN 20):**

| Node | IPv4 | IPv6 |
|------|------|------|
| labctrl | 10.0.20.20 | fd00:1:20::20 |
| horse01 | 10.0.20.21 | fd00:1:20::21 |
| horse02 | 10.0.20.22 | fd00:1:20::22 |
| horse03 | 10.0.20.23 | fd00:1:20::23 |
| horse04 | 10.0.20.24 | fd00:1:20::24 |

**CNI:** Cilium v1.19.1 (replaced Flannel, 2026-03-01). Native routing mode (no VXLAN overhead — all nodes share VLAN 20 L2 segment). eBPF datapath replaces kube-proxy. IPAM mode: `cluster-pool` (Cilium manages pod CIDRs independently of k3s node.spec.podCIDRs).

**Config:** Managed via Ansible `group_vars/k3s_control_plane/k3s.yaml` (`k3s_cluster_cidr`, `k3s_service_cidr`) and per-node `k3s_node_ipv6` in host_vars. Cilium values in `apps/cluster/cilium/values.yaml`.

## Traffic Flow

### Client → Application

```text
[Client on any VLAN or WiFi]
    ↓
[OPNsense inter-VLAN routing]
    ↓
[10.0.30.10 - Traefik VIP (VLAN 30)]
    ↓
[Cilium L2 ARP announcement → K8s node eth1]
    ↓
[Cilium eBPF → Traefik pod]
    ↓
[Traefik routes to backend pods]
```

### WiFi → Lab Services

```text
[Mac on WiFi (10.0.0.4)]
    ↓ (gateway: 10.0.0.10)
[OPNsense LAN interface (vtnet1)]
    ↓ (firewall: "Default allow LAN to any")
[OPNsense routes to target VLAN]
    ↓
[Target service responds]
    ↓ (return path: OPNsense → LAN → Mac)
```

## Physical Connectivity

### Proxmox Hosts (pve-01/02/03)

- **Single NIC** → Switch → `vmbr0` (VLAN trunk)
- **VLAN tagging**: Done at VM/LXC level
- **Bridge config**: `vmbr0` carries VLANs 10, 20, 30 (native = home 10.0.0.0/24)

### OPNsense VM (VMID 300)

- **WAN NIC (net0)**: `vmbrWAN` (MAC: BC:24:11:3D:33:2A) → USB NIC → Speedport LAN
  - IP: 10.0.0.100/24 — default route to 10.0.0.1 (Speedport)
- **LAN NIC (net2)**: `vmbr0` trunk (MAC: BC:24:11:73:DE:1F) — VLANs 10,20,30
  - Native (untagged): 10.0.0.10/24 — home/WiFi gateway
  - VLAN 10: 10.0.10.1/24
  - VLAN 20: 10.0.20.1/24
  - VLAN 30: 10.0.30.1/24

**Note:** OPNsense has **two interfaces on 10.0.0.0/24** (WAN at .100, LAN at .10). WAN is for internet egress; LAN is for home client gateway services (DHCP, DNS, routing).

### K8s Node VMs

- **Dual NIC configuration**:
  - **eth0 (net0)**: `vmbr0` with VLAN 20 tag → 10.0.20.20-24
    - Purpose: Pod network, cluster communication, default route
    - Gateway: 10.0.20.1 (OPNsense)
  - **eth1 (net1)**: `vmbr0` with VLAN 30 tag → 10.0.30.50-54
    - Purpose: Cilium L2 announcements (ARP/NDP for LoadBalancer VIPs)
    - No gateway configured

### Infrastructure LXCs/VMs

- **Single NIC** → `vmbr0` with VLAN 10 tag
- **Gateway**: 10.0.10.1 (OPNsense)

## Troubleshooting

### DNS Resolution Issues

```bash
# Test DNS from K8s node
ssh root@labctrl
dig @10.0.20.1 argocd.m0sh1.cc

# Test DNS from infrastructure VLAN
ssh root@pve01
dig @10.0.10.1 harbor.m0sh1.cc

# Test DNS from home/WiFi
dig @10.0.0.10 argocd.m0sh1.cc
```

### Cilium LB-IPAM / Service Access Issues

```bash
# Test service connectivity
curl -sk https://argocd.m0sh1.cc

# Check Cilium LB-IPAM pools and L2 announcements
kubectl get ciliumloadbalancerippool,ciliuml2announcementpolicy

# Check LB IP assignments
kubectl get svc -A -o wide | grep LoadBalancer

# Check Cilium status
kubectl -n kube-system exec ds/cilium -- cilium-dbg status

# Check service events
kubectl describe svc -n traefik traefik-lan
```

### Inter-VLAN Routing Issues

```bash
# From K8s node, test connectivity to infrastructure
ssh root@labctrl
ping 10.0.10.1   # OPNsense VLAN 10 gateway

# From infrastructure, test connectivity to services
ssh root@pve01
curl -sk https://traefik.m0sh1.cc  # Should resolve to 10.0.30.10

# From WiFi, verify routing through OPNsense
ping -S 10.0.0.4 10.0.10.11  # Should reach pve01 via OPNsense
ping -S 10.0.0.4 10.0.30.1   # Should reach VLAN 30 gateway
```

## DNS Resolution Chain

**Updated:** 2026-03-01

```text
Pods → CoreDNS (10.43.0.10) → OPNsense Unbound (10.0.20.1)
                                  → DNS-over-TLS (port 853)
                                  → Cloudflare 1.1.1.1 / 1.0.0.1
                                  (Verify CN: one.one.one.one)
```

- **DNSSEC**: Enabled in Unbound
- **Forward mode**: Forward first (try DoT, fall back to recursion)
- **No IPv6 upstreams**: WAN has no IPv6, so only IPv4 DoT forwarders configured

## Related Files

- Comprehensive architecture: `docs/network-architecture.md`
- Terraform VMs: `terraform/envs/lab/vms.tf`
- Cilium CNI: `apps/cluster/cilium/values.yaml`
- Cilium LB-IPAM pool: `apps/cluster/cilium/templates/lb-ipam-pool.yaml`
- Cilium L2 announcements: `apps/cluster/cilium/templates/l2-announcement-policy.yaml`
- Cilium network policies: `apps/cluster/cilium-policies/`, `apps/user/cilium-policies/`
- Traefik: `apps/cluster/traefik/values.yaml`
- CoreDNS: `apps/cluster/coredns/values.yaml`
- External DNS: `apps/cluster/external-dns/values.yaml`
- Alloy (syslog): `apps/cluster/alloy/values.yaml`
- OPNsense exporter: `apps/cluster/opnsense-exporter/values.yaml`
- OPNsense Ansible: `ansible/roles/opnsense/`
- OPNsense→Netbox sync: `tools/cli/docker/netbox/opnsense-sync.py`
- Tailscale operator: `apps/cluster/tailscale-operator/values.yaml`
- MetalLB (disabled): `argocd/disabled/cluster/metallb.yaml`
