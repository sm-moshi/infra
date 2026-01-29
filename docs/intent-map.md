# Network Topology Diagram

                          Internet
                             |
                    [Speedport Router]
                    LAN IP: 10.0.0.1/24
                    Wi-Fi clients: 10.0.0.0/24 (untagged)
                             |
                             | (untagged access port)
                        [Managed Switch]
                             |
     +-----------------------+------------------------+----------------------+
     |                       |                        |                      |
     | (trunk: VLAN 10/20/30)| (trunk: VLAN 10/20/30) | (trunk: VLAN 10/20/30)| (untagged)
     |                       |                        |                      |
  [pve-01]                [pve-02] [pve-03] (optional wired clients)
  mgmt: VLAN10            mgmt: VLAN10 mgmt: VLAN10
  hosts VMs/LXCs hosts VMs/LXCs hosts VMs/LXCs
     |                       |                        |
     | vmbrWAN (dedicated)   |                        |
     | (separate NIC, cabled directly to Speedport LAN port)
     |
  [OPNsense VM on pve-01]
    WAN: DHCP from Speedport (10.0.0.0/24)
    LAN: 10.0.10.1/24 (VLAN10 gateway)
    VLAN20 GW: 10.0.20.1/24
    VLAN30 GW: 10.0.30.1/24
     |
     +---- routes/firewalls between VLAN10/20/30 and (optionally) 10.0.0.0/24
