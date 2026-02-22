# Security Hardening Wave Comparison — 2026-02-22

## Snapshot

- Comparison generated at: `2026-02-22T22:43:33Z` (UTC)
- Kubernetes context: `default`
- Scope: `Harbor`, `Authentik`, `Browserless-Chromium`, `Woodpecker`
- Data sources:
  - User-run CLI baseline: `trivy kubernetes --report summary --timeout 15m --disable-node-collector` at `2026-02-22T21:27:57+01:00`
  - Live CRDs:
    - `configauditreports.aquasecurity.github.io`
    - `vulnerabilityreports.aquasecurity.github.io`

## Important Comparison Note

- The baseline CLI summary includes vulnerabilities and misconfigurations for many object kinds.
- The post-change live matrix below is aggregated from `ConfigAuditReport` resources for current workload objects.
- These two sources are not a 1:1 metric model; treat the comparison as directional and evidence-backed, not mathematically equivalent.

## Baseline Excerpts (CLI Summary at 2026-02-22T21:27:57+01:00)

### Harbor

- `Deployment/harbor-core`: vulnerabilities `C3 H15 M31 L3`; misconfigurations `H1 M1 L4`
- `Deployment/harbor-registry`: vulnerabilities `C7 H33 M56 L6`; misconfigurations `H2 M2 L6`
- `Deployment/harbor-jobservice`: vulnerabilities `C3 H15 M29 L3`; misconfigurations `H1 M1 L4`
- `Deployment/harbor-portal`: vulnerabilities `C3 H16 M29 L4`; misconfigurations `H1 M1 L4`
- `StatefulSet/harbor-trivy`: vulnerabilities `C4 H19 M34 L5`; misconfigurations `H1 M1 L4`

### Authentik

- `Deployment/authentik-server`: vulnerabilities `C4 H58 M226 L188 U10`; misconfigurations `C4 H6 M5 L14`
- `Deployment/authentik-worker`: vulnerabilities `C4 H58 M226 L188 U10`; misconfigurations `C4 H6 M5 L14`

### Browserless-Chromium

- `Deployment/browserless-chromium`: vulnerabilities `H5 M31 L64`; misconfigurations `H3 M4 L11`

### Woodpecker

- `StatefulSet/woodpecker-agent`: vulnerabilities `C1 H3`; misconfigurations `H1 M1 L4`
- `StatefulSet/woodpecker-server`: vulnerabilities `C1 H3 L1`; misconfigurations `H1 M1 L4`

## Post-Change Live Matrix (ConfigAuditReport Aggregation)

### Aggregate by Workload

| Workload | Reports | Latest Report (UTC) | Critical | High | Medium | Low |
|---|---:|---|---:|---:|---:|---:|
| Harbor | 6 | 2026-02-22T22:43:00Z | 0 | 7 | 10 | 16 |
| Authentik | 2 | 2026-02-22T21:07:57Z | 0 | 0 | 2 | 4 |
| Browserless-Chromium | 1 | 2026-02-22T21:38:35Z | 0 | 0 | 1 | 2 |
| Woodpecker | 2 | 2026-02-19T08:55:37Z | 0 | 0 | 3 | 4 |

### Matched Live Reports

#### Harbor

- `apps/cronjob-harbor-scanner` (`2026-02-12T22:41:21Z`) summary `C0 H1 M4 L4`
- `apps/replicaset-harbor-core-66f995487b` (`2026-02-22T22:37:20Z`) summary `C0 H1 M1 L2`
- `apps/replicaset-harbor-jobservice-5b4d6f9cb9` (`2026-02-22T22:37:20Z`) summary `C0 H1 M1 L2`
- `apps/replicaset-harbor-portal-5bbb45db7d` (`2026-02-22T22:43:00Z`) summary `C0 H1 M1 L2`
- `apps/replicaset-harbor-registry-7cc5fd9bb8` (`2026-02-22T22:37:20Z`) summary `C0 H2 M2 L4`
- `apps/statefulset-harbor-trivy` (`2026-02-03T09:13:04Z`) summary `C0 H1 M1 L2`

#### Authentik

- `apps/replicaset-authentik-server-6cd569bc5c` (`2026-02-22T21:07:57Z`) summary `C0 H0 M1 L2`
- `apps/replicaset-authentik-worker-6498954cfc` (`2026-02-22T21:07:57Z`) summary `C0 H0 M1 L2`

#### Browserless-Chromium

- `apps/replicaset-browserless-chromium-5b878b6b9` (`2026-02-22T21:38:35Z`) summary `C0 H0 M1 L2`

#### Woodpecker

- `woodpecker/statefulset-woodpecker-agent` (`2026-02-19T08:55:37Z`) summary `C0 H0 M2 L2`
- `woodpecker/statefulset-woodpecker-server` (`2026-02-19T08:55:37Z`) summary `C0 H0 M1 L2`

## Remaining Failing Check Themes (Live)

- Harbor: `AVD-KSV-0014` (root filesystem not read-only), `AVD-KSV-0012` (runs as root), `AVD-KSV-0125` (trusted registries), `AVD-KSV-0020/0021` (UID/GID <= 10000)
- Authentik: `AVD-KSV-0125`, `AVD-KSV-0020`, `AVD-KSV-0021`
- Browserless-Chromium: `AVD-KSV-0125`, `AVD-KSV-0020`, `AVD-KSV-0021`
- Woodpecker: `AVD-KSV-0125`, `AVD-KSV-0020`, `AVD-KSV-0021`

## VulnerabilityReport Coverage Status (Live)

- Matching `VulnerabilityReport` objects for these four workloads at snapshot time: `0`
- Interpretation: vulnerability scanning visibility for these targets is currently incomplete in CRD data (coverage gap), so vulnerability deltas cannot be claimed from CRDs yet.

## Freshness Against SLA (24h)

- Authentik ConfigAudit freshness: `PASS`
- Browserless-Chromium ConfigAudit freshness: `PASS`
- Harbor ConfigAudit freshness: `MIXED` (new ReplicaSet reports fresh; older CronJob/StatefulSet reports stale)
- Woodpecker ConfigAudit freshness: `FAIL` (latest reports from `2026-02-19T08:55:37Z`)

## Changes Included In This Wave

- `48346f7f`: `hardening(woodpecker): use trusted Harbor mirror images`
- `6445b14f`: `hardening(woodpecker): set init container resources`
- `7566849e`: `network-policies(traefik): allow headlamp backend port 4466`
- `474b4cf2`: `fix(garage-webui): declare port on authentik externalname service`
- `128c2d8c`: `trivy-operator: add woodpecker registry scan secret mapping`

## Decision-Ready Next Checks

1. Re-check Woodpecker ConfigAudit after the next Trivy scan cycle to confirm `AVD-KSV-0125` drops for mirrored images.
2. Decide whether to raise runtime UIDs/GIDs for Authentik/Browserless/Woodpecker above `10000` or document permanent exceptions.
3. Keep Harbor read-only-rootfs as staged work; require service continuity test gates before enforcing globally.
