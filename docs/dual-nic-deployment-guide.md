# K8s Dual-NIC Deployment Guide

**Purpose:** Add secondary NICs to all K8s nodes for MetalLB L2Advertisement on VLAN 30

**Status:** 🔶 READY FOR REVIEW - Do NOT apply until approved

**Date:** 2026-01-29

---

## Problem Statement

MetalLB L2 mode requires nodes to send ARP replies on the same VLAN as LoadBalancer IPs. Currently:

- ❌ K8s nodes on VLAN 20 (10.0.20.0/24)
- ❌ MetalLB VIPs on VLAN 30 (10.0.30.0/24)
- ❌ ARP doesn't cross VLANs → Traefik VIP (10.0.30.10) unreachable

**Solution:** Add secondary NICs to K8s nodes on VLAN 30 for MetalLB L2Advertisement.

---

## Architecture

### Before (Current - Broken)

```text
K8s Nodes (VLAN 20)
  └─ eth0: 10.0.20.20-24
      └─ MetalLB speakers try to ARP for 10.0.30.10
          └─ ❌ ARP requests on VLAN 20 don't reach VLAN 30
```

### After (Dual-NIC - Working)

```text
K8s Nodes (Dual-NIC)
  ├─ eth0: 10.0.20.20-24 (VLAN 20) - Pod network, default route
  └─ eth1: 10.0.30.50-54 (VLAN 30) - MetalLB L2Advertisement
      └─ MetalLB speakers ARP for 10.0.30.10 on eth1
          └─ ✅ ARP requests on VLAN 30 work correctly
```

### IP Allocations

| Node | Primary (eth0) VLAN 20 | Secondary (eth1) VLAN 30 | Purpose |
|------|------------------------|--------------------------|---------|
| labctrl | 10.0.20.20/24 | 10.0.30.50/24 | Control plane + MetalLB |
| horse01 | 10.0.20.21/24 | 10.0.30.51/24 | Worker + MetalLB |
| horse02 | 10.0.20.22/24 | 10.0.30.52/24 | Worker + MetalLB |
| horse03 | 10.0.20.23/24 | 10.0.30.53/24 | Worker + MetalLB |
| horse04 | 10.0.20.24/24 | 10.0.30.54/24 | Worker + MetalLB |

### Routing

**eth0 (VLAN 20):**

- Gateway: 10.0.20.1 (default route)
- Routes: All traffic except VLAN 30

**eth1 (VLAN 30):**

- No gateway configured
- Routes: Only 10.0.30.0/24 subnet

---

## Deployment Steps

### Phase 1: Documentation Review ✅

- [x] Review [network-vlan-architecture.md](../network-vlan-architecture.md) updates
- [x] Review [terraform/envs/lab/vms-dual-nic-CHANGES.tf](../../terraform/envs/lab/vms-dual-nic-CHANGES.tf)
- [x] Review [ansible/playbooks/k3s-secondary-nic.yaml](../../ansible/playbooks/k3s-secondary-nic.yaml)

### Phase 2: Terraform Changes ⏸️ (DO NOT RUN YET)

**WARNING:** These changes will reconfigure VM network devices. Coordinate with cluster operations.

1. **Apply Terraform changes to vms.tf:**

   Open `terraform/envs/lab/vms.tf` and manually apply the changes from `vms-dual-nic-CHANGES.tf` to each K8s module:

   - `module "lab_ctrl"`
   - `module "horse_01"`
   - `module "horse_02"`
   - `module "horse_03"`
   - `module "horse_04"`

2. **Validate Terraform:**

   ```bash
   cd terraform/envs/lab
   terraform fmt
   terraform validate
   terraform plan -out=tfplan
   ```

3. **Review plan output:**

   Should show `update in-place` for each K8s VM with network device additions:

   ```text
   # module.lab_ctrl.proxmox_virtual_environment_vm.vm will be updated in-place
     ~ network_device {
         + network_device {
             + bridge   = "vmbr0"
             + mac_address = "BC:24:11:4A:9D:30"
             + queues   = 2
             + vlan_id  = 30
           }
       }
   ```

4. **Apply Terraform (after approval):**

   ```bash
   terraform apply tfplan
   ```

5. **Verify NICs added in Proxmox:**

   ```bash
   # Run on each Proxmox node
   qm config 201 | grep net  # lab-ctrl
   qm config 210 | grep net  # horse-01
   qm config 211 | grep net  # horse-02
   qm config 212 | grep net  # horse-03
   qm config 213 | grep net  # horse-04
   ```

   Expected output:

   ```text
   net0: virtio=BC:24:11:4A:9D:06,bridge=vmbr0,firewall=0,tag=20
   net1: virtio=BC:24:11:4A:9D:30,bridge=vmbr0,firewall=0,tag=30
   ```

6. **Reboot K8s nodes to activate new NICs:**

   ```bash
   # Drain nodes first
   kubectl drain labctrl --ignore-daemonsets --delete-emptydir-data
   kubectl drain horse01 --ignore-daemonsets --delete-emptydir-data
   # ... repeat for all nodes

   # Reboot via Proxmox or SSH
   ssh root@labctrl 'reboot'
   ssh root@horse01 'reboot'
   # ... repeat for all nodes

   # Wait for nodes to come back
   kubectl get nodes -w

   # Uncordon nodes
   kubectl uncordon labctrl horse01 horse02 horse03 horse04
   ```

### Phase 3: Ansible Configuration ⏸️ (DO NOT RUN YET)

**WARNING:** Only run after VMs rebooted with new NICs.

1. **Verify eth1 exists on all nodes:**

   ```bash
   ansible k3s_control_plane:k3s_workers -m command -a "ip link show eth1"
   ```

   Expected: `eth1: <BROADCAST,MULTICAST> mtu 1500 ...` (DOWN state is OK)

2. **Dry-run Ansible playbook:**

   ```bash
   ansible-playbook playbooks/k3s-secondary-nic.yaml --check --diff
   ```

   Review changes:
   - Creates `/etc/systemd/network/20-eth1.network`
   - Configures static IP on eth1
   - Adds route for 10.0.30.0/24

3. **Apply Ansible playbook:**

   ```bash
   ansible-playbook playbooks/k3s-secondary-nic.yaml
   ```

4. **Verify eth1 configuration:**

   ```bash
   ansible k3s_control_plane:k3s_workers -m command -a "ip addr show eth1"
   ```

   Expected: `inet 10.0.30.5X/24 scope global eth1`

5. **Test connectivity:**

   ```bash
   # From your Mac (VLAN 10)
   ping 10.0.30.50  # lab-ctrl
   ping 10.0.30.51  # horse01
   # ... test all nodes

   # From each node, ping VLAN 30 gateway
   ansible k3s_control_plane:k3s_workers -m command -a "ping -c 3 10.0.30.1"
   ```

### Phase 4: MetalLB Validation ⏸️

1. **Check MetalLB speaker logs:**

   ```bash
   kubectl logs -n metallb-system -l component=speaker --tail=50
   ```

   Look for: `interface eth1 has IP 10.0.30.5X`

2. **Test Traefik VIP reachability:**

   ```bash
   # From your Mac
   ping 10.0.30.10
   ```

   Expected: Replies from 10.0.30.10 (finally!)

3. **Test ArgoCD WebUI:**

   ```bash
   curl -I -k https://argocd.lab.m0sh1.cc/
   ```

   Expected: `HTTP/2 200`

4. **Browser test:**

   Open: <https://argocd.lab.m0sh1.cc/>

---

## Rollback Plan

If something goes wrong:

1. **Revert Terraform changes:**

   ```bash
   cd terraform/envs/lab
   git checkout vms.tf  # Revert to previous version
   terraform plan -out=rollback.tfplan
   terraform apply rollback.tfplan
   ```

2. **Reboot nodes to remove secondary NICs**

3. **Remove Ansible configuration:**

   ```bash
   ansible k3s_control_plane:k3s_workers -m file -a "path=/etc/systemd/network/20-eth1.network state=absent"
   ansible k3s_control_plane:k3s_workers -m systemd -a "name=systemd-networkd state=restarted"
   ```

---

## Success Criteria

- [ ] All K8s nodes have eth1 interface with correct VLAN 30 IP
- [ ] Routing table shows 10.0.30.0/24 via eth1
- [ ] Ping succeeds: Mac → 10.0.30.50-54 (K8s node secondary IPs)
- [ ] Ping succeeds: Mac → 10.0.30.10 (Traefik VIP)
- [ ] ArgoCD WebUI accessible at <https://argocd.lab.m0sh1.cc/>
- [ ] MetalLB speaker logs show eth1 interface detected

---

## Timeline Estimate

- Phase 1 (Review): 30 minutes
- Phase 2 (Terraform): 1 hour (includes node reboots)
- Phase 3 (Ansible): 30 minutes
- Phase 4 (Validation): 15 minutes
- **Total: ~2.5 hours**

---

## Questions Before Proceeding?

1. When is a good maintenance window for node reboots?
2. Any workloads that need special handling during drain/reboot?
3. Should we test on a single node first before rolling out to all?

---

**Ready to proceed?** Review all files, then we'll execute phase by phase with your approval at each step.
