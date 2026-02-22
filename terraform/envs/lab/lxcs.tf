/*
  LXC/container definitions for the lab environment.

  Infrastructure LXCs on VLAN 10 (10.0.10.0/24):
  - smb (pve-01): Samba file server

  Note: These are NEW deployments (clean slate rebuild).
  SSH keys will be injected during initial creation.
*/

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
  started      = true

  cores     = 2
  memory    = 512
  swap      = 256
  disk_size = 6
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  # eth0: Untagged on vmbr0 = WiFi subnet 10.0.0.0/24 (for scanning)
  ip      = "10.0.0.50/24"
  gateway = "10.0.0.1"
  vlan_id = 0

  bridge = local.bridges_by_node["pve-03"]

  # eth1: VLAN 10 (infra) for management + Scanopy server access
  # eth2: VLAN 20 (K8s nodes) for scanning
  # eth3: VLAN 30 (services/LB) for Scanopy server API
  extra_network_interfaces = [
    {
      name    = "eth1"
      bridge  = local.bridges_by_node["pve-03"]
      vlan_id = 10
      ip      = "10.0.10.50/24"
      gateway = ""
    },
    {
      name    = "eth2"
      bridge  = local.bridges_by_node["pve-03"]
      vlan_id = 20
      ip      = "10.0.20.50/24"
      gateway = ""
    },
    {
      name    = "eth3"
      bridge  = local.bridges_by_node["pve-03"]
      vlan_id = 30
      ip      = "10.0.30.50/24"
      gateway = ""
    }
  ]

  ssh_public_keys = var.public_ssh_keys

  # OPNsense DNS on VLAN 10 (reachable via eth1)
  dns_servers = ["10.0.10.1"]
  dns_domain  = local.dns_domain

  # TUN device needed for network scanning
  device_passthrough = [
    { path = "/dev/net/tun" }
  ]

  tags = ["debian", "scanopy", "daemon", "lxc", "terraform", "wifi"]

  mount_points = []
}
