terraform {
  required_version = ">= 1.14.3"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.18.0"
    }
  }
}
