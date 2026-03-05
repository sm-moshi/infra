# NetBox IPAM/DCIM Authority Model

**Status:** 📋 Design Document
**Updated:** 2026-03-05
**Purpose:** Define clean domain authority boundaries for NetBox IPAM/DCIM integration with the Proxmox cluster

## Design Philosophy

> Assign authority per domain and let everything else orbit around it like
> well-behaved planets — instead of fighting for gravitational dominance.

**One owner per domain. No overlaps. No second-guessing.**

The m0sh1.cc lab architecture is correctly layered. Each component has a
single, clear responsibility. This document codifies those boundaries so
automation respects them.

## Clean Authority Matrix

| Domain             | Authority    | Role                                          |
|--------------------|-------------|-----------------------------------------------|
| WAN/ISP            | ISP Router  | Forwards only (bridge/DMZ to OPNsense)         |
| Routing            | OPNsense    | Single L3 authority, inter-VLAN routing         |
| DHCP               | OPNsense    | Sole DHCP server across all VLANs               |
| DNS                | OPNsense    | Sole DNS authority (CoreDNS supplements for K8s)|
| VLAN definitions   | OPNsense    | Owns VLAN config; modeled in NetBox for visibility|
| Firewall rules     | OPNsense    | Owns all rules; synced to NetBox for visibility  |
| Physical switch    | L2 transport| Tagged VLAN trunks only — no routing, no DHCP   |
| VM lifecycle       | Terraform   | VM/LXC provisioning and destruction             |
| VM compute/storage | Proxmox     | Hosts VMs/LXCs — does NOT route, does NOT DHCP  |
| IP planning/intent | NetBox      | Source of truth for prefixes, reservations, inventory|
| Identity/SSO       | Authentik   | Single IdP for Proxmox, PBS, K8s apps           |
| Network discovery  | Scanopy/OrbAgent | Reports reality — does not modify anything |

## Data Flow

```text
                    NetBox (Intent / Source of Truth)
                              ↓
              ┌───────────────┴───────────────┐
              ↓                               ↓
    OPNsense (Enforcement)          Provisioning Scripts
              ↓                               ↓
       Network Traffic              Proxmox VM Creation
                                    (Terraform-governed)

    Parallel observation loops:
      Scanopy/OrbAgent → Discovers reality → Reports to NetBox (via Diode)
      OPNsense sync    → Pulls config     → Mirrors in NetBox security plugin
      Authentik        → Controls access   → SSO for all services
```

### Current Direction (Phase 1)

Reality flows **into** NetBox:

- `onboarding.py` seeds NetBox from Scanopy discovery data
- `opnsense_sync.py` pulls OPNsense aliases, rules, zones into NetBox
- OrbAgent (planned) will feed Diode with network discovery data

### Future Direction (Gradual Migration)

NetBox **defines** intent, automation **enforces**:

- Reserve IPs in NetBox before provisioning VMs
- Validate Terraform plans against NetBox-allocated addresses
- Drift detection alerts when reality diverges from intent

**Do not flip overnight.** Migrate gradually — one workflow at a time.

## Component Responsibilities

### OPNsense — Sole Network Brain

OPNsense is the **only** device that routes, filters, and assigns addresses.

**Owns:**

- VLAN definitions (10=Infra, 20=K8s, 30=Services, plus Home)
- Inter-VLAN routing and firewall rules
- DHCP leases and static mappings
- DNS resolution (primary; CoreDNS supplements for K8s reliability)
- NAT and WAN connectivity

**Does not:**

- Consult NetBox before applying rules (NetBox is observer, not controller)
- Delegate any L3 decisions to Proxmox or Kubernetes

### NetBox — Network Intent and Visibility

NetBox is the **single source of truth** for IP planning and infrastructure inventory.

**Owns:**

- Prefix and VLAN documentation (mirrors OPNsense reality)
- IP address reservations and status tracking
- Device and VM inventory (DCIM)
- Interface mappings and cable documentation
- Tenant and role assignments

**Receives from:**

- OPNsense: firewall rules, aliases, zones, DHCP mappings, routes (via sync script)
- Scanopy/OrbAgent: discovered hosts, ports, topology (via Diode)
- Terraform/onboarding.py: VM definitions, interfaces, IPs

**Does not:**

- Push configuration to OPNsense (observation only, not enforcement)
- Manage VM lifecycle (that's Terraform)
- Replace OPNsense for any L3 function

### Proxmox — Compute Only

Each Proxmox node receives a VLAN trunk from the physical switch, creates
Linux bridges, tags VLANs, and hosts VMs/LXCs.

**Does:**

- VM lifecycle management (create, start, stop, migrate)
- Storage management
- Compute resource allocation

**Does not:**

- Route traffic between VLANs
- Run DHCP or DNS services
- Replace the firewall

### Physical Switch — L2 Transport

The switch carries tagged VLAN trunks between OPNsense and Proxmox nodes.

**Does:** Tagged VLAN trunk ports. That's it.
**Does not:** Routing, DHCP, or any "smart" features.

### Terraform — VM Provisioning Authority

Terraform manages the VM/LXC lifecycle in `terraform/envs/lab/`.

**Owns:** VM definitions (vms.tf), LXC definitions (lxcs.tf), resource allocation.
**Does not:** Manage network configuration or IP assignment (defers to OPNsense/NetBox).

### Scanopy / OrbAgent — Network Observers

Discovery agents that report reality without modifying anything.

**Scanopy:** HostNetwork DaemonSet scanning VLAN 20 (K8s network).
**OrbAgent:** Network discovery via NMAP, feeding results to Diode → NetBox.

Think of them as: **Security camera system for the network.**

### Authentik — Identity Hub

Single IdP providing SSO for:

- Proxmox VE (PVE01-03)
- Proxmox Backup Server
- Kubernetes applications (via OIDC)
- OPNsense GUI (planned)

## Why PVE SDN Is Not Enabled

Proxmox SDN (`libpve-network-perl`) is installed but **intentionally unused**.

**Current networking:** Traditional Linux bridges (`vmbr0`, `vmbr0.{10,20,30}`,
`vmbrWAN`) with VLAN tags. Simple, reliable, well-understood.

**SDN would be needed only if:**

- VXLAN overlays were required (multi-site, cross-datacenter)
- Tenant isolation experiments demanded virtual network segmentation
- Cloud-like virtual networking was needed at scale

**None of these apply.** Three Proxmox nodes on the same physical switch with
four VLANs do not need an overlay network or a third control plane.

**Rule:** Do not enable SDN unless solving a real problem.

See `docs/diaries/pve-sdn-evaluation.md` for the full evaluation.

## Network Architecture Reference

| VLAN | Subnet (IPv4)   | Subnet (IPv6)      | Purpose          |
|------|-----------------|---------------------|------------------|
| —    | 10.0.0.0/24     | —                   | Home network     |
| 10   | 10.0.10.0/24    | fd00:1:10::/64      | Infrastructure   |
| 20   | 10.0.20.0/24    | fd00:1:20::/64      | Kubernetes       |
| 30   | 10.0.30.0/24    | fd00:1:30::/64      | Services / LB    |

### Cluster-internal CIDRs (Cilium IPAM)

| CIDR            | Purpose                  |
|-----------------|--------------------------|
| 10.42.0.0/16    | Cilium pod CIDR (IPv4)   |
| fd00:42::/48    | Cilium pod CIDR (IPv6)   |
| 10.43.0.0/16    | K8s service CIDR (IPv4)  |
| fd00:43::/112   | K8s service CIDR (IPv6)  |

CNI is Cilium (replaced flannel 2026-02-28) with dual-stack IPv6, BPF masquerading,
hybrid DSR, and kube-proxy replacement enabled.

### Key addresses

- **PVE nodes:** 10.0.10.{11-13}:8006
- **PBS:** 10.0.10.14:8007
- **OPNsense:** 10.0.10.1 (8 vCPU, 8 GB RAM — VMID 300 on pve-01)

### MetalLB LoadBalancer VIP allocations

| IP          | IPv6             | Service        |
|-------------|------------------|----------------|
| 10.0.30.10  | fd00:1:30::10    | Traefik        |
| 10.0.30.14  | fd00:1:30::14    | Alloy syslog   |
| 10.0.30.15  | fd00:1:30::15    | Diode          |

Note: 10.0.30.{11-13} are PVE host IPs on vmbr0.30 — do not allocate as LB VIPs.

### Security and observability layer

- **CrowdSec**: Separate LAPI in k8s (agent parses Traefik logs, AppSec WAF on port 7422).
  Also runs on OPNsense (local LAPI, parses pf + Suricata).
- **Suricata IDS**: Enabled on OPNsense WAN interface (~284k rules, ET Open rulesets).
  EVE JSON dual-output (file + syslog local5) → syslog-ng → Alloy → Loki.
- **OPNsense syslog**: TCP 1514 → Alloy DaemonSet (LB 10.0.30.14) → Loki.

### Hardware note (2026-03-03)

pve-01 WAN NIC swapped from USB CDC NCM (nic2, 6.7M tx timeouts) to Intel I219-LM
PCIe (nic0) with EEE disabled. OPNsense VM virtual NICs (virtio) unchanged.

See `docs/diaries/network-vlan-architecture.md` for the complete network design.

## Day-2 Operations

- **New VM**: Terraform creates VM → `proxmox-discover.py` syncs to NetBox → allocate IP in NetBox
- **New IP**: Create in NetBox IPAM → OPNsense remains enforcement authority
- **Drift check**: `drift-report.py` compares NetBox vs Proxmox/OPNsense/OrbAgent (nightly via Woodpecker)
- **OPNsense changes**: Auto-synced to NetBox via `opnsense_sync.py` custom script

## Automation Scripts

Located in `tools/cli/docker/netbox/`:

- `onboarding.py` — Idempotent seeder (`--mode seed`) + reconcile reporter (`--mode reconcile`)
- `opnsense-sync.py` — OPNsense → NetBox custom script (runs inside NetBox pod)
- `proxmox-discover.py` — Proxmox VM/CT discovery (standalone CLI)
- `drift-report.py` — Cross-system drift detection (standalone CLI, JSON output)

## Related Documents

- `docs/diaries/network-vlan-architecture.md` — Full 4-VLAN network design
- `docs/diaries/pve-sdn-evaluation.md` — Why PVE SDN is not needed
- `AGENTS.md` — Repository enforcement contract (GitOps rules)
