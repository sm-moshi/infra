/*
  LXC/container definitions for the lab environment.

  Infrastructure LXCs on VLAN 10 (10.0.10.0/24):
  - dns01 (pve-02): AdGuard Home primary DNS
  - dns02 (pve-03): AdGuard Home secondary DNS
  - smb (pve-01): Samba file server

  Note: These are NEW deployments (clean slate rebuild).
  SSH keys will be injected during initial creation.
*/

module "dns01" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_02
  }

  hostname     = "dns01"
  vmid         = 100
  target_node  = "pve-02"
  unprivileged = false

  cores     = 1
  memory    = 1024
  swap      = 512
  disk_size = 8
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.21/24"
  gateway = local.gateway_vlan10
  vlan_id = local.vlan10

  bridge = local.bridges_by_node["pve-02"]

  ssh_public_keys = var.public_ssh_keys

  # Bootstrap with Cloudflare DNS until AdGuard Home is configured
  dns_servers = ["10.0.10.1", "1.1.1.1"]
  dns_domain  = local.dns_domain

  tags = ["debian", "dns", "adguard", "infra", "lxc", "terraform", "vlan10"]
}

module "dns02" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_03
  }

  hostname     = "dns02"
  vmid         = 101
  target_node  = "pve-03"
  unprivileged = false

  cores     = 1
  memory    = 1024
  swap      = 512
  disk_size = 8
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.22/24"
  gateway = local.gateway_vlan10
  vlan_id = local.vlan10

  bridge = local.bridges_by_node["pve-03"]

  ssh_public_keys = var.public_ssh_keys

  # Bootstrap with Cloudflare DNS until AdGuard Home is configured
  dns_servers = ["10.0.10.1", "1.0.0.1"]
  dns_domain  = local.dns_domain

  tags = ["debian", "dns", "adguard", "infra", "lxc", "terraform", "vlan10"]
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
  disk_size = 32
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.23/24"
  gateway = local.gateway_vlan10
  vlan_id = local.vlan10

  bridge = local.bridges_by_node["pve-01"]

  ssh_public_keys = var.public_ssh_keys

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "smb", "samba", "storage", "lxc", "terraform", "vlan10"]

  # Mount points will be configured via Ansible after deployment:
  # - /timemachine/tm-smb -> /srv/timemachine
  # - /datengrab/archive  -> /srv/archive
  # - /datengrab/media    -> /srv/media
  mount_points = []
}

module "apt" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_03
  }

  hostname     = "apt"
  vmid         = 105
  target_node  = "pve-03"
  unprivileged = true

  cores     = 1
  memory    = 512
  swap      = 256
  disk_size = 8
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.24/24"
  gateway = local.gateway_vlan10
  vlan_id = local.vlan10

  bridge = local.bridges_by_node["pve-03"]

  ssh_public_keys = var.public_ssh_keys

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "apt", "cache", "apt-cacher-ng", "infra", "lxc", "terraform", "vlan10"]

  # Apt-Cacher NG will be configured via Ansible after deployment:
  # - Port 3142 for package cache proxy
  # - Cache directory: /var/cache/apt-cacher-ng
  # - Configuration: /etc/apt-cacher-ng/acng.conf
  # See: https://www.unix-ag.uni-kl.de/~bloch/acng/html/index.html
  mount_points = []
}

# Scanopy daemon LXC on WiFi subnet (untagged, 10.0.0.0/24)
# Runs the standalone Scanopy daemon binary to discover WiFi devices
# that aren't reachable from K8s VLAN 20 nodes.
# eth0: WiFi (10.0.0.50) for scanning, eth1: VLAN 10 (10.0.10.50) for Scanopy server access
# Configured via Ansible role: scanopy_daemon
module "scanopy_daemon" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_03
  }

  hostname     = "scanopy-daemon"
  vmid         = 106
  target_node  = "pve-03"
  unprivileged = true

  cores     = 1
  memory    = 512
  swap      = 256
  disk_size = 4
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  # eth0: Untagged on vmbr0 = WiFi subnet 10.0.0.0/24 (for scanning)
  ip      = "10.0.0.50/24"
  gateway = "10.0.0.1"
  vlan_id = 0

  bridge = local.bridges_by_node["pve-03"]

  # eth1: VLAN 10 (infra) for routing to Scanopy server via VLAN 30
  extra_network_interfaces = [
    {
      name    = "eth1"
      bridge  = local.bridges_by_node["pve-03"]
      vlan_id = 10
      ip      = "10.0.10.50/24"
      gateway = ""
    }
  ]

  ssh_public_keys = var.public_ssh_keys

  # OPNsense DNS on VLAN 10 (reachable via eth1)
  dns_servers = ["10.0.10.1"]
  dns_domain  = local.dns_domain

  tags = ["debian", "scanopy", "daemon", "lxc", "terraform", "wifi"]

  mount_points = []
}
