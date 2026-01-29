# Terraform VLAN Infrastructure Rebuild

**Status:** Implementation Guide
**Created:** 2026-01-22
**Purpose:** Complete Terraform configuration for 4-VLAN network architecture

## Network Architecture

```text
10.0.0.0/24   - VLAN 1/untagged: Speedport WiFi clients
10.0.10.0/24  - VLAN 10: Infrastructure (PVE, PBS, DNS, OPNsense LAN)
10.0.20.0/24  - VLAN 20: Kubernetes nodes (control plane + workers)
10.0.30.0/24  - VLAN 30: Services/Ingress (MetalLB, Traefik)
```

## Infrastructure Assignments

### OPNsense Firewall

- **Node:** pve-01
- **VMID:** 300
- **WAN:** USB NIC passthrough → Speedport (DHCP on 10.0.0.x)
- **LAN:** vmbr0 VLAN 10 → 10.0.10.1/24 (gateway for VLANs 10/20/30)
- **Resources:** 4 cores, 8GB RAM, 40GB disk

### Kubernetes Cluster (VLAN 20)

```text
labctrl  → pve-01, VMID 201, 10.0.20.20/24 (control plane)
horse01  → pve-01, VMID 210, 10.0.20.21/24 (worker)
horse02  → pve-02, VMID 211, 10.0.20.22/24 (worker)
horse03  → pve-03, VMID 212, 10.0.20.23/24 (worker)
horse04  → pve-02, VMID 213, 10.0.20.24/24 (worker)
```

### Infrastructure LXCs (VLAN 10)

```text
dns01 → pve-02, VMID 100, 10.0.10.21/24 (AdGuard Home primary)
dns02 → pve-03, VMID 101, 10.0.10.22/24 (AdGuard Home secondary)
pbs   → pve-02, VMID 120, 10.0.10.14/24 (Proxmox Backup Server)
smb   → pve-01, VMID 110, 10.0.10.110/24 (Samba file server)
```

## Implementation Steps

### 1. Completed ✅

- [x] Added pve-03 provider to providers.tf
- [x] Added pve-03 API token variable
- [x] Updated proxmox_nodes list to include pve-03
- [x] Fixed Ansible inventory pve-03 IP (10.0.0.13)
- [x] Updated main.tf locals for VLAN gateways
- [x] Added OPNsense ISO download to templates.tf
- [x] Removed PDM references from templates.tf
- [x] Added Debian 13 LXC template for pve-03

### 2. Remaining Tasks

#### lxcs.tf Update

Replace entire file with:

```terraform
/*
  LXC/container definitions for the lab environment.

  Infrastructure LXCs on VLAN 10 (10.0.10.0/24):
  - dns01 (pve-02): AdGuard Home primary
  - dns02 (pve-03): AdGuard Home secondary
  - pbs (pve-02): Proxmox Backup Server
  - smb (pve-01): Samba file server
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

  cores     = 2
  memory    = 2048
  swap      = 512
  disk_size = 16
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.10/24"
  gateway = local.gateway_vlan10

  ipv6_address = "fd8d:a82b:a42f:a::10/64"
  ipv6_gateway = "fd8d:a82b:a42f:a::1"

  bridge = local.bridge

  ssh_public_keys = var.public_ssh_keys

  dns_servers = ["1.1.1.1", "1.0.0.1"]  # Cloudflare for bootstrap
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

  cores     = 2
  memory    = 2048
  swap      = 512
  disk_size = 16
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.11/24"
  gateway = local.gateway_vlan10

  ipv6_address = "fd8d:a82b:a42f:a::11/64"
  ipv6_gateway = "fd8d:a82b:a42f:a::1"

  bridge = local.bridge

  ssh_public_keys = var.public_ssh_keys

  dns_servers = ["1.1.1.1", "1.0.0.1"]  # Cloudflare for bootstrap
  dns_domain  = local.dns_domain

  tags = ["debian", "dns", "adguard", "infra", "lxc", "terraform", "vlan10"]
}

module "pbs" {
  source = "../../modules/lxc"

  providers = {
    proxmox = proxmox.pve_02
  }

  hostname     = "pbs"
  vmid         = 120
  target_node  = "pve-02"
  unprivileged = false

  cores     = 4
  memory    = 4096
  swap      = 1024
  disk_size = 32
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.20/24"
  gateway = local.gateway_vlan10

  ipv6_address = "fd8d:a82b:a42f:a::20/64"
  ipv6_gateway = "fd8d:a82b:a42f:a::1"

  bridge = local.bridge

  ssh_public_keys = var.public_ssh_keys

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "backup", "pbs", "infra", "lxc", "terraform", "vlan10"]
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
  memory    = 4096
  swap      = 512
  disk_size = 32
  storage   = local.proxmox_datastore

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  ip      = "10.0.10.110/24"
  gateway = local.gateway_vlan10

  ipv6_address = "fd8d:a82b:a42f:a::110/64"
  ipv6_gateway = "fd8d:a82b:a42f:a::1"

  bridge = local.bridge

  ssh_public_keys = var.public_ssh_keys

  dns_servers = local.dns_servers
  dns_domain  = local.dns_domain

  tags = ["debian", "smb", "samba", "storage", "lxc", "terraform", "vlan10"]
}
```

#### vms.tf Update

Update K3s node IPs for VLAN 20 and remove pdm_01/builder_01:

```terraform
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
  memory     = 5120
  memory_min = 4096

  bridge         = local.bridge
  mac_address    = "BC:24:11:4A:9D:06"
  network_queues = 6

  disk_size    = 60
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.201/24"
  ipv6_address = "fd8d:a82b:a42f:14::201/64"
  ipv6_gateway = "fd8d:a82b:a42f:14::1"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-01"]
}

# Worker Node 1
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

  bridge         = local.bridge
  mac_address    = "BC:24:11:F8:5B:85"
  network_queues = 4

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.210/24"
  ipv6_address = "fd8d:a82b:a42f:14::210/64"
  ipv6_gateway = "fd8d:a82b:a42f:14::1"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-01"]
}

# Worker Node 2
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

  bridge         = local.bridge
  mac_address    = "BC:24:11:03:7A:58"
  network_queues = 6

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.211/24"
  ipv6_address = "fd8d:a82b:a42f:14::211/64"
  ipv6_gateway = "fd8d:a82b:a42f:14::1"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-02"]
}

# Worker Node 3
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
  memory     = 4096
  memory_min = 3072

  bridge         = local.bridge
  mac_address    = "BC:24:11:D2:8E:7A"
  network_queues = 4

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.212/24"
  ipv6_address = "fd8d:a82b:a42f:14::212/64"
  ipv6_gateway = "fd8d:a82b:a42f:14::1"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-03"]
}

# Worker Node 4
module "horse_04" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_02
  }

  name      = "horse-04"
  vm_id     = 213
  node_name = "pve-02"

  tags = ["terraform", "debian", "k3s-worker", "vm", "vlan20"]

  cores      = 2
  memory     = 3072
  memory_min = 2048

  bridge         = local.bridge
  mac_address    = "BC:24:11:A8:C3:F2"
  network_queues = 2

  disk_size    = 50
  datastore_id = local.proxmox_datastore

  gateway      = local.gateway_vlan20
  ipv4_address = "10.0.20.213/24"
  ipv6_address = "fd8d:a82b:a42f:14::213/64"
  ipv6_gateway = "fd8d:a82b:a42f:14::1"

  ssh_keys = var.public_ssh_keys

  template_vmid = local.debian_template_vmid["pve-02"]
}

# OPNsense Firewall VM
# NOTE: OPNsense uses manual installation from ISO, not cloud-init template
# This VM definition is for resource allocation only; OS installed via ISO boot
module "opnsense" {
  source = "../../modules/vm"

  providers = {
    proxmox = proxmox.pve_01
  }

  name      = "opnsense"
  vm_id     = 300
  node_name = "pve-01"

  tags = ["terraform", "opnsense", "firewall", "vm", "vlan10"]

  cores      = 4
  memory     = 8192
  memory_min = 6144

  # OPNsense has TWO network interfaces:
  # nic0 (vmbr0): LAN interface on VLAN 10 (10.0.10.1/24)
  # nic1 (USB passthrough or separate bridge): WAN interface to Speedport
  bridge         = local.bridge  # This is LAN interface
  mac_address    = "BC:24:11:FW:01:00"
  network_queues = 4

  disk_size    = 40
  datastore_id = local.proxmox_datastore

  # OPNsense installed from ISO (not cloud-init)
  template_vmid = null

  # Static IP configured during OPNsense installation wizard
  # gateway/ipv4_address will be ignored since template_vmid is null
  gateway      = null
  ipv4_address = null
  ipv6_address = null
  ipv6_gateway = null

  ssh_keys = []

  # Set on_boot and started to false initially (install from ISO first)
  on_boot = false
  started = false
}
```

### 3. Validation

```bash
# Navigate to lab environment
cd terraform/envs/lab

# Source secrets
source ../../op.env

# Initialize (download providers if needed)
terraform init

# Validate syntax
terraform validate

# Plan (see what will be created)
terraform plan

# Apply (create infrastructure)
terraform apply
```

### 4. Post-Deployment

**OPNsense Setup:**

1. Boot VM from OPNsense ISO
2. Install to disk (40GB virtual disk)
3. Configure WAN interface (DHCP from Speedport)
4. Configure LAN interface (10.0.10.1/24)
5. Create VLANs 20 and 30 on LAN interface
6. Set up firewall rules between VLANs
7. Configure DHCP servers for each VLAN (optional)

**DNS LXCs:**

1. Deploy via Ansible: `ansible-playbook -i inventory/hosts.ini playbooks/adguard.yaml`
2. Configure AdGuard Home via web UI (dns01: 10.0.10.10, dns02: 10.0.10.11)
3. Set upstream DNS servers (Cloudflare, Quad9)
4. Configure DNS rewrites for *.m0sh1.cc → cluster IPs

**K3s Cluster:**

1. Deploy control plane: `ansible-playbook -i inventory/hosts.ini playbooks/k3s-control-plane.yaml`
2. Deploy workers: `ansible-playbook -i inventory/hosts.ini playbooks/k3s-workers.yaml`
3. Verify: `kubectl get nodes -o wide`

## References

- Network diagram: [docs/intent-map.md](intent-map.md)
- Memory Bank: Project context and decisions
