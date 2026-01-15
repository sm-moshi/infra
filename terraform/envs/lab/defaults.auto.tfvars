proxmox_endpoint = {
  "pve-01" = "https://10.0.0.100:8006/api2/json"
  "pve-02" = "https://10.0.0.101:8006/api2/json"
}

debian_template_vmid = {
  "pve-01" = 9000
  "pve-02" = 9001
}

proxmox_datastore = "nvmestore"
lab_gateway       = "10.0.0.1"

proxmox_nodes = ["pve-01", "pve-02"]
