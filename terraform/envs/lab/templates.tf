/*
  Downloaded artifacts for the lab environment.

  Keep ISO/template media here so VM/LXC definitions stay in vms.tf/lxcs.tf.
*/

locals {
  # OPNsense
  opnsense_iso_node      = "pve-01"
  opnsense_iso_datastore = "local"
  opnsense_iso_filename  = "OPNsense-25.7-dvd-amd64.iso"
  opnsense_iso_url       = "https://pkg.opnsense.org/releases/25.7/OPNsense-25.7-dvd-amd64.iso.bz2"
  opnsense_iso_checksum  = "fa4b30df3f5fd7a2b1a1b2bdfaecfe02337ee42f77e2d0ae8a60753ea7eb153e"

  # Fedora cloud image
  fedora_cloud_node      = "pve-02"
  fedora_cloud_datastore = "local"
  fedora_cloud_filename  = "fedora-cloud-base-43-1.6.x86_64.img"
  fedora_cloud_url       = "https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
  fedora_cloud_checksum  = "846574c8a97cd2d8dc1f231062d73107cc85cbbbda56335e264a46e3a6c8ab2f"

  # Ubuntu cloud image
  ubuntu_cloud_node      = "pve-02"
  ubuntu_cloud_datastore = "local"
  ubuntu_cloud_filename  = "ubuntu-24.04-server-cloudimg-amd64.img"
  ubuntu_cloud_url       = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
  ubuntu_cloud_checksum  = "2b5f90ffe8180def601c021c874e55d8303e8bcbfc66fee2b94414f43ac5eb1f"

  # Proxmox Backup Server ISO
  pbs_iso_node      = "pve-01"
  pbs_iso_datastore = "local"
  pbs_iso_filename  = "proxmox-backup-server_4.1-1.iso"
  pbs_iso_url       = "https://enterprise.proxmox.com/iso/proxmox-backup-server_4.1-1.iso"
  pbs_iso_checksum  = "670f0a71ee25e00cc7839bebb3f399594f5257e49a224a91ce517460e7ab171e"

  # Debian 13 LXC template (must exist on every node that creates LXCs)
  debian_13_lxc_template_url       = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
  debian_13_lxc_template_filename  = "debian-13-standard_13.1-2_amd64.tar.zst"
  debian_13_lxc_template_checksum  = "5aec4ab2ac5c16c7c8ecb87bfeeb10213abe96db6b85e2463585cea492fc861d7c390b3f9c95629bf690b95e9dfe1037207fc69c0912429605f208d5cb2621f8"
  debian_13_lxc_template_algorithm = "sha512"
  debian_13_lxc_template_timeout   = 300
}

resource "proxmox_virtual_environment_download_file" "opnsense_iso" {
  provider            = proxmox.pve_01
  content_type        = "iso"
  datastore_id        = local.opnsense_iso_datastore
  node_name           = local.opnsense_iso_node
  file_name           = local.opnsense_iso_filename
  url                 = local.opnsense_iso_url
  checksum            = local.opnsense_iso_checksum
  checksum_algorithm  = "sha256"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 1800
}

resource "proxmox_virtual_environment_download_file" "pbs_iso" {
  provider            = proxmox.pve_01
  content_type        = "iso"
  datastore_id        = local.pbs_iso_datastore
  node_name           = local.pbs_iso_node
  file_name           = local.pbs_iso_filename
  url                 = local.pbs_iso_url
  checksum            = local.pbs_iso_checksum
  checksum_algorithm  = "sha256"
  overwrite           = false
  overwrite_unmanaged = false
  upload_timeout      = 1800

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_download_file" "debian_13_lxc_pve01" {
  provider            = proxmox.pve_01
  content_type        = "vztmpl"
  datastore_id        = "local"
  node_name           = "pve-01"
  file_name           = local.debian_13_lxc_template_filename
  url                 = local.debian_13_lxc_template_url
  checksum            = local.debian_13_lxc_template_checksum
  checksum_algorithm  = local.debian_13_lxc_template_algorithm
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = local.debian_13_lxc_template_timeout
}

resource "proxmox_virtual_environment_download_file" "debian_13_lxc_pve02" {
  provider            = proxmox.pve_02
  content_type        = "vztmpl"
  datastore_id        = "local"
  node_name           = "pve-02"
  file_name           = local.debian_13_lxc_template_filename
  url                 = local.debian_13_lxc_template_url
  checksum            = local.debian_13_lxc_template_checksum
  checksum_algorithm  = local.debian_13_lxc_template_algorithm
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = local.debian_13_lxc_template_timeout
}

resource "proxmox_virtual_environment_download_file" "debian_13_lxc_pve03" {
  provider            = proxmox.pve_03
  content_type        = "vztmpl"
  datastore_id        = "local"
  node_name           = "pve-03"
  file_name           = local.debian_13_lxc_template_filename
  url                 = local.debian_13_lxc_template_url
  checksum            = local.debian_13_lxc_template_checksum
  checksum_algorithm  = local.debian_13_lxc_template_algorithm
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = local.debian_13_lxc_template_timeout
}

resource "proxmox_virtual_environment_download_file" "fedora_cloud" {
  provider            = proxmox.pve_02
  content_type        = "iso"
  datastore_id        = local.fedora_cloud_datastore
  node_name           = local.fedora_cloud_node
  file_name           = local.fedora_cloud_filename
  url                 = local.fedora_cloud_url
  checksum            = local.fedora_cloud_checksum
  checksum_algorithm  = "sha256"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 1800
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud" {
  provider            = proxmox.pve_02
  content_type        = "iso"
  datastore_id        = local.ubuntu_cloud_datastore
  node_name           = local.ubuntu_cloud_node
  file_name           = local.ubuntu_cloud_filename
  url                 = local.ubuntu_cloud_url
  checksum            = local.ubuntu_cloud_checksum
  checksum_algorithm  = "sha256"
  overwrite           = true
  overwrite_unmanaged = true
  upload_timeout      = 1800
}
