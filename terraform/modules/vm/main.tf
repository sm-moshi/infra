terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this_managed" {
  count     = var.ignore_efi_disk_changes ? 0 : 1
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  tags      = var.tags
  on_boot   = var.on_boot
  started   = var.started

  dynamic "clone" {
    for_each = var.template_vmid != null ? [1] : []
    content {
      vm_id = var.template_vmid
      full  = true
    }
  }

  machine                              = "q35"
  bios                                 = "ovmf"
  delete_unreferenced_disks_on_destroy = false
  boot_order                           = ["scsi0", "ide2"]
  scsi_hardware                        = "virtio-scsi-single"

  agent {
    enabled = true
    trim    = true
  }

  rng {
    source = "/dev/urandom"
  }

  cpu {
    cores   = var.cores
    sockets = 1
    type    = var.cpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_min
  }

  dynamic "network_device" {
    for_each = length(var.network_devices) > 0 ? var.network_devices : (
      var.bridge != null ? [
        {
          bridge      = var.bridge
          model       = "virtio"
          mac_address = var.mac_address
          queues      = var.network_queues
          firewall    = false
          trunks      = null
          vlan_id     = null
        }
      ] : []
    )

    content {
      bridge      = network_device.value.bridge
      model       = network_device.value.model
      mac_address = try(network_device.value.mac_address, null)
      queues      = try(network_device.value.queues, null)
      firewall    = try(network_device.value.firewall, null)
      trunks      = try(network_device.value.trunks, null)
      vlan_id     = try(network_device.value.vlan_id, null)
    }
  }

  serial_device { device = "socket" }

  disk {
    interface    = "scsi0"
    size         = var.disk_size
    datastore_id = var.datastore_id
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  dynamic "disk" {
    for_each = var.data_disk_size != null ? [1] : []
    content {
      interface    = "scsi1"
      size         = var.data_disk_size
      datastore_id = coalesce(var.data_disk_datastore_id, var.datastore_id)
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  dynamic "efi_disk" {
    for_each = var.template_vmid == null ? [1] : []
    content {
      datastore_id      = var.datastore_id
      pre_enrolled_keys = true
      type              = var.efi_disk_type
    }
  }

  dynamic "cdrom" {
    for_each = var.cdrom_file_id != null ? [1] : []
    content { file_id = var.cdrom_file_id }
  }

  operating_system { type = "l26" }

  dynamic "initialization" {
    for_each = var.cloud_init_enabled ? [1] : []
    content {
      datastore_id = var.datastore_id

      ip_config {
        ipv4 {
          address = var.ipv4_address
          gateway = var.gateway
        }

        dynamic "ipv6" {
          for_each = var.ipv6_address != null ? [1] : []
          content {
            address = var.ipv6_address
            gateway = var.ipv6_gateway
          }
        }
      }

      user_account {
        username = var.cloud_init_user
        keys     = var.ssh_keys
      }
    }
  }

  lifecycle {
    ignore_changes = [
      boot_order,
      cpu[0].flags,
      memory[0].floating,
      operating_system,
      rng,

      # NOTE: if you want "ignore_network_changes" to work dynamically,
      # you must do the same split pattern for network too.
      network_device,
    ]
  }

  keyboard_layout = var.keyboard_layout
}

resource "proxmox_virtual_environment_vm" "this_ignore_efi" {
  count     = var.ignore_efi_disk_changes ? 1 : 0
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  tags      = var.tags
  on_boot   = var.on_boot
  started   = var.started

  dynamic "clone" {
    for_each = var.template_vmid != null ? [1] : []
    content {
      vm_id = var.template_vmid
      full  = true
    }
  }

  machine                              = "q35"
  bios                                 = "ovmf"
  delete_unreferenced_disks_on_destroy = false
  boot_order                           = ["scsi0", "ide2"]
  scsi_hardware                        = "virtio-scsi-single"

  agent {
    enabled = true
    trim    = true
  }

  rng {
    source = "/dev/urandom"
  }

  cpu {
    cores   = var.cores
    sockets = 1
    type    = var.cpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_min
  }

  dynamic "network_device" {
    for_each = length(var.network_devices) > 0 ? var.network_devices : (
      var.bridge != null ? [
        {
          bridge      = var.bridge
          model       = "virtio"
          mac_address = var.mac_address
          queues      = var.network_queues
          firewall    = false
          trunks      = null
          vlan_id     = null
        }
      ] : []
    )

    content {
      bridge      = network_device.value.bridge
      model       = network_device.value.model
      mac_address = try(network_device.value.mac_address, null)
      queues      = try(network_device.value.queues, null)
      firewall    = try(network_device.value.firewall, null)
      trunks      = try(network_device.value.trunks, null)
      vlan_id     = try(network_device.value.vlan_id, null)
    }
  }

  serial_device { device = "socket" }

  disk {
    interface    = "scsi0"
    size         = var.disk_size
    datastore_id = var.datastore_id
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  dynamic "disk" {
    for_each = var.data_disk_size != null ? [1] : []
    content {
      interface    = "scsi1"
      size         = var.data_disk_size
      datastore_id = coalesce(var.data_disk_datastore_id, var.datastore_id)
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  dynamic "cdrom" {
    for_each = var.cdrom_file_id != null ? [1] : []
    content { file_id = var.cdrom_file_id }
  }

  operating_system { type = "l26" }

  dynamic "efi_disk" {
    for_each = var.template_vmid != null ? [1] : []
    content {
      datastore_id      = var.datastore_id
      pre_enrolled_keys = true
    }
  }

  dynamic "efi_disk" {
    for_each = var.template_vmid == null ? [1] : []
    content {
      datastore_id      = var.datastore_id
      pre_enrolled_keys = true
      type              = var.efi_disk_type
    }
  }

  dynamic "initialization" {
    for_each = var.cloud_init_enabled ? [1] : []
    content {
      datastore_id = var.datastore_id

      ip_config {
        ipv4 {
          address = var.ipv4_address
          gateway = var.gateway
        }

        dynamic "ipv6" {
          for_each = var.ipv6_address != null ? [1] : []
          content {
            address = var.ipv6_address
            gateway = var.ipv6_gateway
          }
        }
      }

      user_account {
        username = var.cloud_init_user
        keys     = var.ssh_keys
      }
    }
  }

  lifecycle {
    ignore_changes = [
      boot_order,
      cpu[0].flags,
      memory[0].floating,
      operating_system,
      rng,
      network_device,

      # IGNORE ALL EFI
      efi_disk,
      network_interface_names
    ]
  }

  keyboard_layout = var.keyboard_layout
}
