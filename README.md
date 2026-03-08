# Infrastructure Repository

GitOps-managed infrastructure for the m0sh1.cc homelab.

## Overview

Declarative infrastructure using ArgoCD (app-of-apps pattern), Helm wrapper charts,
Terraform, and Ansible. All changes flow through Git — no imperative cluster operations.

See [AGENTS.md](AGENTS.md) for the full enforcement contract.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Hypervisor | Proxmox VE (3-node cluster: pve-01/02/03, ZFS storage) |
| Orchestration | k3s (1 control plane + 4 workers, Debian 13) |
| GitOps | ArgoCD (automated sync, prune, self-heal) |
| CNI | Cilium (native routing, dual-stack IPv4/IPv6, kube-proxy replacement) |
| Load Balancer | Cilium LB-IPAM + L2 announcements (dual-stack, VLAN 30) |
| Ingress | Traefik (wildcard TLS via Cloudflare Origin CA) |
| External Access | Cloudflare Tunnel + Tailscale subnet routing |
| Storage | Proxmox CSI (ZFS), Garage S3 (object), CloudNativePG (PostgreSQL), Valkey (cache) |
| Identity | Authentik (OIDC SSO for all user apps) |
| Secrets | Bitnami SealedSecrets (K8s), Ansible Vault (hosts) |
| IaC | Terraform (Proxmox provider) |
| Config Mgmt | Ansible (host provisioning, k3s setup, OPNsense) |
| Observability | Prometheus, Grafana, Loki, Alloy, Hubble |
| Security | CrowdSec (k8s + OPNsense), Trivy Operator, CiliumNetworkPolicies |
| Registry | Harbor (vulnerability scanning, cosign signing, DHI images) |
| CI/CD | Woodpecker CI, Renovate (automated dependency updates) |
| IPAM | NetBox + Diode (network intent and discovery) |
| Firewall | OPNsense (inter-VLAN routing, Suricata IDS, Unbound DNS) |

## Network

4-VLAN architecture routed by OPNsense, with dual-stack IPv6 (ULA internal):

| VLAN | Subnet | Purpose |
|------|---------|---------|
| — | 10.0.0.0/24 | Home network |
| 10 | 10.0.10.0/24 | Infrastructure (Proxmox, DNS, PBS) |
| 20 | 10.0.20.0/24 | Kubernetes (control plane + workers) |
| 30 | 10.0.30.0/24 | Load balancers (Traefik, Diode, Alloy syslog) |

See [docs/network-architecture.md](docs/network-architecture.md) for the comprehensive architecture.

## Deployed Applications

### Platform (cluster scope)

ArgoCD, Alloy, cert-manager, Cilium, Cloudflared, CloudNativePG, CoreDNS,
CrowdSec, external-dns, Garage (cluster + operator), Grafana MCP, Kured,
kube-prometheus-stack, local-path, Loki, OPNsense exporter, origin-ca-issuer,
Prometheus CRDs, Prometheus PVE exporter, Proxmox CSI, Reflector,
Renovate Operator, SealedSecrets, Traefik, Valkey.

### Workloads (user scope)

Authentik, Basic Memory, Diode, Forgejo, Garage WebUI, Harbor, Headlamp,
Kopia, NetBox (+ operator), Ollama, Open WebUI, Paperless-ngx, pgAdmin 4,
Qdrant, Renovate, Stirling PDF, Trivy Operator, Uptime Kuma, Vaultwarden,
Woodpecker CI.

## Repository Structure

```text
.
├── apps/             # Helm wrapper charts (cluster/ + user/)
├── argocd/           # ArgoCD Application manifests
├── cluster/          # Bootstrap and environment configs
├── terraform/        # Infrastructure as Code (Proxmox)
├── ansible/          # Configuration management
├── docs/             # Documentation
└── tools/            # CI scripts, guards, and DevOps automation
```

See [docs/layout.md](docs/layout.md) for the authoritative structure specification.

## Documentation

- **[docs/getting-started.md](docs/getting-started.md)** — Bootstrap, workflows, validation
- **[docs/layout.md](docs/layout.md)** — Repository structure
- **[docs/network-architecture.md](docs/network-architecture.md)** — Full network and cluster architecture
- **[docs/cluster-placement.md](docs/cluster-placement.md)** — Node scheduling and placement
- **[docs/authentik-contract.md](docs/authentik-contract.md)** — Authentik integration modes
- **[AGENTS.md](AGENTS.md)** — Automation rules and GitOps enforcement
- **[docs/TODO.md](docs/TODO.md)** — Active tasks
- **[docs/done.md](docs/done.md)** — Completed milestones

## Security

See [.github/SECURITY.md](.github/SECURITY.md) for the responsible disclosure process.
