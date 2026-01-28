/*
  VM definitions for the lab environment.

  Kubernetes cluster VMs on VLAN 20 (10.0.20.0/24):
    - lab_ctrl  (control-plane, pve-01)
    - horse_01  (worker, pve-01)
    - horse_02  (worker, pve-02)
    - horse_03  (worker, pve-03)
    - horse_04  (worker, pve-02)

  Network infrastructure VMs on VLAN 10 (10.0.10.0/24):
    - opnsense (firewall/gateway, pve-01)
    - bastion  (jump host, pve-02, 10.0.10.15)
    - pbs      (Proxmox Backup Server, pve-01)
*/

# Bastion VM (Infrastructure jump host - VLAN 10)
module "bastion" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "bastion"
  vm_id     = 250
  node_name = "pve-02"

  tags = ["terraform", "fedora", "bastion", "vm", "vlan10"]

  cores      = 2
  memory     = 6144
  memory_min = 4096

  # NIC on VLAN10 (tagged on vmbr0 trunk)
  network_devices = [
    {
      bridge      = local.bridges_by_node["pve-02"]
      mac_address = "BC:24:11:BA:51:00"
      queues      = 2
      firewall    = false
      vlan_id     = local.vlan10
    }
  ]

  disk_size    = 64
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan10
  ipv4_address = "10.0.10.15/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.fedora_template_vmid["pve-02"]
}

# Proxmox Backup Server VM (VLAN 10)
module "pbs" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "pbs"
  vm_id     = 120
  node_name = "pve-01"
  started   = false
  on_boot   = true

  tags = ["terraform", "pbs", "backup", "infra", "vm", "vlan10"]

  cores      = 4
  memory     = 8192
  memory_min = 6144

  network_devices = [
    {
      bridge   = local.bridges_by_node["pve-01"]
      queues   = 4
      firewall = false
      vlan_id  = local.vlan10
    }
  ]

  disk_size    = 32
  datastore_id = local.proxmox_datastore

  # ISO attach (matches templates.tf download location)
  cdrom_file_id = "${local.pbs_iso_datastore}:iso/${local.pbs_iso_filename}"

  template_vmid      = null
  cloud_init_enabled = false

  gateway      = local.gateway_vlan10
  ipv4_address = "10.0.10.14/24"

  ssh_keys = []
}

# Control Plane VM
module "lab_ctrl" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "lab-ctrl"
  vm_id     = 201
  node_name = "pve-01"

  tags = ["terraform", "debian", "k3s-control-plane", "vm", "vlan20"]

  cores      = 6
  memory     = 6144
  memory_min = 4096

  network_devices = [
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:4A:9D:06"
      queues      = 6
      firewall    = false
      vlan_id     = local.vlan20
    }
  ]

  disk_size    = 60
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.20/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-01"]
}

module "horse_01" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "horse-01"
  vm_id     = 210
  node_name = "pve-01"

  tags = ["terraform", "debian", "k3s-worker", "vm", "vlan20"]

  cores      = 6
  memory     = 10240
  memory_min = 8192

  network_devices = [
    {
      bridge      = local.bridges_by_node["pve-01"]
      mac_address = "BC:24:11:F8:5B:85"
      queues      = 4
      firewall    = false
      vlan_id     = local.vlan20
    }
  ]

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.21/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-01"]
}

module "horse_02" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "horse-02"
  vm_id     = 211
  node_name = "pve-02"

  tags = ["terraform", "debian", "k3s-worker", "vm", "vlan20"]

  cores      = 6
  memory     = 6144
  memory_min = 4096

  network_devices = [{
    bridge      = local.bridges_by_node["pve-02"]
    mac_address = "BC:24:11:03:7A:58"
    queues      = 4
    firewall    = false
    vlan_id     = local.vlan20
  }]

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.22/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-02"]
}

module "horse_03" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_03
  }

  name      = "horse-03"
  vm_id     = 212
  node_name = "pve-03"

  tags = ["terraform", "debian", "k3s-worker", "vm", "vlan20"]

  cores      = 4
  memory     = 6144
  memory_min = 4096

  network_devices = [{
    bridge      = local.bridges_by_node["pve-03"]
    mac_address = "BC:24:11:D2:8E:7A"
    queues      = 4
    firewall    = false
    vlan_id     = local.vlan20
  }]

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.23/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-03"]
}

module "horse_04" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "horse-04"
  vm_id     = 213
  node_name = "pve-02"

  tags = ["terraform", "debian", "k3s-worker", "vm", "vlan20"]

  cores      = 4
  memory     = 6144
  memory_min = 4096

  network_devices = [{
    bridge      = local.bridges_by_node["pve-02"]
    mac_address = "BC:24:11:A8:C3:F2"
    queues      = 2
    firewall    = false
    vlan_id     = local.vlan20
  }]

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.24/24"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-02"]
}

# OPNsense Firewall VM
# NOTE: OPNsense is already installed and configured manually.
# This Terraform configuration adopts the existing VM (VMID 300) to track its lifecycle.
#
# Current network configuration (managed manually via Proxmox):
#   - net0: WAN on vmbrWAN (MAC: BC:24:11:3D:33:2A) - DHCP from Speedport
#   - net2: LAN trunk on vmbr0 (MAC: BC:24:11:73:DE:1F) - VLAN 10/20/30 trunk
#
# OPNsense VLAN configuration:
#   - VLAN 10 (Infrastructure): 10.0.10.1/24 gateway
#   - VLAN 20 (K8s nodes): 10.0.20.1/24 gateway
#   - VLAN 30 (Services/Ingress): 10.0.30.1/24 gateway
#
# IMPORTANT: Network interfaces are NOT managed by Terraform to prevent drift.
# The vm module creates one network_device, but OPNsense has 2 manually configured NICs.
# To modify network config, use: qm set 300 -netX virtio=...,bridge=...,trunks=...
module "opnsense" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "opnsense"
  vm_id     = 300
  node_name = "pve-01"

  on_boot = true
  started = true

  tags = ["terraform", "opnsense", "firewall", "vm", "vlan10", "vlan20", "vlan30"]

  cores      = 4
  memory     = 8192
  memory_min = null # matches qm: balloon: 0 (no ballooning)

  # Multi-NIC (matches qm config)
  network_devices = [
    # net0 (WAN)
    {
      bridge      = "vmbrWAN"
      mac_address = "BC:24:11:3D:33:2A"
      queues      = 4
      firewall    = false
    },
    # net2 (LAN trunk: VLAN 10 / 20 / 30 tagged on vmbr0)
    {
      bridge      = "vmbr0"
      mac_address = "BC:24:11:73:DE:1F"
      queues      = 4
      firewall    = false
      trunks      = "10,20,30"
    },
  ]

  disk_size    = 40
  datastore_id = local.proxmox_datastore

  template_vmid      = null
  cloud_init_enabled = false

  # Keep Terraform from trying to “fix” NIC ordering/shape on an adopted VM.
  # Once you're fully happy, you can set this to false and re-apply carefully.
  ignore_network_changes = true

  # OPNsense: keep EFI stable
  ignore_efi_disk_changes = true

  # Not used when cloud_init_enabled = false, but keep explicit
  gateway      = null
  ipv4_address = null
  ipv6_address = null
  ipv6_gateway = null
  ssh_keys     = []

  cdrom_file_id = null
}
