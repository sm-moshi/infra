/*
  LXC/container definitions for the lab environment.

  Currently contains the dns02 LXC definition migrated from ../main.tf
  without behaviour changes.

  Later:
    - Add dns01, SMB, and other infra LXCs using modules/lxc.
    - Normalize tags and shared defaults via locals.
*/

module "dns02" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_02
  }

  hostname     = "dns02"
  vmid         = 101
  target_node  = "pve-02"
  unprivileged = false

  cores     = 2
  memory    = 512
  swap      = 512
  disk_size = 8
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.0.11/24"
  gateway = local.lab_gateway

  ipv6_address = "fd8d:a82b:a42f:1::11/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  bridge = local.bridge

  # Container already exists; avoid injecting keys to prevent replacement
  ssh_public_keys = []

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "dns", "infra", "lxc", "terraform"]
}

module "dns01" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_01
  }

  hostname     = "dns01"
  vmid         = 100
  target_node  = "pve-01"
  unprivileged = true

  cores     = 2
  memory    = 1024
  swap      = 512
  disk_size = 8
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.0.10/24"
  gateway = local.lab_gateway

  ipv6_address = "fd8d:a82b:a42f:1::10/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  bridge = local.bridge

  # Container already exists; avoid injecting keys to prevent replacement
  ssh_public_keys = []

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "dns", "infra", "lxc", "terraform"]
}

module "smb" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_01
  }

  hostname     = "smb"
  vmid         = 110
  target_node  = "pve-01"
  unprivileged = false

  cores     = 2
  memory    = 2048
  swap      = 512
  disk_size = 24
  storage   = "nvmestore"

  # Template matches other LXCs (Debian 13). Template ID is ignored on drift.
  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  # Live config uses DHCP for v4/v6; keep static blank to avoid replacement.
  ip      = "10.0.0.110/24"
  gateway = local.lab_gateway

  ipv6_address = "fd8d:a82b:a42f:1::110/64"
  ipv6_gateway = "fd8d:a82b:a42f:1::1"

  bridge = local.bridge

  # Existing container already has users; avoid forcing key injection.
  ssh_public_keys = []

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  # Match live tags
  tags = ["debian", "infra", "lxc", "smb", "terraform"]

  # Document live mount points for reference (ignored via lifecycle in module):
  # mp0: /timemachine/tm-smb -> /srv/timemachine (noatime, replicate=0)
  # mp1: /datengrab/archive   -> /srv/archive    (noatime, replicate=0)
  # mp2: /datengrab/media     -> /srv/media      (noatime, replicate=0)

  mount_points = [
    {
      volume        = "/timemachine/tm-smb"
      path          = "/srv/timemachine"
      mount_options = ["noatime", "discard"]
      replicate     = false
      # },
      # {
      #   volume        = "/datengrab/archive"
      #   path          = "/srv/archive"
      #   mount_options = ["noatime", "discard"]
      #   replicate     = false
      # },
      # {
      #   volume        = "/datengrab/media"
      #   path          = "/srv/media"
      #   mount_options = ["noatime", "discard"]
      #   replicate     = false
    }
  ]
}
