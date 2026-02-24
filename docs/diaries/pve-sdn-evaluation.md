# PVE SDN Evaluation

**Status:** 📋 Evaluation Document (no implementation planned)
**Updated:** 2026-02-24
**Purpose:** Document why Proxmox VE SDN is not needed and when it would become relevant

## Executive Summary

Proxmox VE SDN (`libpve-network-perl 1.2.5`) is installed on all PVE nodes but
**intentionally left unconfigured**. The current networking setup — traditional Linux
bridges with VLAN tags — is the correct choice for this homelab's scale and requirements.

**Recommendation:** Do not enable PVE SDN. Revisit only if overlay networking becomes a real need.

## Current Networking

### What's Deployed

```text
Physical Switch (L2 trunk)
    ↓
PVE Nodes (vmbr0 + vmbr0.{10,20,30} + vmbrWAN)
    ↓
VMs/LXCs (tagged VLAN interfaces)
    ↓
OPNsense (sole L3 router — inter-VLAN routing, DHCP, DNS, firewall)
```

- **3 PVE nodes** on the same physical switch
- **4 VLANs**: Home (untagged), VLAN 10 (Infra), VLAN 20 (K8s), VLAN 30 (Services)
- **Traditional Linux bridges**: `vmbr0`, `vmbr0.10`, `vmbr0.20`, `vmbr0.30`, `vmbrWAN`
- **OPNsense** as sole L3 authority

### Why This Works

- Simple: one bridge per VLAN, well-understood Linux networking
- Reliable: no additional control plane, no SDN daemon to fail
- Debuggable: standard tools (`ip`, `bridge`, `tcpdump`)
- Performant: native VLAN tagging at kernel level

## What PVE SDN Would Add

### SDN Architecture (If Enabled)

```text
PVE SDN Controller
    ↓
Zones (Simple, VLAN, QinQ, VXLAN, EVPN)
    ↓
VNets (Virtual Networks — replace bridges)
    ↓
Subnets (IP allocation within VNets)
    ↓
IPAM Provider (pve, netbox, phpipam)
```

### SDN Zone Types

| Zone Type | Use Case | Relevant Here? |
|-----------|----------|----------------|
| Simple    | Basic L2, like current bridges | No advantage |
| VLAN      | VLAN-tagged, like current setup | No advantage |
| QinQ      | Stacked VLANs (ISP, multi-tenant) | No |
| VXLAN     | L2 overlay across L3 boundaries | No |
| EVPN      | Full overlay with BGP control plane | No |

### IPAM Integration

PVE SDN supports registering an external IPAM (NetBox, phpIPAM):

```text
pvesh create /cluster/sdn/ipams --ipam netbox --type netbox --url <URL> --token <TOKEN>
```

This would let PVE query NetBox for IP allocation when creating VM interfaces
in SDN VNets. However, this **only works with SDN VNets**, not traditional bridges.

## Why SDN Is Not Needed

### 1. No Overlay Requirement

SDN's primary value is VXLAN/EVPN overlays for multi-site or cross-datacenter L2
extension. With 3 nodes on the same switch, there is no L3 boundary to bridge.

### 2. No Tenant Isolation Need

SDN zones provide tenant isolation. This is a single-operator homelab — there are
no tenants requiring network isolation beyond existing VLAN segmentation.

### 3. Additional Complexity, No Benefit

Enabling SDN adds:

- A new control plane (SDN controller service)
- VNet abstraction layer over existing bridges
- Zone configuration management
- Potential for misconfiguration during migration

For zero functional benefit at this scale.

### 4. Migration Risk

Switching from traditional bridges to SDN VNets would require:

1. Creating SDN zones and VNets matching current VLANs
2. Migrating every VM/LXC network interface from `vmbr0.X` to VNet equivalents
3. Brief network interruption per VM during migration
4. Testing all inter-VLAN routing still works through OPNsense

The risk/reward ratio is unfavorable.

## When To Revisit

SDN would become relevant if:

1. **Multi-site expansion** — A second physical location needs L2 extension
   via VXLAN overlay across a WAN link
2. **Tenant isolation** — Multiple users/teams need isolated virtual networks
   that go beyond VLAN-level segmentation
3. **Cloud-like provisioning** — Automated VM creation needs dynamic network
   allocation that SDN VNets provide natively
4. **Scale beyond current switch** — If nodes span multiple switches without
   VLAN trunk capability

**None of these currently apply or are planned.**

## Conclusion

Traditional Linux bridges + VLAN tags are the correct choice for this lab.
PVE SDN solves problems that don't exist here. Keep it installed but unconfigured.

If the need arises in the future, the migration path is documented above.

## Related Documents

- `docs/diaries/netbox-proxmox-authority-model.md` — Domain authority boundaries
- `docs/diaries/network-vlan-architecture.md` — Full 4-VLAN network design
