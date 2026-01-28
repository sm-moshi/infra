output "vm_id" {
  value = coalesce(
    try(proxmox_virtual_environment_vm.this_managed[0].vm_id, null),
    try(proxmox_virtual_environment_vm.this_ignore_efi[0].vm_id, null),
  )
}

output "name" {
  value = coalesce(
    try(proxmox_virtual_environment_vm.this_managed[0].name, null),
    try(proxmox_virtual_environment_vm.this_ignore_efi[0].name, null),
  )
}

output "node_name" {
  value = coalesce(
    try(proxmox_virtual_environment_vm.this_managed[0].node_name, null),
    try(proxmox_virtual_environment_vm.this_ignore_efi[0].node_name, null),
  )
}

output "tags" {
  value = coalesce(
    try(proxmox_virtual_environment_vm.this_managed[0].tags, null),
    try(proxmox_virtual_environment_vm.this_ignore_efi[0].tags, null),
  )
}
