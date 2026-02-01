terraform {
  required_version = ">= 1.14.3"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.1"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.16.0"
    }
  }
}
