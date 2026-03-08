# Infrastructure Change History

This file records notable infra changes: chart version pins/upgrades,
temporary tag usage, and supply chain exceptions.

The `infra-guard supply-chain` guard checks for this file's existence.
For completed milestone tracking, see [done.md](done.md).

---

## 2026-02-06

- Added Grafana Loki (observability logs) wrapper chart and ArgoCD app:
  - Wrapper: `apps/cluster/loki/`
  - Upstream chart: `grafana/loki` `6.52.0` (app `3.6.4`)
  - Image: `dhi.io/loki:3.6.4`
