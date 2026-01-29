/*
  Lab environment root module.

  Run Terraform with:

    terraform -chdir=envs/lab init
    terraform -chdir=envs/lab plan
    terraform -chdir=envs/lab apply

  VM definitions live in vms.tf
  LXC/container definitions live in lxcs.tf
*/

locals {
  # Environment identifier
  env = "lab"

  # VLAN Network Design
  # VLAN 1/untagged: 10.0.0.0/24  - Speedport WiFi clients
  # VLAN 10:         10.0.10.0/24 - Infrastructure (PVE, PBS, DNS, OPNsense LAN)
  # VLAN 20:         10.0.20.0/24 - Kubernetes nodes
  # VLAN 30:         10.0.30.0/24 - Services/Ingress (MetalLB, Traefik)

  # Shared networking defaults
  bridges_by_node = {
    "pve-01" = "vmbr0"
    "pve-02" = "vmbr0"
    "pve-03" = "vmbr0"
  }
  bridge = "vmbr0"
  vlan10 = 10
  vlan20 = 20
  vlan30 = 30

  # VLAN gateways (managed by OPNsense)
  gateway_vlan10 = "10.0.10.1" # Infrastructure gateway
  gateway_vlan20 = "10.0.20.1" # K8s nodes gateway
  gateway_vlan30 = "10.0.30.1" # Services gateway

  # Shared storage defaults
  proxmox_datastore = var.proxmox_datastore

  # Terraform-derived topology (kept as locals so vms.tf can stay clean)
  debian_template_vmid = var.debian_template_vmid
  fedora_template_vmid = var.fedora_template_vmid

  # List of Proxmox node names managed by this env (used for loops/validation)
  proxmox_nodes = var.proxmox_nodes

  # Shared DNS defaults (OPNsense Unbound on VLAN 10 gateway)
  dns_servers = ["10.0.10.1"]
  dns_domain  = "m0sh1.cc"

  # Common tag sets
  common_tags = [local.env, "terraform"]
  vm_tags     = concat(local.common_tags, ["debian", "vm"])
  lxc_tags    = concat(local.common_tags, ["debian", "lxc"])

  keyboard_layout = var.keyboard_layout
  timezone        = var.timezone
}
