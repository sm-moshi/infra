# Network Architecture

**Status:** Operational
**Updated:** 2026-03-01

This document describes how the m0sh1.cc homelab network functions end-to-end:
the physical topology, VLAN segmentation, CNI datapath, load balancing, DNS
resolution chain, ingress routing, observability pipeline, remote access, and
how each layer differs from a stock k3s homelab.

---

## Physical Topology

```text
Internet (Telekom Fibre, dynamic IPv4, no IPv6)
    │
    ▼
┌──────────────────────────────────────────────┐
│  Speedport Smart 4 Plus  (10.0.0.1)         │
│  ISP router — NAT, DHCP for WiFi, firewall  │
│  Cannot be placed in bridge mode easily      │
└──────────────┬───────────────────────────────┘
               │  10.0.0.0/24 (home LAN, native VLAN)
               │
┌──────────────┴───────────────────────────────┐
│  L2 Switch  (10.0.0.2)                       │
│  Carries 802.1Q VLAN trunk to all Proxmox    │
│  hosts via vmbr0                             │
└──────┬──────────┬──────────┬─────────────────┘
       │          │          │
   ┌───┴───┐  ┌───┴───┐  ┌───┴───┐
   │pve-01 │  │pve-02 │  │pve-03 │   HP Mini PCs
   │.10.11 │  │.10.12 │  │.10.13 │   8 vCPU, 32 GB each
   └───────┘  └───────┘  └───────┘
       │          │          │
       └──────────┴──────────┘
              vmbr0 trunk (VLANs 10, 20, 30)
```

**Double NAT:** OPNsense sits behind the Speedport, creating a double-NAT path
(`client → OPNsense NAT → Speedport NAT → Internet`). This adds ~12 ms latency
to the first hop but is functionally invisible for outbound traffic. Inbound
connections from the internet are not supported without Speedport DMZ or port
forwarding.

**How this differs from a typical homelab:** Most k3s homelabs sit directly on
a flat home network with a single subnet. This lab uses enterprise-style VLAN
segmentation with a dedicated firewall VM routing between segments.

---

## VLAN Segmentation

OPNsense (FreeBSD 14.3, KVM on pve-01, VMID 300) acts as the inter-VLAN
router, firewall, DHCP server, DNS resolver, and Tailscale subnet router.

| VLAN | Subnet (IPv4) | Subnet (IPv6 ULA) | OPNsense GW | Purpose |
|------|---------------|---------------------|-------------|---------|
| native | 10.0.0.0/24 | fd00:1::/64 | 10.0.0.10 | Home WiFi, consumer devices |
| 10 | 10.0.10.0/24 | fd00:1:10::/64 | 10.0.10.1 | Infrastructure (Proxmox hosts, PBS, bastion) |
| 20 | 10.0.20.0/24 | fd00:1:20::/64 | 10.0.20.1 | Kubernetes nodes (control plane + workers) |
| 30 | 10.0.30.0/24 | fd00:1:30::/64 | 10.0.30.1 | LoadBalancer VIPs, ingress endpoints |

### Why separate VLANs?

- **Blast radius:** A compromised pod on VLAN 20 cannot ARP-scan Proxmox
  management interfaces on VLAN 10.
- **Traffic isolation:** LoadBalancer ARP/NDP announcements on VLAN 30 do not
  pollute the node network on VLAN 20.
- **Firewall visibility:** OPNsense sees and logs all inter-VLAN traffic,
  enabling per-VLAN firewall rules and IDS inspection.

**Stock k3s comparison:** A default k3s install has all nodes, services, and
management on the same flat subnet. There are no VLANs, no inter-VLAN
firewall, and no separation between management and data planes.

### OPNsense Interfaces

| OPNsense Name | FreeBSD Device | IPv4 | Role |
|---------------|----------------|------|------|
| WAN | vtnet0 | 10.0.0.100 (static) | Internet egress via Speedport |
| LAN | vtnet1 (native) | 10.0.0.10 | Home WiFi gateway |
| MGMT_VLAN10 | vtnet1.10 | 10.0.10.1 | Infrastructure gateway |
| MGMT_VLAN20 | vtnet1.20 | 10.0.20.1 | Kubernetes gateway |
| MGMT_VLAN30 | vtnet1.30 | 10.0.30.1 | Services gateway |
| TAIL | tailscale0 | 100.120.6.1 | Tailscale overlay |

OPNsense has two interfaces on the home subnet (WAN at .100 for internet,
LAN at .10 for gateway services). WiFi clients use 10.0.0.10 as their default
gateway, not the Speedport — this allows them to reach all VLANs through
OPNsense inter-VLAN routing without static routes.

### Firewall Rules

All VLANs have permissive "pass all from own subnet" rules. The home LAN also
has "allow to any", enabling WiFi clients to reach all lab segments. Outbound
NAT is applied only on the WAN interface; inter-VLAN traffic is routed, not
NATed.

### IPv6 (Internal Only)

IPv6 uses ULA prefix `fd00:1::/48` with SLAAC + stateless DHCPv6 on all VLANs.
WAN has no IPv6 — the Speedport does not pass Telekom's DHCPv6-PD prefix
through. Internal dual-stack works for pod-to-pod and service communication;
external IPv6 traffic is not possible.

---

## Kubernetes Cluster

### Nodes

| Node | Role | VLAN 20 IP | VLAN 30 IP | Proxmox Host |
|------|------|-----------|-----------|-------------|
| lab-ctrl | control-plane + worker | 10.0.20.20 | 10.0.30.50 | pve-01 |
| horse01 | worker | 10.0.20.21 | 10.0.30.51 | pve-01 |
| horse02 | worker | 10.0.20.22 | 10.0.30.52 | pve-02 |
| horse03 | worker | 10.0.20.23 | 10.0.30.53 | pve-03 |
| horse04 | worker | 10.0.20.24 | 10.0.30.54 | pve-02 |

All nodes are Debian 13 (trixie) VMs running k3s v1.35.1 with containerd.

### Dual-NIC Configuration

Each K8s node has **two virtual NICs**:

- **eth0** (VLAN 20): Pod network, cluster communication, API server, default route
- **eth1** (VLAN 30): LoadBalancer L2 announcements only (no default gateway)

**Why dual-NIC:** Cilium L2 announcements (ARP/NDP for LoadBalancer VIPs) must
originate from the same L2 segment as the VIP addresses. Since VIPs live on
VLAN 30 but pods run on VLAN 20, each node needs a foot in both VLANs.

**Stock k3s comparison:** Default k3s nodes have a single NIC. MetalLB or
kube-vip announces VIPs on the same subnet as the nodes. No VLAN separation
exists.

### Pod and Service CIDRs

| Resource | IPv4 | IPv6 |
|----------|------|------|
| Pod CIDR | 10.42.0.0/16 | fd00:42::/48 |
| Service CIDR | 10.43.0.0/16 | fd00:43::/112 |
| LB VIP range | 10.0.30.10–49 | fd00:1:30::10–49 |

---

## CNI: Cilium (Replacing Flannel + kube-proxy)

Cilium v1.19.1 replaces both Flannel (overlay) and kube-proxy (service routing)
with a single eBPF-based datapath.

### Key Settings

| Setting | Value | Why |
|---------|-------|-----|
| `routingMode` | `native` | All nodes share VLAN 20 (same L2). No tunnel overhead. |
| `autoDirectNodeRoutes` | `true` | Auto-programs kernel routes to peer pod CIDRs |
| `kubeProxyReplacement` | `true` | eBPF replaces iptables for service load balancing |
| `ipam.mode` | `cluster-pool` | Cilium manages pod CIDRs independently |
| `bpf.masquerade` | `true` | Required for BPF host routing + correct IPv6 identity |
| `policyEnforcementMode` | `never` | Policies loaded but not enforced (migration phase) |
| `lbIPAM.enabled` | `true` | Replaces MetalLB for IP allocation |
| `l2announcements.enabled` | `true` | Replaces MetalLB speaker for ARP/NDP |

### Native Routing vs Tunnelling

```text
Stock k3s (Flannel VXLAN):
  Pod A ──→ [VXLAN encap +50 bytes] ──→ Node B ──→ [VXLAN decap] ──→ Pod B

This cluster (Cilium native routing):
  Pod A ──→ [kernel route to Node B's pod CIDR] ──→ Pod B
```

Native routing avoids the 50-byte VXLAN overhead and the CPU cost of
encapsulation/decapsulation. It works because all nodes are on the same L2
segment (VLAN 20). Cilium's `autoDirectNodeRoutes` programs routes like:

```text
10.42.1.0/24 via 10.0.20.21 dev eth0   # horse01's pod CIDR
10.42.2.0/24 via 10.0.20.22 dev eth0   # horse02's pod CIDR
```

### BPF Masquerade

`bpf.masquerade: true` is critical. Without it, Cilium falls back to legacy
iptables-based host routing, and remote-pod IPv6 identities resolve to
`reserved:world-ipv6` instead of the correct pod identity. This breaks IPv6
network policy evaluation.

### kube-proxy Replacement

Cilium's eBPF datapath replaces kube-proxy entirely:

- **Service load balancing:** eBPF maps instead of iptables DNAT chains
- **Session affinity:** BPF-native, not conntrack-based
- **NodePort/LoadBalancer:** Handled in XDP/TC programs, not iptables

The API server address (`10.0.20.20:6443`) is hardcoded in Cilium's config
because kube-proxy is not available to resolve the `kubernetes.default` service
during Cilium bootstrap.

**Stock k3s comparison:** Default k3s uses Flannel VXLAN overlay + kube-proxy
iptables. No eBPF, no native routing, no LB-IPAM.

---

## Load Balancing: Cilium LB-IPAM + L2 Announcements

Cilium LB-IPAM replaced MetalLB as of 2026-03-01.

### IP Pool

```yaml
# CiliumLoadBalancerIPPool: services-vlan30
blocks:
  - start: "10.0.30.10"
    stop: "10.0.30.49"
  - start: "fd00:1:30::10"
    stop: "fd00:1:30::49"
```

40 IPv4 + 40 IPv6 addresses available on VLAN 30.

### L2 Announcement Policy

```yaml
# CiliumL2AnnouncementPolicy: services-vlan30
loadBalancerIPs: true
nodeSelector:
  matchLabels: {}    # all nodes participate
```

All nodes respond to ARP (IPv4) and NDP (IPv6) for allocated VIPs on their
eth1 (VLAN 30) interface.

### Current Allocations

| Service | IPv4 | IPv6 | Port(s) | Annotation |
|---------|------|------|---------|------------|
| Traefik LAN | 10.0.30.10 | fd00:1:30::10 | 80, 443 | `lbipam.cilium.io/ips` |
| Diode ingress-nginx | 10.0.30.15 | fd00:1:30::15 | 80, 443 | `lbipam.cilium.io/ips` |
| Alloy syslog | 10.0.30.14 | fd00:1:30::14 | 1514/TCP | `io.cilium/lb-ipam-ips` |

Reserved: .12 and .13 are physical devices on VLAN 30, not available for k8s.

**Stock k3s comparison:** Default k3s includes Klipper (ServiceLB) which runs
a DaemonSet binding to node IPs — no separate VIP, no L2 announcements. More
advanced setups use MetalLB in L2 mode. Cilium LB-IPAM is tighter integration
(single binary, no separate speaker pods).

---

## Ingress: Traefik

Traefik v3 runs as 2 replicas with pod anti-affinity across Proxmox zones.

### Traffic Flow

```text
Client (any VLAN or WiFi)
  │
  │  DNS: *.m0sh1.cc → 10.0.30.10 (via OPNsense Unbound)
  ▼
OPNsense inter-VLAN routing
  │
  ▼
10.0.30.10 (Traefik LB VIP on VLAN 30)
  │
  │  Cilium L2 announcement → ARP reply from a k8s node's eth1
  │  eBPF service LB → selected Traefik pod
  ▼
Traefik pod (ClusterIP service, not the LB directly)
  │
  │  IngressRoute / Ingress matching
  ▼
Backend pod (e.g., ArgoCD, Grafana, Harbor)
```

### Entrypoints

| Entrypoint | Port | Behaviour |
|------------|------|-----------|
| `web` | 80 | Permanent redirect to `websecure` |
| `websecure` | 443 | TLS termination with wildcard cert `wildcard-m0sh1-cc` |
| `metrics` | 9100 | Prometheus scrape endpoint (not exposed on LB) |

### TLS

A single wildcard certificate (`*.m0sh1.cc`) is stored as a Kubernetes Secret
(`wildcard-m0sh1-cc`) and set as the default TLS certificate in Traefik's
TLSStore. The certificate is issued by Cloudflare Origin CA and managed by
cert-manager with the origin-ca-issuer.

### IngressRoute vs Ingress

Most services use standard Kubernetes `Ingress` resources. ArgoCD and Hubble
use Traefik-native `IngressRoute` CRDs for features not available in standard
Ingress:

- **ArgoCD:** Dual routes — priority 10 for HTTP/1.1 (UI/API) and priority 11
  for h2c with `Content-Type: application/grpc` (native gRPC for `argocd` CLI)
- **Hubble:** ForwardAuth middleware for Authentik SSO protection

### Secondary Ingress: Diode

Diode (NetBox ingestion) runs its own ingress-nginx on a separate LB VIP
(`10.0.30.15`) because its routing requirements (`/diode` + `/diode/auth`) are
incompatible with Traefik's middleware model.

**Stock k3s comparison:** Default k3s includes Traefik as a DaemonSet with a
single entrypoint. No IngressRoutes, no wildcard TLS, no secondary ingress
controllers. Services are exposed directly via NodePort or Klipper.

---

## DNS Resolution Chain

DNS resolution traverses multiple layers depending on where the query
originates.

### From a Pod Inside the Cluster

```text
Pod → CoreDNS (10.43.0.10, ClusterIP)
  ├─ *.svc.cluster.local → resolved from k8s service registry
  ├─ pve01.m0sh1.cc → static entry in CoreDNS configmap
  └─ everything else → forwarded to OPNsense (10.0.20.1)
       └─ OPNsense Unbound → DNS-over-TLS to Cloudflare (1.1.1.1:853)
```

### From a K8s Node

```text
Node → /etc/resolv.conf → OPNsense (10.0.20.1)
  └─ Unbound → DoT → Cloudflare
```

### From the Mac (on LAN)

```text
Mac → Tailscale MagicDNS (100.100.100.100) [primary, order 103200]
  ├─ *.m0sh1.cc → split DNS → OPNsense (10.0.10.1)
  └─ everything else → Tailscale upstream
Mac → OPNsense (10.0.10.1) [fallback, order 200000]
  └─ Unbound → DoT → Cloudflare
```

### CoreDNS Customisation

CoreDNS has static entries for Proxmox hosts (`pve01/02/03.m0sh1.cc →
10.0.10.11-13`) to avoid DNS failures when the Proxmox CSI driver queries host
addresses under load. OPNsense Unbound can become slow under sustained query
bursts.

### OPNsense Unbound Configuration

| Setting | Value |
|---------|-------|
| DNSSEC | Enabled |
| DNS64 | Disabled |
| AAAA-only mode | Disabled |
| Upstream | DNS-over-TLS to `1.1.1.1` and `1.0.0.1` (port 853) |
| Verify CN | `one.one.one.one` |
| Forward first | Enabled (fallback to full recursion if DoT fails) |
| Listening interfaces | LAN, VLAN 10, VLAN 20, VLAN 30 |

### Unbound Host Overrides

All infrastructure hosts, K8s nodes, and application services are registered
as A records pointing to their respective IPs. Application FQDNs
(`argocd.m0sh1.cc`, `grafana.m0sh1.cc`, etc.) resolve to the Traefik VIP
`10.0.30.10`. Wildcard overrides are intentionally avoided to prevent
accidental exposure.

**Stock k3s comparison:** Default k3s uses CoreDNS with upstream forwarding to
the host's `/etc/resolv.conf` (typically the ISP's DNS). No DoT, no DNSSEC, no
split DNS, no custom host overrides.

---

## Observability Pipeline

### Metrics (Prometheus)

```text
In-cluster targets:
  ServiceMonitor CRDs → Prometheus operator → Prometheus scrape

  Scraped components:
  - Cilium agent + operator (per-node)
  - Hubble flow metrics (dns, drop, tcp, flow, icmp, http)
  - Traefik (per-pod)
  - ArgoCD (server, controller, repo-server, appset, notifications)
  - kube-state-metrics, node-exporter
  - cert-manager, sealed-secrets, Garage, CNPG
  - All user apps with ServiceMonitor labels

External scrape targets (additionalScrapeConfigs):
  - OPNsense node_exporter: 10.0.10.1:9100
  - OPNsense CrowdSec: 10.0.10.1:6060

In-cluster exporter:
  - opnsense-exporter: queries OPNsense REST API for firewall,
    gateway, Unbound, and DHCP metrics
```

### Logs (Loki via Alloy)

```text
Pod logs:
  /var/log/pods/*/*/*.log → Alloy DaemonSet → loki.source.file
    → loki.process (CRI parse) → loki.write → Loki gateway

OPNsense syslog:
  OPNsense syslog-ng → TCP 1514 → Alloy syslog listener (10.0.30.14)
    → loki.source.syslog → loki.relabel (promote __syslog_* labels)
    → loki.write → Loki gateway

  Syslog labels promoted: hostname, app (app_name), level (severity), facility
  Sources: filterlog, suricata, unbound, sshd, system
```

### Network Observability (Hubble)

```text
Cilium agent eBPF → Hubble observer → Hubble Relay → Hubble UI
                                    → Prometheus metrics (flow, dns, drop, tcp)
```

Hubble UI is accessible at `hubble.m0sh1.cc` via Traefik IngressRoute,
protected by Authentik SSO (forwardAuth middleware).

### Dashboards (Grafana)

Grafana is provisioned with dashboards via the kube-prometheus-stack sidecar:

| Folder | Dashboards | Source |
|--------|-----------|--------|
| Cilium | 6 dashboards | Cilium Helm chart ConfigMaps |
| ArgoCD | ArgoCD Overview | gnetId 14584 |
| Traefik | Traefik Overview | gnetId 17346 |
| OPNsense | OPNsense Exporter, Node Exporter BSD | gnetId 21113, 4260 |
| Security | CrowdSec Metrics, CrowdSec Insights, Suricata EVE | gnetId 21419, 21689, 22247 |
| DNS | Unbound DNS | gnetId 18703 |
| Database | CNPG Overview | gnetId 20417 |
| Certificates | cert-manager Overview | gnetId 20842 |
| Logging | Loki Metrics | gnetId 17781 |
| Forgejo | Forgejo Overview | gnetId 17802 |
| Infrastructure | Proxmox VE | gnetId 10347 |

### Alerting (Alertmanager)

PrometheusRule CRs define alerts for OPNsense health:

- **System:** High CPU, high memory, disk space low, unexpected reboot, exporter down
- **Network:** Interface down, network errors, gateway packet loss, high latency
- **Security:** CrowdSec ban spike, CrowdSec down, pf state table near capacity
- **DNS:** Unbound down

**Stock k3s comparison:** Default k3s has no monitoring stack. No Prometheus,
no Grafana, no Hubble, no syslog ingestion. Users must install everything
separately.

---

## Network Policies: CiliumNetworkPolicy

55 CiliumNetworkPolicies are deployed across two charts:

- `apps/cluster/cilium-policies/` — platform namespaces (monitoring, traefik, cert-manager, etc.)
- `apps/user/cilium-policies/` — application namespaces (apps, authentik, forgejo, etc.)

### Current Mode: Observe-Only

All policies have `enableDefaultDeny: false`. Cilium loads the policies and
matches traffic in Hubble, but no implicit deny is triggered. This allows
validating that all legitimate traffic patterns are covered before enabling
enforcement.

```yaml
# Example: every policy includes this
metadata:
  annotations:
    policy.cilium.io/description: "..."
spec:
  enableDefaultDeny:
    egress: false
    ingress: false
```

### Enforcement Phases

1. **Phase 4a (current):** Policies deployed, enforcement OFF (`policyEnforcementMode: never`).
   Traffic is matched and visible in Hubble but nothing is denied.
2. **Phase 4b:** Switch `policyEnforcementMode` to `default`. Policies load
   but `enableDefaultDeny: false` prevents implicit deny.
3. **Phase 4c:** Flip `enableDefaultDeny: true` per-namespace after Hubble
   observation confirms all traffic patterns match.

**Stock k3s comparison:** Default k3s uses standard Kubernetes NetworkPolicy
with a basic controller. No Hubble observability, no observe-before-enforce
workflow, no CiliumNetworkPolicy CRDs.

---

## GitOps: ArgoCD

All cluster state is managed declaratively through ArgoCD.

### App-of-Apps Structure

```text
argocd/apps/apps-root.yaml
  ├── argocd/apps/cluster/*.yaml   (platform: cilium, traefik, monitoring, ...)
  └── argocd/apps/user/*.yaml      (workloads: vaultwarden, forgejo, ...)

Disabled apps: argocd/disabled/
```

### Network-Relevant ArgoCD Config

- **Resource exclusions:** `cilium.io/*` wildcard excludes all Cilium CRDs from
  the ArgoCD resource tree (prevents UI crashes from CiliumIdentity/Endpoint churn)
- **ignoreDifferences:** Service `ipFamilyPolicy`, `ipFamilies`, `clusterIPs`
  are globally ignored to prevent selfHeal from reverting dual-stack settings
- **Server-side apply:** Enabled for the Cilium dashboard ConfigMap (exceeds
  262 KiB annotation limit for client-side apply)

---

## Remote Access: Tailscale

OPNsense runs as a Tailscale subnet router, advertising all four lab subnets:

```text
Tailscale tunnel (WireGuard)
  ├── 10.0.0.0/24   (home WiFi)
  ├── 10.0.10.0/24  (infrastructure)
  ├── 10.0.20.0/24  (k8s nodes)
  └── 10.0.30.0/24  (services / LB VIPs)
```

Split DNS routes `*.m0sh1.cc` queries through the Tailscale tunnel to
OPNsense's Unbound, so application FQDNs resolve to internal VLAN 30 VIPs
instead of Cloudflare's public proxy addresses.

When **on Tailscale:** `argocd.m0sh1.cc → 10.0.30.10 → Traefik → ArgoCD`
When **off Tailscale:** `argocd.m0sh1.cc → Cloudflare Anycast → Cloudflare Access`

---

## External Services Reaching Into the Cluster

| Source | Target | Protocol | Path |
|--------|--------|----------|------|
| OPNsense syslog-ng | Alloy syslog LB (10.0.30.14:1514) | TCP | VLAN 30 LB → pod |
| Prometheus | OPNsense node_exporter (10.0.10.1:9100) | HTTP | VLAN 20 → VLAN 10 (via OPNsense routing) |
| Prometheus | OPNsense CrowdSec (10.0.10.1:6060) | HTTP | VLAN 20 → VLAN 10 |
| opnsense-exporter pod | OPNsense REST API (10.0.10.1:443) | HTTPS | Pod CIDR → VLAN 10 |
| Proxmox CSI | Proxmox API (pve0X.m0sh1.cc:8006) | HTTPS | VLAN 20 → VLAN 10 |

---

## Gateway Monitoring

OPNsense monitors the WAN gateway (`WAN_DHCP → 10.0.0.1`, the Speedport) via
ICMP. Current readings: RTT 0.6 ms, loss 0.0%. Gateway health graphs are
available under **System → Gateways → Overview** in OPNsense.

---

## Summary: What Makes This Different from Stock k3s

| Layer | Stock k3s | This Cluster |
|-------|-----------|-------------|
| **Network** | Flat subnet, single NIC | 4 VLANs, dual-NIC nodes, OPNsense firewall |
| **CNI** | Flannel VXLAN | Cilium native routing + eBPF |
| **kube-proxy** | iptables | Replaced by Cilium eBPF |
| **Load balancer** | Klipper (ServiceLB) | Cilium LB-IPAM + L2 announcements |
| **Ingress** | Traefik DaemonSet | Traefik Deployment (2 replicas) + IngressRoute CRDs |
| **TLS** | Self-signed or Let's Encrypt per-service | Wildcard cert via Cloudflare Origin CA |
| **DNS** | CoreDNS → host resolver | CoreDNS → OPNsense Unbound → DoT to Cloudflare |
| **Network policy** | Basic k8s NetworkPolicy | 55 CiliumNetworkPolicies (observe-only) |
| **Monitoring** | None | Prometheus + Grafana + Loki + Alloy + Hubble |
| **Remote access** | SSH / kubectl port-forward | Tailscale subnet router + split DNS |
| **IP addressing** | Single-stack IPv4 | Dual-stack IPv4 + IPv6 ULA |
| **GitOps** | Manual kubectl | ArgoCD app-of-apps |
| **Secrets** | kubectl create secret | SealedSecrets (Bitnami) |
