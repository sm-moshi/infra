# Cluster Placement And Sizing

This document captures scheduling defaults and placement rationale for the m0sh1.cc homelab.

## Principles

- Keep the control plane light. Only controllers and operators may run on labctrl.
- Treat workers as failure domains (pve-01/02/03) and spread replicas across nodes.
- Use requests and limits so the scheduler does not lie.
- Use Proxmox CSI storage classes for stateful workloads.

## Node Labels (Recommended)

- Label workers with `topology.kubernetes.io/zone` as `pve-01`, `pve-02`, `pve-03`.
- Keep `kubernetes.io/hostname` as the fallback topology key.

```bash
kubectl label node horse01 topology.kubernetes.io/zone=pve-01
kubectl label node horse02 topology.kubernetes.io/zone=pve-02
kubectl label node horse03 topology.kubernetes.io/zone=pve-03
kubectl label node horse04 topology.kubernetes.io/zone=pve-02
```

## Control Plane Policy

- Prefer `NoSchedule` taint on labctrl if we want strict enforcement.
- Allow only lightweight controllers on labctrl: ArgoCD, cert-manager, sealed-secrets, external-dns.
- Keep stateful workloads off labctrl even if it is untainted.

## Worker Failure Domains

- Spread replicas across workers using `topologySpreadConstraints`.
- Use `kubernetes.io/hostname` for immediate spread and `topology.kubernetes.io/zone` once labeled.
- Prefer `ScheduleAnyway` for the zone constraint and a stricter rule for hostname if needed.

## Stateful Defaults

- Use `nodeSelector: node-role.kubernetes.io/worker: "true"`.
- Use `podAntiAffinity` on `kubernetes.io/hostname`.
- Pin PVCs via Proxmox CSI and size requests/limits sensibly.

## Placement Recommendations

### CNPG (CloudNativePG)

- Run on workers only.
- Target three instances across horse01, horse02, horse03.
- Leave horse04 as spare capacity or maintenance slack.

### Valkey

- Default to three pods spread across horse01, horse02, horse03.
- If used as cache only, replicas can be reduced but spreading is still cheap.

### Harbor

- Core components (core, portal, jobservice) spread across horse01, horse02, horse03.
- Registry uses Proxmox CSI and should avoid labctrl.
- Prefer external Postgres (CNPG) and Valkey when possible.

### Observability

- Prometheus: one worker with good IO, avoid sharing with Loki.
- Alertmanager: two replicas across different workers.
- Loki (single binary): horse02 or horse03.
- Alloy: DaemonSet on all workers, avoid labctrl unless needed.

### Authentik

- Postgres via CNPG and Redis via Valkey.
- Server and worker spread across horse01, horse02, horse03.

### NetBox

- Postgres via CNPG and Redis via Valkey.
- Web and worker spread across horse01, horse02, horse03.

### Utility Apps

- pgadmin4, Uptime-Kuma, Headlamp, Homepages: horse04 or spread lightly.
- Basic Memory MCP: horse04 unless it becomes critical.
- Semaphore and Scanopy: horse04 with firm limits to avoid contention.

### Gitea

- App pods spread across horse01, horse02, horse03.
- Database via CNPG across workers.
- Storage via PVC or MinIO, avoid pinning all to one Proxmox node.

## Non-K8s Placement

- SMB LXC: pve-01 (storage-friendly).
- Bastion VM: pve-02.
- DNS LXCs: dns01 on pve-02, dns02 on pve-03.
- Pentest VLAN VMs: pve-03 for blast-radius isolation.

## Database Strategy

- Default: shared CNPG cluster for most apps to reduce operational overhead.
- Use per-app CNPG clusters when isolation, extensions, or lifecycle differences demand it.
- Reserve separate clusters for heavy workloads or high-risk migrations.

## Improvements To Consider

- Enforce a control-plane taint and explicitly tolerate only core controllers.
- Label nodes with `topology.kubernetes.io/zone` to align with PVE failure domains.
- Use PodDisruptionBudgets on critical stateful components.
- Review resource requests quarterly as cluster capacity grows.
