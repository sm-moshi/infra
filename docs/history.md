# Infrastructure Change History

This file records notable infra changes (especially chart version pins / upgrades)
so we can track what changed over time without trawling git history.

---

## 2026-02-06

- Added Grafana Loki (observability logs) wrapper chart and ArgoCD app:
  - Wrapper: `apps/cluster/loki/`
  - Upstream chart: `grafana/loki` `6.52.0` (app `3.6.4`)
  - Image: `dhi.io/loki:3.6.4-debian13`
