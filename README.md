# Infrastructure Repository

GitOps-managed infrastructure for the m0sh1.cc homelab.

## Overview

Declarative infrastructure using ArgoCD (app-of-apps pattern), Helm wrapper charts,
Terraform, and Ansible. All changes flow through Git — no imperative cluster operations.

See [AGENTS.md](AGENTS.md) for the full enforcement contract.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Hypervisor | Proxmox VE (3-node cluster, ZFS storage) |
| Orchestration | k3s (1 control plane + 4 workers) |
| GitOps | ArgoCD (automated sync, prune, self-heal) |
| CNI | Cilium (dual-stack IPv4/IPv6, kube-proxy replacement) |
| Load Balancer | MetalLB (dual-stack, VLAN 30) |
| Ingress | Traefik (cert-manager TLS, Cloudflare Tunnel) |
| Storage | Proxmox CSI (ZFS), Garage S3 (object), CloudNativePG (PostgreSQL) |
| Identity | Authentik (OIDC SSO) |
| Secrets | Bitnami SealedSecrets (K8s), Ansible Vault (hosts) |
| IaC | Terraform (Proxmox provider) |
| Config Mgmt | Ansible (host provisioning, k3s setup) |
| Observability | Prometheus, Grafana, Loki, Alloy |
| Registry | Harbor (vulnerability scanning, cosign signing) |
| IPAM | NetBox + Diode (network intent and discovery) |

## Network

4-VLAN architecture routed by OPNsense, with dual-stack IPv6:

| VLAN | Subnet | Purpose |
|------|--------|---------|
| — | 10.0.0.0/24 | Home network |
| 10 | 10.0.10.0/24 | Infrastructure (Proxmox, DNS, PBS, SMB) |
| 20 | 10.0.20.0/24 | Kubernetes (control plane + workers) |
| 30 | 10.0.30.0/24 | Load balancers (Traefik, Diode) |

See [docs/diaries/network-vlan-architecture.md](docs/diaries/network-vlan-architecture.md) for the complete design.

## Repository Structure

```text
.
├── apps/             # Helm wrapper charts (cluster/ + user/)
├── argocd/           # ArgoCD Application manifests
├── cluster/          # Bootstrap and environment configs
├── terraform/        # Infrastructure as Code (Proxmox)
├── ansible/          # Configuration management
├── docs/             # Documentation
└── tools/            # CI scripts and DevOps automation
```

See [docs/layout.md](docs/layout.md) for the authoritative structure specification.

## Documentation

- **[docs/getting-started.md](docs/getting-started.md)** — Bootstrap, workflows, validation
- **[docs/layout.md](docs/layout.md)** — Repository structure
- **[docs/cluster-placement.md](docs/cluster-placement.md)** — Node scheduling and placement
- **[AGENTS.md](AGENTS.md)** — Automation rules and GitOps enforcement
- **[docs/TODO.md](docs/TODO.md)** — Active tasks
- **[docs/done.md](docs/done.md)** — Completed milestones

## Security

See [.github/SECURITY.md](.github/SECURITY.md) for the responsible disclosure process.
