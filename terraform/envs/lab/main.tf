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

  # Shared networking defaults
  bridge      = "vmbr0"
  lab_gateway = var.lab_gateway

  # Shared storage defaults
  proxmox_datastore = var.proxmox_datastore

  # Terraform-derived topology (kept as locals so vms.tf can stay clean)
  # Map keyed by Proxmox node name, e.g. { pve-01 = 9000, pve-02 = 9001 }
  debian_template_vmid = var.debian_template_vmid

  # List of Proxmox node names managed by this env (used for loops/validation)
  proxmox_nodes = var.proxmox_nodes

  # Shared DNS defaults
  dns_servers = ["10.0.0.10", "10.0.0.2"]
  dns_domain  = "m0sh1.cc"

  # Common tag sets
  common_tags = [local.env, "terraform"]
  vm_tags     = concat(local.common_tags, ["debian", "vm"])
  lxc_tags    = concat(local.common_tags, ["debian", "lxc"])

  keyboard_layout = var.keyboard_layout
  timezone        = var.timezone

}
