terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  description   = "Managed by Terraform - ${var.hostname}"
  node_name     = var.target_node
  start_on_boot = true
  started       = true
  unprivileged  = var.unprivileged

  vm_id = var.vmid
  tags  = var.tags

  cpu {
    architecture = "amd64"
    cores        = var.cores
  }

  disk {
    datastore_id  = var.storage
    mount_options = var.disk_mount_options
    size          = var.disk_size
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  operating_system {
    template_file_id = var.ostemplate
    type             = "debian"
  }

  initialization {
    hostname = var.hostname

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
        domain  = var.dns_domain
      }
    }

    ip_config {
      ipv4 {
        address = var.ip
        gateway = var.gateway
      }
      dynamic "ipv6" {
        for_each = var.ipv6_address != "" ? [1] : []
        content {
          address = var.ipv6_address
          gateway = var.ipv6_gateway
        }
      }
    }

    dynamic "user_account" {
      for_each = length(var.ssh_public_keys) > 0 ? [1] : []
      content {
        keys = var.ssh_public_keys
      }
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume        = mount_point.value.volume
      path          = mount_point.value.path
      mount_options = mount_point.value.mount_options
      replicate     = mount_point.value.replicate
    }
  }

  dynamic "features" {
    for_each = var.unprivileged ? [1] : []
    content {
      nesting = true
      fuse    = false
    }
  }

  lifecycle {
    # Avoid forced recreation when managing existing containers whose template file ID cannot be read back reliably.
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }
}
