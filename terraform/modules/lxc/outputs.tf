output "vmid" {
  description = "VMID of the created container."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "name" {
  description = "Name/hostname of the container."
  value       = proxmox_virtual_environment_container.this.initialization[0].hostname
}

output "node_name" {
  description = "Proxmox node name where the container is running."
  value       = proxmox_virtual_environment_container.this.node_name
}
