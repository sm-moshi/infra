variable "hostname" {
  type        = string
  description = "LXC hostname (and Proxmox name)."
}

variable "vmid" {
  type        = number
  description = "Static VMID of the container."
}

variable "target_node" {
  type        = string
  description = "Proxmox node name (e.g. pve-01, pve-02)."
}

variable "cores" {
  type        = number
  description = "Number of vCPU cores."
  default     = 2
}

variable "memory" {
  type        = number
  description = "Dedicated RAM in MiB."
  default     = 512
}

variable "swap" {
  type        = number
  description = "Swap size in MiB."
  default     = 256
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GiB."
}

variable "disk_mount_options" {
  type        = list(string)
  description = "Root filesystem mount options."
  default     = ["noatime", "discard"]
}

variable "storage" {
  type        = string
  description = "Proxmox datastore ID (e.g. nvmestore, vmstore)."
}

variable "ostemplate" {
  type        = string
  description = "LXC template file ID (e.g. local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst)."
}

variable "ip" {
  type        = string
  description = "IPv4 address with CIDR (e.g. 10.0.0.11/24)."
}

variable "ipv6_address" {
  type        = string
  description = "IPv6 address with CIDR (e.g. 2001:db8::1/64)."
  default     = ""
}

variable "gateway" {
  type        = string
  description = "IPv4 gateway."
  default     = "10.0.0.1"
}

variable "ipv6_gateway" {
  type        = string
  description = "IPv6 gateway."
  default     = "fd8d:a82b:a42f:1::1"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys to inject into the root account of the container."
  default     = []
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers used inside the container."
  default     = []
}

variable "tags" {
  type        = list(string)
  description = "Tags for the container in Proxmox."
  default     = []
}

variable "unprivileged" {
  type        = bool
  description = "Whether to create an unprivileged container."
  default     = true
}

variable "dns_domain" {
  type        = string
  description = "DNS search domain used inside the container (maps to Proxmox searchdomain)."
  default     = null
}

variable "mount_points" {
  description = "Optional list of mount points to attach to the container."
  type = list(object({
    volume        = string
    path          = string
    mount_options = optional(list(string), [])
    replicate     = optional(bool, false)
  }))
  default = []
}

variable "firewall" {
  type        = bool
  description = "Enable Proxmox firewall on the LXC NIC."
  default     = false
}

variable "vlan_id" {
  type    = number
  default = 0

  validation {
    condition     = var.vlan_id == 0 || (var.vlan_id >= 2 && var.vlan_id <= 4094)
    error_message = "vlan_id must be 0 (untagged) or 2..4094."
  }
}

variable "bridge" {
  type    = string
  default = "vmbr0"

  validation {
    condition     = length(trimspace(var.bridge)) > 0
    error_message = "bridge must be a non-empty string."
  }
}
