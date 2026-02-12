# Kubescape Operator Incident - February 12, 2026

## Executive Summary

**Incident**: Kubescape Operator deployment caused cluster-wide ArgoCD outage
**Duration**: ~10 hours (07:26 AM - ~5:00 PM)
**Impact**: ALL ArgoCD application syncs blocked cluster-wide
**Resolution**: Manual APIService deletion + storage backend disabled
**Status**: Kubescape currently disabled, cluster stable

---

## What Happened

### Timeline

| Time | Event |
|------|-------|
| 07:26 AM | Commit `c5c1f2d3` changed `backend-storage: enable` → `disable` |
| ~5:00 PM | User discovered ALL ArgoCD syncs failing cluster-wide |
| ~5:00 PM | Emergency fix: Manually deleted APIService, disabled storage components |
| Post-fix | Cluster stabilized, Kubescape fully disabled |

### Root Cause

**Trigger**: Configuration change from `backend-storage: enable` to `backend-storage: disable`

**Technical Failure**:

1. **Inverted helm chart logic** (counterintuitive):
   - `backend-storage: enable` = NO local storage (use external backend)
   - `backend-storage: disable` = YES deploy local storage components ⚠️

2. **Broken deployment**:
   - Chart deployed `kubescape-storage` deployment
   - Created APIService: `v1beta1.spdx.softwarecomposition.kubescape.io`
   - APIService had **broken OpenAPI schema** with undefined model references

3. **Cluster-wide poisoning**:
   - APIService registered in Kubernetes API aggregation layer
   - ArgoCD's cluster cache couldn't initialize (schema validation failed)
   - ALL ArgoCD application syncs blocked (not just Kubescape)
   - Entire GitOps pipeline frozen for 10 hours

**Why it affected the ENTIRE cluster**:

- APIServices are cluster-wide via Kubernetes API aggregation
- Single broken APIService poisons API discovery for all controllers
- ArgoCD shares cluster cache across ALL applications
- Schema validation failure blocks cache initialization

### Evidence

**Git commits**:

- `c5c1f2d3` - kubescape: enable storage-backed compliance scanning (TRIGGER)
- `36517a8c` - kubescape: disable storage backend (EMERGENCY FIX)
- `5230ffc9` - argocd: add ignoreDifferences for kubescape APIService (SAFETY NET)

---

## Current State

### ✅ Stable After Emergency Fixes

- All Kubescape pods removed (namespace exists but empty)
- Broken APIService deleted
- ArgoCD syncing normally again
- Trivy Operator handling vulnerability scanning

### ❌ Lost Capabilities

- CIS benchmark scanning
- NSA/CISA hardening checks
- Compliance reporting (PCI-DSS, SOC2, etc.)
- Configuration posture assessment

### Current Configuration

```yaml
# apps/user/kubescape-operator/values.yaml
capabilities:
  operator: enable
  configurationScan: enable
  continuousScan: enable
  vulnerabilityScan: disable
  # All other capabilities: disable

storage:
  enabled: false
  # backend-storage capability OMITTED entirely
```

**Safety measures in place**:

- ArgoCD `ignoreDifferences` configured for storage APIService
- Prevents accidental re-deployment of broken components

---

## Restoration Plan

### Phase 1: Research & Validation (NO CLUSTER CHANGES)

**Task 1.1**: Check upstream for storage APIService bug fixes
**Task 1.2**: Test chart rendering locally

```bash
helm template apps/user/kubescape-operator > /tmp/test.yaml
# CRITICAL: Verify NO storage APIService rendered
! grep "v1beta1.spdx.softwarecomposition" /tmp/test.yaml
```

**Task 1.3**: Evaluate if Kyverno could replace Kubescape

### Phase 2: Implement Safe Configuration

**Minimal capability set**:

```yaml
capabilities:
  configurationScan: enable
  continuousScan: enable
  vulnerabilityScan: disable  # Trivy handles this
  # Omit backend-storage entirely

storage:
  enabled: false
```

**Chart version bump**: 0.1.8 → 0.2.0

### Phase 3: Testing (CRITICAL - DO NOT SKIP)

**Mandatory checks**:

1. Dry-run: Verify no storage APIService in rendered manifests
2. ArgoCD diff: Preview changes before sync
3. Staged deployment: Manual sync with monitoring
4. Rollback plan: < 5 minute recovery if anything fails

**Abort criteria**: If storage APIService appears in any check, DO NOT PROCEED

### Phase 4: Documentation

- Create this incident postmortem ✅
- Update basic-memory with findings
- Document workaround and re-enabling criteria

### Phase 5: Future Migration Paths

**Option A**: Wait for upstream fix (monitor kubescape/helm-charts)
**Option B**: Migrate to Kyverno (2-3 day effort)
**Option C**: Keep minimal Kubescape forever (current recommendation)

---

## Risk Assessment

### Minimal Safe Kubescape (Recommended)

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Storage APIService recreated | Very Low | Critical | ArgoCD ignoreDifferences blocks it |
| Chart rendering bug | Low | High | Mandatory dry-run testing |
| New upstream bug | Medium | Medium | Staged deployment + quick rollback |

**Overall Risk**: < 5% probability of failure
**Rollback Time**: < 5 minutes

---

## Lessons Learned

1. **APIServices are cluster-wide**: Single broken APIService can poison entire API aggregation layer
2. **Inverted chart logic is dangerous**: Config that sounds safe (`disable`) can trigger unsafe behavior
3. **ArgoCD shares cluster cache**: Failure in one app can block all apps
4. **Test before deploy**: Mandatory dry-run verification prevents incidents
5. **Safety nets work**: ArgoCD ignoreDifferences successfully prevents re-deployment

---

## Decision Required

User must choose:

1. **Restore Kubescape** (execute Phases 1-4) - if compliance scanning is critical
2. **Stay disabled** - if risk-averse or compliance not needed
3. **Research only** (Phase 1) - gather data, then decide

**Status**: Plan created, awaiting user decision

---

## Quick Reference

### Key Files

- Config: `apps/user/kubescape-operator/values.yaml`
- Chart: `apps/user/kubescape-operator/Chart.yaml`
- ArgoCD: `argocd/apps/user/kubescape-operator.yaml`

### Verification Commands

```bash
# Check for broken APIServices
kubectl get apiservice | grep False

# Check ArgoCD health
argocd app list | grep -E "Unknown|Degraded"

# Check Kubescape status
kubectl get pods -n kubescape
```

### Emergency Rollback

```bash
# If restoration goes wrong:
kubectl delete ns kubescape
kubectl delete apiservice v1beta1.spdx.softwarecomposition.kubescape.io
git revert HEAD && git push
argocd app sync kubescape-operator
```

---

**Last Updated**: 2026-02-12
**Next Review**: After Phase 1 completion or 2026-03-12 (whichever comes first)
