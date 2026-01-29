output "proxmox_nodes" {
  value = keys(var.proxmox_endpoint)
}

output "debian_template_vmid" {
  value = var.debian_template_vmid
}

output "fedora_template_vmid" {
  value = var.fedora_template_vmid
}

output "proxmox_datastore" {
  value = var.proxmox_datastore
}
