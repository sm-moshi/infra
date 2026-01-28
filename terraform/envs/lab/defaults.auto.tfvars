proxmox_endpoint = {
  "pve-01" = "https://10.0.10.11:8006/api2/json"
  "pve-02" = "https://10.0.10.12:8006/api2/json"
  "pve-03" = "https://10.0.10.13:8006/api2/json"
}

debian_template_vmid = {
  "pve-01" = 9000
  "pve-02" = 9001
  "pve-03" = 9002
}

fedora_template_vmid = {
  "pve-02" = 9100
}

proxmox_datastore = "nvme"
lab_gateway       = "10.0.10.1"

proxmox_nodes = ["pve-01", "pve-02", "pve-03"]
