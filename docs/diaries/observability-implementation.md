# Observability Implementation Plan

## Document Information

- **Author:** m0sh1-devops Agent
- **Date:** 2026-02-02
- **Status:** Draft Implementation Plan (audited 2026-02-03)
- **Related:** docs/diaries/valkey-implementation.md, docs/diaries/harbor-implementation.md

---

## Table of Contents

- [Observability Implementation Plan](#observability-implementation-plan)
  - [Document Information](#document-information)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Current State (Audit 2026-02-05)](#current-state-audit-2026-02-05)
  - [Architecture](#architecture)
  - [Prerequisites](#prerequisites)
  - [Phase 1: kube-prometheus-stack](#phase-1-kube-prometheus-stack)
  - [Phase 1.5: grafana-mcp (Optional)](#phase-15-grafana-mcp-optional)
    - [Grafana Connection](#grafana-connection)
    - [Credentials (SealedSecret)](#credentials-sealedsecret)
  - [Phase 2: prometheus-pve-exporter](#phase-2-prometheus-pve-exporter)
  - [Phase 3: Loki](#phase-3-loki)
  - [Phase 4: Alloy](#phase-4-alloy)
  - [Phase 5: Validation](#phase-5-validation)
  - [Phase 6: Operations](#phase-6-operations)
  - [Troubleshooting](#troubleshooting)
  - [References](#references)

---

## Overview

Deploy the observability stack in this order:

1. kube-prometheus-stack
2. prometheus-pve-exporter
3. Loki
4. Alloy

The goal is a GitOps-managed, self-hosted monitoring stack with Prometheus Operator, Grafana, and logs via Loki. kube-prometheus-stack includes Prometheus, Alertmanager, Grafana, and exporters such as kube-state-metrics and node-exporter, so do not install those separately. Prometheus Operator uses CRDs (ServiceMonitor, PodMonitor, PrometheusRule) for discovery and rules.

---

## Current State (Audit 2026-02-05)

- Repo: wrapper charts + ArgoCD apps exist for `prometheus-crds` (using `prometheus-operator-crds` chart v26.0.1 / operator v0.88.1) and `kube-prometheus-stack` under `argocd/apps/cluster/`.
- Repo: `prometheus-pve-exporter` wrapper chart exists (chart v2.6.1 / app v3.8.0) and the ArgoCD app is enabled at `argocd/apps/cluster/prometheus-pve-exporter.yaml`.
- Repo: `kube-prometheus-stack` app uses `skipCrds: true`; CRDs are managed by `prometheus-crds` with server-side apply.
- Repo: SealedSecret `monitoring-pve-exporter` exists at `apps/cluster/secrets-cluster/monitoring-pve-exporter.sealedsecret.yaml` and is listed in `apps/cluster/secrets-cluster/kustomization.yaml`.
- Remaining: Loki, Alloy.
- Repo: `kube-prometheus-stack` values override core images to DHI variants and set `imagePullSecrets` to `kubernetes-dhi`.
- Repo: Grafana dashboard `10347` (Proxmox via Prometheus) is configured in `apps/cluster/kube-prometheus-stack/values.yaml`.
- Repo: `monitoring` namespace is defined in `apps/cluster/namespaces/values.yaml` (synced to cluster).
- Cluster: `monitoring` namespace present; `prometheus-crds` synced and CRDs installed.
- Cluster: `prometheus-pve-exporter` synced and healthy.
- Cluster: `kube-prometheus-stack` synced; Grafana pod running with `monitoring-grafana-admin` secret present. Prometheus and Alertmanager StatefulSets are ready; Prometheus/Alertmanager pods are running. kube-state-metrics and node-exporter are running; ServiceMonitors are present.
- Cluster: MinIO operator + tenant are deployed and TLS ingress is fixed (object storage available, Loki buckets/credentials not yet created).

---

## Architecture

- **Namespace:** `monitoring` (recommended) or a dedicated `observability` namespace.
- **Metrics:** Prometheus Operator + Prometheus + Alertmanager (kube-prometheus-stack).
- **Dashboards:** Grafana (from kube-prometheus-stack).
- **Proxmox metrics:** prometheus-pve-exporter (scraped by Prometheus).
- **Logs:** Loki (Grafana Loki Helm chart in the grafana/loki repo).
- **Agents:** Alloy (Grafana Alloy Helm chart) for log/metric pipelines.

---

## Prerequisites

- Namespace chosen: `monitoring` (cluster-scope).
- Ensure `monitoring` namespace is applied from `apps/cluster/namespaces/values.yaml`.
- Storage classes available for Prometheus and Grafana PVs (retain class recommended).
- SealedSecrets ready for PVE credentials and Grafana admin password.
  - Grafana admin secret path: `apps/cluster/secrets-cluster/monitoring-grafana-admin.sealedsecret.yaml`
  - Username standard: `monitoring_admin`
- DHI pull secret is available via reflector:
  - SealedSecret: `apps/cluster/secrets-cluster/kubernetes-dhi-pat.yaml`
  - Secret name: `kubernetes-dhi` (reflected to all namespaces)
- Harbor proxy caches exist for `dhi`, `hub`, `ghcr`, `quay`, and `k8s` via `apps/user/harbor/values.yaml`.
  - We still configure `imagePullSecrets` for `dhi.io` because DHI requires auth, even when pulling through the Harbor proxy cache.
- Create Loki S3 buckets and SealedSecret credentials (cluster app):
  - Buckets: `loki-chunks`, `loki-ruler`, `loki-admin`
  - Secret path: `apps/cluster/secrets-cluster/monitoring-loki-s3.sealedsecret.yaml`
  - Ingress and TLS strategy for Grafana (optional external access).

---

## Phase 1: kube-prometheus-stack

1. Create wrapper chart for CRDs at `apps/cluster/prometheus-crds/` using `prometheus-operator-crds` chart v26.0.1 (operator v0.88.1).
2. Add ArgoCD Application under `argocd/apps/cluster/prometheus-crds.yaml` with a sync-wave before the stack (e.g., 25 < 30).
3. Create wrapper chart at `apps/cluster/kube-prometheus-stack/`.
4. Add ArgoCD Application under `argocd/apps/cluster/kube-prometheus-stack.yaml`.
5. Configure values:
   - Enable Prometheus and Alertmanager with persistent storage.
   - Enable Grafana with persistent storage and set admin password via SealedSecret.
   - Import Grafana dashboard `10347` (Proxmox via Prometheus) via `grafana.dashboards`.
   - Set retention (time and size) based on available storage.
   - Use DHI images and set `imagePullSecrets` to `kubernetes-dhi` for DHI pulls.
6. Enable ServiceMonitor/PodMonitor discovery for custom exporters (pve-exporter) and ensure label selectors match the release label.
7. Manage CRDs via GitOps (the chart installs CRDs and does not remove them on uninstall).

Example (local only; do not commit unsealed secrets):

```bash
export GRAFANA_ADMIN_USER="monitoring_admin"
export GRAFANA_ADMIN_PASSWORD="$(openssl rand -base64 24)"

kubectl create secret generic monitoring-grafana-admin -n monitoring \
  --from-literal=admin-user="$GRAFANA_ADMIN_USER" \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml > /tmp/monitoring-grafana-admin.yaml

kubeseal --format yaml < /tmp/monitoring-grafana-admin.yaml > \
  apps/cluster/secrets-cluster/monitoring-grafana-admin.sealedsecret.yaml

rm /tmp/monitoring-grafana-admin.yaml
```

Add the sealed secret to `apps/cluster/secrets-cluster/kustomization.yaml` after sealing.

---

## Phase 1.5: grafana-mcp (Optional)

Deploy `grafana-mcp` as an internal service in the `monitoring` namespace so MCP-capable
clients can manage Grafana (dashboards, alert rules, datasources, etc.) via a service
account token.

Repo additions:

- Wrapper chart: `apps/cluster/grafana-mcp/`
  - Upstream: `grafana-community/grafana-mcp` chart `0.5.0` (app `0.9.0`)
  - Image (DHI proxy cache): `harbor.m0sh1.cc/dhi/grafana-mcp:0.9.0`
- ArgoCD Application: `argocd/apps/cluster/grafana-mcp.yaml` (sync-wave 35; after kube-prometheus-stack)

### Grafana Connection

Grafana is provided by kube-prometheus-stack and exposed internally as:

- Service: `kube-prometheus-stack-grafana` (namespace `monitoring`)
- URL used by grafana-mcp: `http://kube-prometheus-stack-grafana.monitoring`

### Credentials (SealedSecret)

Do NOT commit plaintext tokens. Create a Grafana service account token and store it as a
SealedSecret in the `monitoring` namespace, then reference it from
`apps/cluster/grafana-mcp/values.yaml` via `grafana.apiKeySecret`.

Suggested secret:

- name: `grafana-mcp-api-key`
- key: `grafana-mcp-api-key`

Example workflow (local only; do not commit unsealed secrets):

```bash
export GRAFANA_MCP_TOKEN="<Grafana service account token>"

kubectl create secret generic grafana-mcp-api-key -n monitoring \
  --from-literal=grafana-mcp-api-key="$GRAFANA_MCP_TOKEN" \
  --dry-run=client -o yaml > /tmp/grafana-mcp-api-key.yaml

kubeseal --format yaml < /tmp/grafana-mcp-api-key.yaml > \
  apps/cluster/secrets-cluster/monitoring-grafana-mcp-api-key.sealedsecret.yaml

rm /tmp/grafana-mcp-api-key.yaml
```

Then:

1. Add the sealed secret to `apps/cluster/secrets-cluster/kustomization.yaml`.
2. Set `grafana-mcp.grafana.apiKeySecret.name` and `.key` in `apps/cluster/grafana-mcp/values.yaml`.

### Transport Note (Kubernetes)

By default, `grafana-mcp` can start in stdio mode and exit immediately in Kubernetes.
In this repo we force SSE transport (listening on `0.0.0.0:8000`) via
`apps/cluster/grafana-mcp/values.yaml` (`extraArgs`).

---

## Phase 2: prometheus-pve-exporter

1. Wrapper chart created at `apps/cluster/prometheus-pve-exporter/` pinned to `christianhuth/prometheus-pve-exporter` chart v2.6.1 (app v3.8.0).
2. ArgoCD Application created at `argocd/apps/cluster/prometheus-pve-exporter.yaml` (sync-wave after kube-prometheus-stack; namespace `monitoring`).
3. SealedSecret `monitoring-pve-exporter` exists at `apps/cluster/secrets-cluster/monitoring-pve-exporter.sealedsecret.yaml` and is listed in `apps/cluster/secrets-cluster/kustomization.yaml`. For token auth include `tokenName` + `tokenValue`; for password auth include `password`. Set `pveUser` (e.g., `pve-exporter@pve`) in wrapper values.
4. Token format note: full token is `user@realm!tokenname`; set `pveUser` to `user@realm`, `tokenName` to the suffix, and `tokenValue` to the secret string. One token can be used across all PVE nodes.
5. Configure exporter to point at Proxmox API endpoints and set `pveVerifySsl` based on cert trust. For `pveTargets`, use bare hosts/IPs (no scheme, no port).
6. ServiceMonitor enabled with label `release: kube-prometheus-stack`; `pveTargets` is a placeholder list until endpoints are defined.
7. Use `/pve` with `target` and `module` parameters for node/cluster metrics; `/metric` exposes exporter metrics.
8. If API load is high, consider disabling the `config` collector.
9. Validate PVE targets appear in Prometheus.

10. Grafana: if you use `grafana.dashboards.*` (gnetId) in kube-prometheus-stack, also configure `grafana.dashboardProviders` or Grafana will download JSON but not provision it.

In this repo, we avoid runtime downloads for dashboard 10347 and instead render it as a ConfigMap:

- Template: `apps/cluster/kube-prometheus-stack/templates/grafana-dashboard-proxmox-via-prometheus.yaml`
- Provider: `kube-prometheus-stack.grafana.dashboardProviders` points at `/tmp/dashboards/proxmox` and provisions into the Grafana folder `Proxmox`.

- <https://artifacthub.io/packages/helm/christianhuth/prometheus-pve-exporter>

---

## Phase 3: Loki

1. Use the Helm chart from `grafana/loki` (not the deprecated loki-distributed chart).
2. Pick deployment mode:
   - **Monolithic** for small homelab scale and meta-monitoring.
   - **Simple scalable** for a balance of scale and simplicity.
   - **Microservices** only if you need full HA and large scale.
3. Configure object storage for indexes and chunks.
   - MinIO is suitable; filesystem storage is not recommended for microservices mode.
   - Buckets: `loki-chunks`, `loki-ruler`, `loki-admin`.
   - Store S3 credentials in `apps/cluster/secrets-cluster/monitoring-loki-s3.sealedsecret.yaml`.
   - Add the sealed secret to `apps/cluster/secrets-cluster/kustomization.yaml` after sealing.
4. Enable ServiceMonitor for Loki metrics.
5. Add Grafana data source for Loki (via kube-prometheus-stack values).

---

## Phase 4: Alloy

1. Use the Grafana Alloy Helm chart.
2. Configure Alloy to send logs to Loki and metrics to Prometheus (or remote_write).
3. Store Alloy configuration in values.yaml and roll updates via GitOps (Helm upgrade in ArgoCD).
4. If using Kustomize configMapGenerator, avoid hashed names that prevent Helm from detecting changes; prefer static ConfigMaps or an annotation-based reload.
5. If Alloy replaces any existing log agent, disable the redundant agent.

---

## Phase 5: Validation

1. Verify all pods Healthy/Synced in ArgoCD.
2. Check Prometheus targets for kube-state-metrics, node-exporter, and pve-exporter.
3. Validate Loki readiness and query logs from Grafana.
4. Confirm Alloy pipelines are shipping logs/metrics.

---

## Phase 6: Operations

- Pin chart versions and track upgrades in `docs/history.md`.
- Back up Prometheus and Grafana PVCs.
- Keep CRDs in sync during chart upgrades.
- Use least-privilege PVEAuditor credentials.

---

## Troubleshooting

- **No PVE metrics:** check PVE API credentials and ServiceMonitor selectors.
- **No Loki logs:** verify Alloy pipeline and Loki gateway/service.
- **Grafana empty:** ensure data sources are configured and Prometheus is scraping targets.

---

## References

- <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
- <https://github.com/prometheus-pve/prometheus-pve-exporter>
- <https://github.com/grafana/loki/tree/main/production/helm/loki>
- <https://artifacthub.io/packages/helm/grafana/loki>
- <https://artifacthub.io/packages/helm/grafana/alloy>
- <https://prometheus-operator.dev/docs/getting-started/introduction/>
- <https://grafana.com/docs/loki/latest/setup/install/helm/>
- <https://grafana.com/docs/loki/latest/get-started/overview/>
- <https://grafana.com/docs/alloy/latest/set-up/install/kubernetes/>
- <https://grafana.com/docs/alloy/latest/>
