variable "proxmox_endpoint" {
  type        = map(string)
  description = "Map of Proxmox node names to their API endpoint URLs"
}

variable "proxmox_api_token_pve01" {
  type        = string
  description = "Proxmox API token for pve-01 (format: 'token_id=token_secret')"
  sensitive   = true
}

variable "proxmox_api_token_pve02" {
  type        = string
  description = "Proxmox API token for pve-02 (format: 'token_id=token_secret')"
  sensitive   = true
}

variable "proxmox_api_token_pve03" {
  type        = string
  description = "Proxmox API token for pve-03 (format: 'token_id=token_secret')"
  sensitive   = true
}

variable "proxmox_nodes" {
  description = "List of Proxmox node names managed by this environment (e.g., [\"pve-01\", \"pve-02\"])."
  type        = list(string)

  validation {
    condition     = length(var.proxmox_nodes) > 0
    error_message = "At least one Proxmox node must be specified"
  }
}

variable "proxmox_datastore" {
  type        = string
  description = "Default Proxmox datastore_id for VM disks/EFI/cloud-init"
  default     = "nvmestore"

  validation {
    condition     = length(var.proxmox_datastore) > 0
    error_message = "Datastore ID cannot be empty"
  }
}

variable "debian_template_vmid" {
  type        = map(number)
  description = "VMIDs of the Debian cloud-init template to clone from"

  validation {
    condition     = alltrue([for k, v in var.debian_template_vmid : v >= 9000 && v < 9099])
    error_message = "Template VMIDs must be in range 9000-9099 to avoid conflicts with infrastructure VMs"
  }
}

variable "fedora_template_vmid" {
  type        = map(number)
  description = "VMIDs of the Fedora cloud-init template to clone from"

  validation {
    condition     = alltrue([for k, v in var.fedora_template_vmid : v >= 9100 && v < 10000])
    error_message = "Template VMIDs must be in range 9100-9999 to avoid conflicts with infrastructure VMs"
  }
}

variable "public_ssh_keys" {
  type        = list(string)
  description = "Public SSH keys to inject into VMs"
}

variable "lab_gateway" {
  type        = string
  description = "Gateway IP address for the lab network"
  default     = "10.0.0.1"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.lab_gateway))
    error_message = "Gateway must be a valid IPv4 address"
  }
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token"
}

variable "keyboard_layout" {
  type        = string
  description = "Keyboard layout for VMs (e.g., 'en-us')"
  default     = "de"

  validation {
    condition     = contains(["de", "en-us", "en-gb", "fr", "es"], var.keyboard_layout)
    error_message = "Keyboard layout must be one of: de, en-us, en-gb, fr, es"
  }
}
variable "timezone" {
  type        = string
  description = "Timezone for VMs (e.g., 'Europe/Berlin')"
  default     = "Europe/Berlin"
}
