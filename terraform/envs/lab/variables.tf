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

variable "proxmox_nodes" {
  description = "List of Proxmox node names managed by this environment (e.g., [\"pve-01\", \"pve-02\"])."
  type        = list(string)
}

variable "proxmox_datastore" {
  type        = string
  description = "Default Proxmox datastore_id for VM disks/EFI/cloud-init"
  default     = "nvmestore"
}

variable "debian_template_vmid" {
  type        = map(number)
  description = "VMIDs of the Debian cloud-init template to clone from"
}

variable "public_ssh_keys" {
  type        = list(string)
  description = "Public SSH keys to inject into VMs"
}

variable "lab_gateway" {
  type        = string
  description = "Gateway IP address for the lab network"
  default     = "10.0.0.1"
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
}
variable "timezone" {
  type        = string
  description = "Timezone for VMs (e.g., 'Europe/Berlin')"
  default     = "Europe/Berlin"
}
