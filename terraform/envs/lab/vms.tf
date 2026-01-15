/*
  VM definitions for the lab environment.

  Currently contains the three k3s-related VMs:
    - lab_ctrl  (control-plane)
    - horse_01  (worker)
    - horse_02  (worker)
    - horse_03  (worker)
    - builder_01 (image builder for native amd64 builds)

  This is a straight migration from ../vms-lab.tf without behaviour changes.
  Later, these resources will be refactored into modules/vm with shared defaults.
*/

# Control Plane VM
module "lab_ctrl" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "lab-ctrl"
  vm_id     = 201
  node_name = "pve-02"

  tags = ["terraform", "debian", "k3s-control-plane", "vm"]

  cores      = 6
  memory     = 5120
  memory_min = 4096

  bridge         = local.bridge
  mac_address    = "BC:24:11:4A:9D:06"
  network_queues = 6

  disk_size    = 60
  datastore_id = local.proxmox_datastore

  gateway      = local.lab_gateway
  ipv4_address = "10.0.0.201/24"
  ipv6_address = "fd8d:a82b:a42f:1::201/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  ssh_keys = var.public_ssh_keys
}

module "horse_01" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "horse-01"
  vm_id     = 210
  node_name = "pve-01"

  tags = ["terraform", "debian", "k3s-worker", "vm"]

  cores      = 6
  memory     = 10240
  memory_min = 8192

  bridge         = local.bridge
  mac_address    = "BC:24:11:F8:5B:85"
  network_queues = 4

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.lab_gateway
  ipv4_address = "10.0.0.210/24"
  ipv6_address = "fd8d:a82b:a42f:1::210/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  ssh_keys = var.public_ssh_keys
}

module "horse_02" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "horse-02"
  vm_id     = 211
  node_name = "pve-02"

  tags = ["terraform", "debian", "k3s-worker", "vm"]

  cores      = 6
  memory     = 6144
  memory_min = 4096

  bridge         = local.bridge
  mac_address    = "BC:24:11:03:7A:58"
  network_queues = 6

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.lab_gateway
  ipv4_address = "10.0.0.211/24"
  ipv6_address = "fd8d:a82b:a42f:1::211/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  ssh_keys = var.public_ssh_keys
}

module "horse_03" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "horse-03"
  vm_id     = 212
  node_name = "pve-01"

  template_vmid = local.debian_template_vmid["pve-01"]

  tags = ["terraform", "debian", "k3s-worker", "vm"]

  cores      = 8
  memory     = 10240
  memory_min = 8192

  bridge         = local.bridge
  mac_address    = "BC:24:11:7D:4F:39"
  network_queues = 4

  disk_size    = 60
  datastore_id = local.proxmox_datastore

  gateway      = local.lab_gateway
  ipv4_address = "10.0.0.212/24"
  ipv6_address = "fd8d:a82b:a42f:1::212/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  ssh_keys = var.public_ssh_keys
}

# Image builder VM (native amd64 builds for multi-arch container images)
module "builder_01" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name = "builder-01"

  template_vmid = local.debian_template_vmid["pve-01"]

  vm_id     = 220
  node_name = "pve-01"
  on_boot   = false
  started   = false

  tags = ["terraform", "debian", "builder", "docker", "vm"]

  # Sane defaults for Node/Vite builds (adjust if you see memory pressure)
  cores      = 4
  memory     = 8192
  memory_min = 6144

  bridge         = local.bridge
  network_queues = 4

  disk_size    = 80
  datastore_id = local.proxmox_datastore

  data_disk_size = 200

  gateway = local.lab_gateway

  ipv4_address = "10.0.0.220/24"
  ipv6_address = "fd8d:a82b:a42f:1::220/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  cloud_init_user = "root"
  ssh_keys        = var.public_ssh_keys
}

# Proxmox Datacenter Manager VM
module "pdm_01" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "pdm-01"
  vm_id     = 230
  node_name = "pve-01"
  on_boot   = false
  started   = false

  tags = concat(local.common_tags, ["pdm", "vm"])

  cores  = 2
  memory = 4096

  bridge = local.bridge

  ipv4_address = "10.0.0.230/24"
  ipv6_address = "fd8d:a82b:a42f:1::230/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"


  disk_size    = 60
  datastore_id = local.proxmox_datastore

  cdrom_file_id      = data.proxmox_virtual_environment_file.pdm_iso.id
  cloud_init_enabled = false

  keyboard_layout = local.keyboard_layout
}
