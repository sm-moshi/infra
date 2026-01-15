# SECURITY: insecure = true disables TLS certificate verification
# This is intentional for homelab environment where Proxmox uses self-signed certificates
# All communication is within trusted 10.0.0.0/24 network
# See docs/security.md for full justification and risk assessment
provider "proxmox" {
  alias     = "pve_01"
  endpoint  = var.proxmox_endpoint["pve-01"]
  api_token = var.proxmox_api_token_pve01
  insecure  = true
}

provider "proxmox" {
  alias     = "pve_02"
  endpoint  = var.proxmox_endpoint["pve-02"]
  api_token = var.proxmox_api_token_pve02
  insecure  = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
