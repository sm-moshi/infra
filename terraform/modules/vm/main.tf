terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
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

  scsi_hardware = "virtio-scsi-single"

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

  network_device {
    bridge      = var.bridge
    model       = "virtio"
    mac_address = var.mac_address
    queues      = var.network_queues
  }

  serial_device {
    device = "socket"
  }

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

  efi_disk {
    datastore_id      = var.datastore_id
    type              = "4m"
    pre_enrolled_keys = true
  }

  dynamic "cdrom" {
    for_each = var.cdrom_file_id != null ? [1] : []

    content {
      file_id = var.cdrom_file_id
    }
  }

  operating_system {
    type = "l26"
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
      # Adoption: Proxmox/provider often reports/derives these and they are not
      # worth forcing changes for existing VMs.
      boot_order,
      cpu[0].flags,
      memory[0].floating,
      operating_system,
      rng,
    ]
  }

  keyboard_layout = var.keyboard_layout
}
