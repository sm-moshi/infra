/*
  Downloaded artifacts for the lab environment.

  Keep ISO/template media here so VM/LXC definitions stay in vms.tf/lxcs.tf.
*/

locals {
  pdm_iso_node      = "pve-01"
  pdm_iso_datastore = "local"
  pdm_iso_filename  = "proxmox-datacenter-manager_1.0-2.iso"
  pdm_iso_url       = "https://enterprise.proxmox.com/iso/proxmox-datacenter-manager_1.0-2.iso"
  pdm_iso_checksum  = "b4b98ed3e8f4dabb1151ebb713d6e7109aeba00d95b88bf65f954dd9ef1e89e1"
}

resource "proxmox_virtual_environment_download_file" "debian_13_lxc" {
  provider            = proxmox.pve_01
  content_type        = "vztmpl"
  datastore_id        = "local"
  node_name           = "pve-01"
  overwrite           = true
  overwrite_unmanaged = true

  url                = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
  file_name          = "debian-13-standard_13.1-2_amd64.tar.zst"
  checksum           = "5aec4ab2ac5c16c7c8ecb87bfeeb10213abe96db6b85e2463585cea492fc861d7c390b3f9c95629bf690b95e9dfe1037207fc69c0912429605f208d5cb2621f8"
  checksum_algorithm = "sha512"
  upload_timeout     = 300
}

resource "proxmox_virtual_environment_download_file" "pdm_iso" {
  provider            = proxmox.pve_01
  content_type        = "iso"
  datastore_id        = local.pdm_iso_datastore
  node_name           = local.pdm_iso_node
  file_name           = local.pdm_iso_filename
  url                 = local.pdm_iso_url
  checksum            = local.pdm_iso_checksum
  checksum_algorithm  = "sha256"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 1200
}

data "proxmox_virtual_environment_file" "pdm_iso" {
  provider     = proxmox.pve_01
  node_name    = local.pdm_iso_node
  datastore_id = local.pdm_iso_datastore
  content_type = "iso"
  file_name    = local.pdm_iso_filename

  depends_on = [proxmox_virtual_environment_download_file.pdm_iso]
}
