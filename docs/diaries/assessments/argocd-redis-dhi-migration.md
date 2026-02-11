# ArgoCD Redis DHI Migration Assessment

**Date:** 2026-02-09
**Status:** Assessment Complete — Ready for Implementation

## Current State

**Deployment:** Single Redis instance (non-HA, no persistence)
**Current Image:** `docker.io/redis:8.4.0-alpine3.22`
**Usage:** Caching + session storage only
**Location:** `apps/cluster/argocd/values.yaml` (lines 231-243)

## Migration Work Required

### File Changes

Update `apps/cluster/argocd/values.yaml`:

```yaml
redis:
  enabled: true
  image:
    registry: dhi.io          # ADD
    repository: redis         # CHANGE (from docker.io/redis)
    tag: "8.2"       # CHANGE (from 8.4.0-alpine3.22)
    pullPolicy: IfNotPresent
  imagePullSecrets:           # ADD
    - name: kubernetes-dhi
```

### Estimated Effort

- **Code changes:** 5 minutes
- **Testing/validation:** 10 minutes
- **Total:** 10-15 minutes

### Commit Message

```text
feat(argocd): migrate internal Redis to DHI hardened image

- Switch from docker.io/redis:8.4.0-alpine3.22 to dhi.io/redis:8.2
- Add DHI imagePullSecrets for registry authentication
- Improves security posture (0 CVEs vs upstream unknown)
- Uses glibc-based image for better DNS compatibility
```

## Risk Assessment

| Risk Factor | Level | Details |
|-------------|-------|---------|
| **Data Loss** | 🟢 LOW | Cache-only; no persistent data in Redis. ArgoCD will repopulate cache on restart. |
| **Downtime** | 🟡 MEDIUM | ArgoCD unavailable 30-60s during pod restart. UI and API will be briefly inaccessible. |
| **Compatibility** | 🟢 LOW | Redis 8.2→8.4 is backward compatible for basic GET/SET/PUBSUB operations. |
| **Rollback** | 🟢 EASY | Single image change — revert values.yaml and ArgoCD sync. |
| **CVE Exposure** | 🟢 IMPROVED | DHI: 0 CVEs vs upstream: unknown/untracked. |

## Mitigation Strategies

1. **Schedule during low-activity period** — evenings/weekends when fewer users accessing ArgoCD
2. **No manual intervention needed** — ArgoCD auto-reconnects after Redis restart
3. **No workload impact** — only ArgoCD UI/API affected, running applications unaffected
4. **Quick rollback** — if issues arise, revert single values.yaml line and re-sync

## Trade-off Analysis

### Pros

- ✅ **Hardened image** — 0 CVEs at time of publishing
- ✅ **glibc-based** — Better DNS compatibility than Alpine/musl (no AAAA/NXDOMAIN issues)
- ✅ **Consistent strategy** — Aligns with cluster-wide DHI migration
- ✅ **SBOM available** — Complete provenance and attestation

### Cons

- ⚠️ **Version downgrade** — 8.4→8.2 (minor gap, features unused by ArgoCD)
- ⚠️ **Brief downtime** — 30-60s ArgoCD unavailability during migration
- ⚠️ **License still RSAL** — Not migrating to open-source Valkey

## Alternative: Valkey Migration

**Why NOT Valkey for ArgoCD internal Redis?**

The ArgoCD Helm chart has Redis image names hardcoded in templates:

- Would require custom patches to the upstream chart
- Or sidecar replacement pattern (complex)
- Higher risk and effort than simple image swap

**Verdict:** For internal ArgoCD cache only, DHI Redis 8.2.x is acceptable. Valkey migration would be better but requires chart modifications.

## Decision

| Attribute | Value |
|-----------|-------|
| **Status** | Assessment complete, ready to implement |
| **Priority** | LOW — not blocking, opportunistic |
| **Risk Level** | LOW |
| **Effort** | LOW (10-15 minutes) |
| **Recommended Window** | Evening/weekend to minimize ArgoCD downtime |
| **Rollback Time** | <5 minutes |

## Next Steps (When Scheduled)

1. Choose low-activity time window
2. Update `apps/cluster/argocd/values.yaml`
3. Commit and push to Git
4. ArgoCD will auto-sync and restart Redis pod
5. Verify ArgoCD UI accessible and responsive
6. Monitor for 15-30 minutes

## References

- DHI Redis catalog: <https://hub.docker.com/hardened-images/catalog/dhi/redis>
- ArgoCD values file: `apps/cluster/argocd/values.yaml`
- DHI migration tracker: `docs/diaries/dhi-catalog.md`
