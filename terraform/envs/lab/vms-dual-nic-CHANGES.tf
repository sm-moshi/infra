# =============================================================================
# K8s Node Dual-NIC Configuration Changes
# =============================================================================
#
# This file contains the required changes to add secondary NICs to all K8s
# VMs for MetalLB L2Advertisement support on VLAN 30.
#
# INSTRUCTIONS:
# 1. Review these changes
# 2. Apply the network_devices changes to vms.tf for each K8s node
# 3. Run: terraform plan -out=tfplan
# 4. Review the plan carefully (should show network device additions)
# 5. Apply: terraform apply tfplan
#
# NOTE: Applying these changes will trigger VM reconfigurations.
# Coordinate with cluster operations to minimize disruption.
# =============================================================================

# -----------------------------------------------------------------------------
# Control Plane (lab-ctrl)
# -----------------------------------------------------------------------------
# CURRENT network_devices in vms.tf:
#   network_devices = [
#     {
#       bridge      = local.bridges_by_node["pve-01"]
#       mac_address = "BC:24:11:4A:9D:06"
#       queues      = 6
#       firewall    = false
#       vlan_id     = local.vlan20
#     }
#   ]
#
# REPLACE WITH:
module "lab_ctrl" {
  # ... existing configuration ...

  network_devices = [
    # Primary NIC (eth0) - VLAN 20: Pod network, cluster communication
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:4A:9D:06"
      queues      = 6
      firewall    = false
      vlan_id     = local.vlan20
    },
    # Secondary NIC (eth1) - VLAN 30: MetalLB L2Advertisement
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:4A:9D:30" # New MAC for eth1
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan30
    }
  ]

  # Cloud-init will only configure eth0 (primary)
  # eth1 will be configured via Ansible playbook
  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.20/24"
}

# -----------------------------------------------------------------------------
# Worker 1 (horse-01)
# -----------------------------------------------------------------------------
# CURRENT network_devices in vms.tf:
#   network_devices = [
#     {
#       bridge      = local.bridges_by_node["pve-01"]
#       mac_address = "BC:24:11:F8:5B:85"
#       queues      = 4
#       firewall    = false
#       vlan_id     = local.vlan20
#     }
#   ]
#
# REPLACE WITH:
module "horse_01" {
  # ... existing configuration ...

  network_devices = [
    # Primary NIC (eth0) - VLAN 20
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:F8:5B:85"
      queues      = 4
      firewall    = false
      vlan_id     = local.vlan20
    },
    # Secondary NIC (eth1) - VLAN 30
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:F8:5B:30" # New MAC for eth1
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan30
    }
  ]

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.21/24"
}

# -----------------------------------------------------------------------------
# Worker 2 (horse-02)
# -----------------------------------------------------------------------------
# CURRENT network_devices in vms.tf:
#   network_devices = [{
#     bridge      = local.bridges_by_node["pve-02"]
#     mac_address = "BC:24:11:03:7A:58"
#     queues      = 4
#     firewall    = false
#     vlan_id     = local.vlan20
#   }]
#
# REPLACE WITH:
module "horse_02" {
  # ... existing configuration ...

  network_devices = [
    # Primary NIC (eth0) - VLAN 20
    {
      bridge      = local.bridges_by_node["pve-02"]
      mac_address = "BC:24:11:03:7A:58"
      queues      = 4
      firewall    = false
      vlan_id     = local.vlan20
    },
    # Secondary NIC (eth1) - VLAN 30
    {
      bridge      = local.bridges_by_node["pve-02"]
      mac_address = "BC:24:11:03:7A:30" # New MAC for eth1
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan30
    }
  ]

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.22/24"
}

# -----------------------------------------------------------------------------
# Worker 3 (horse-03)
# -----------------------------------------------------------------------------
# CURRENT network_devices in vms.tf:
#   network_devices = [{
#     bridge      = local.bridges_by_node["pve-03"]
#     mac_address = "BC:24:11:D2:8E:7A"
#     queues      = 4
#     firewall    = false
#     vlan_id     = local.vlan20
#   }]
#
# REPLACE WITH:
module "horse_03" {
  # ... existing configuration ...

  network_devices = [
    # Primary NIC (eth0) - VLAN 20
    {
      bridge      = local.bridges_by_node["pve-03"]
      mac_address = "BC:24:11:D2:8E:7A"
      queues      = 4
      firewall    = false
      vlan_id     = local.vlan20
    },
    # Secondary NIC (eth1) - VLAN 30
    {
      bridge      = local.bridges_by_node["pve-03"]
      mac_address = "BC:24:11:D2:8E:30" # New MAC for eth1
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan30
    }
  ]

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.23/24"
}

# -----------------------------------------------------------------------------
# Worker 4 (horse-04)
# -----------------------------------------------------------------------------
# CURRENT network_devices in vms.tf:
#   network_devices = [{
#     bridge      = local.bridges_by_node["pve-02"]
#     mac_address = "BC:24:11:A8:C3:F2"
#     queues      = 2
#     firewall    = false
#     vlan_id     = local.vlan20
#   }]
#
# REPLACE WITH:
module "horse_04" {
  # ... existing configuration ...

  network_devices = [
    # Primary NIC (eth0) - VLAN 20
    {
      bridge      = local.bridges_by_node["pve-02"]
      mac_address = "BC:24:11:A8:C3:F2"
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan20
    },
    # Secondary NIC (eth1) - VLAN 30
    {
      bridge      = local.bridges_by_node["pve-02"]
      mac_address = "BC:24:11:A8:C3:30" # New MAC for eth1
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan30
    }
  ]

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.24/24"
}

# =============================================================================
# VALIDATION STEPS AFTER TERRAFORM APPLY
# =============================================================================
#
# 1. Verify NICs added in Proxmox:
#    qm config 201 | grep net    # lab-ctrl
#    qm config 210 | grep net    # horse-01
#    qm config 211 | grep net    # horse-02
#    qm config 212 | grep net    # horse-03
#    qm config 213 | grep net    # horse-04
#
# 2. Expected output for each VM:
#    net0: virtio=...,bridge=vmbr0,firewall=0,tag=20
#    net1: virtio=...,bridge=vmbr0,firewall=0,tag=30
#
# 3. Proceed to Ansible configuration (see ansible playbook changes)
#
# =============================================================================
