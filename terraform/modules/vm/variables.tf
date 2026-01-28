
variable "name" {
  type        = string
  description = "VM name"
}

variable "vm_id" {
  type        = number
  description = "Proxmox VMID"
}

variable "template_vmid" {
  type        = number
  default     = null
  description = "Source template VMID to clone from (e.g. Debian 13 cloud-init template)"
}

variable "node_name" {
  type        = string
  description = "Target Proxmox node"
}

variable "tags" {
  type        = list(string)
  description = "Proxmox tags"
}

variable "cores" {
  type = number
}

variable "memory" {
  type        = number
  description = "Dedicated memory in MB"
}

variable "memory_min" {
  type        = number
  default     = null
  description = "Minimum memory in MB (balloon). Null disables ballooning."
}

variable "cpu_type" {
  type    = string
  default = "host"
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GB"
}

variable "data_disk_size" {
  type        = number
  default     = null
  description = "Optional data disk size in GB (e.g., for build caches)"
}

variable "data_disk_datastore_id" {
  type        = string
  default     = null
  description = "Optional datastore for the data disk; defaults to datastore_id when null"
}

variable "datastore_id" {
  type        = string
  description = "Datastore for disks and EFI"
}

variable "gateway" {
  type        = string
  default     = null
  description = "Gateway IP address for the VM (required when cloud-init is enabled)."
}

variable "ipv4_address" {
  type        = string
  default     = null
  description = "IPv4 address CIDR for the VM (required when cloud-init is enabled)."
}

variable "ipv6_address" {
  type    = string
  default = null
}

variable "ipv6_gateway" {
  type    = string
  default = null
}

variable "ssh_keys" {
  type        = list(string)
  description = "Injected SSH public keys"
  default     = []
}

variable "cloud_init_user" {
  type        = string
  description = "Cloud-init username to create (e.g., root or a non-root user)."
  default     = "root"
}

variable "cloud_init_enabled" {
  type        = bool
  description = "Enable cloud-init configuration for the VM."
  default     = true

  validation {
    condition     = var.cloud_init_enabled == false || (var.gateway != null && var.ipv4_address != null)
    error_message = "When cloud_init_enabled is true, gateway and ipv4_address must be set."
  }
}

variable "cdrom_file_id" {
  type        = string
  description = "Optional ISO file ID to attach as CD-ROM."
  default     = null
}

variable "keyboard_layout" {
  type        = string
  description = "Keyboard layout for the container (e.g., 'en-us')."
  default     = "de"
}

variable "on_boot" {
  type        = bool
  default     = true
  description = "Start VM on host boot."
}

variable "started" {
  type        = bool
  default     = true
  description = "Ensure the VM is running."
}

variable "network_devices" {
  type = list(object({
    bridge      = string
    model       = optional(string, "virtio")
    mac_address = optional(string, null)
    queues      = optional(number, null)
    firewall    = optional(bool, false)
    trunks      = optional(string, null)
    vlan_id     = optional(number, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for n in var.network_devices : length(trimspace(n.bridge)) > 0
    ])
    error_message = "Each network_devices entry must set a non-empty bridge."
  }

  validation {
    condition = alltrue([
      for n in var.network_devices : (
        (try(n.vlan_id, null) == null || (try(n.vlan_id, 0) >= 0 && try(n.vlan_id, 0) <= 4094))
      )
    ])
    error_message = "vlan_id must be null or in range 0..4094."
  }

  validation {
    condition = alltrue([
      for n in var.network_devices : (
        # Either access VLAN (vlan_id) OR trunk (trunks), not both.
        !(try(n.vlan_id, null) != null && try(n.trunks, null) != null)
      )
    ])
    error_message = "Do not set both vlan_id and trunks on the same NIC."
  }

  validation {
    condition = alltrue([
      for n in var.network_devices : (
        try(n.queues, null) == null || try(n.queues, 1) >= 1
      )
    ])
    error_message = "queues must be null or >= 1."
  }
}

variable "bridge" {
  type        = string
  default     = null
  description = "DEPRECATED (single-NIC). Use network_devices instead."
}

variable "mac_address" {
  type        = string
  default     = null
  description = "DEPRECATED (single-NIC). Use network_devices instead."
}

variable "network_queues" {
  type        = number
  default     = 2
  description = "DEPRECATED (single-NIC). Use network_devices instead."
}

variable "ignore_network_changes" {
  type        = bool
  default     = false
  description = "If true, ignore changes to network_device blocks (useful for adopted/manual multi-NIC VMs)."
}

variable "ignore_efi_disk_changes" {
  type        = bool
  default     = false
  description = "If true, ignore changes to efi_disk block."
}

variable "efi_disk_type" {
  type        = string
  description = "EFI disk type: 2m or 4m. If null, do not set type (use Proxmox default)."
  default     = null
}
