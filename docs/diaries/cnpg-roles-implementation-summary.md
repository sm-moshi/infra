# CNPG Role Initialization - Implementation Summary

**Date:** 2026-01-17
**Status:** ✅ Complete - Ready for Git commit and ArgoCD sync

## Problem Solved

CloudNative-PG operator failed to automatically create PostgreSQL roles defined in the cluster's `managed.roles` specification, causing authentication failures for all dependent applications (HarborGuard, Harbor, Gitea, Semaphore).

## Solution Implemented

### 1. Immediate Fix (Manual)

Created missing PostgreSQL roles and databases directly in `cnpg-main-1` pod:

```bash
# Created roles: harborguard, harbor, gitea, semaphore
# Created databases with proper ownership and encoding (UTF8, C/C collation)
```

**Result:** All applications now have database access ✅

### 2. Automation (Helm Chart)

Added `init-roles-job.yaml` to `apps/cluster/cloudnative-pg/templates/`:

- **When:** Runs at sync-wave "11" (after cluster, before apps)
- **What:** Creates roles and databases idempotently using PostgreSQL `IF NOT EXISTS`
- **How:** Reads passwords from same SealedSecrets CNPG references
- **Cleanup:** ArgoCD hook-delete-policy removes old jobs automatically

**Chart version:** 0.2.17 → 0.2.18

### 3. Documentation

Created comprehensive documentation:

- **`docs/cnpg-managed-roles-issue.md`** - Complete incident report with timeline, root cause, solution, and prevention
- **`apps/cluster/cloudnative-pg/CHANGELOG-0.2.18.md`** - Chart changes, testing instructions, rollback procedure
- **`docs/checklist.md`** - Updated Phase 5 with completed work

## Files Changed

```text
Modified:
  apps/cluster/cloudnative-pg/Chart.yaml          (version bump)
  docs/checklist.md                                (Phase 5 update)

Added:
  apps/cluster/cloudnative-pg/templates/init-roles-job.yaml
  apps/cluster/cloudnative-pg/CHANGELOG-0.2.18.md
  docs/cnpg-managed-roles-issue.md
```

## Verification Completed

✅ All PostgreSQL roles exist:

```text
app, gitea, harbor, harborguard, postgres, semaphore, streaming_replica
```

✅ All databases created with correct ownership:

```text
app (app), gitea (gitea), harbor (harbor), harborguard (harborguard), semaphore (semaphore)
```

✅ HarborGuard operational:

```text
[DB] Database connection successful
[DB] Migrations applied successfully
Starting HarborGuard...
✓ Ready in 139ms
```

✅ Chart lints successfully:

```bash
helm lint apps/cluster/cloudnative-pg/
# 1 chart(s) linted, 0 chart(s) failed
```

## Next Steps

1. **Commit changes:**

   ```bash
   git add apps/cluster/cloudnative-pg/ docs/
   git commit -m "fix(cnpg): add init-roles Job to ensure managed roles exist

   - Manually created missing roles: harborguard, harbor, gitea, semaphore
   - Added init-roles Job (sync-wave 11) for automation
   - Fixes CNPG operator not reconciling managed roles from secrets
   - HarborGuard now operational with database access
   - Documented in docs/cnpg-managed-roles-issue.md

   Closes: HarborGuard authentication failures
   Chart version: 0.2.17 -> 0.2.18"
   ```

2. **Push and monitor:**

   ```bash
   git push origin main
   # Watch ArgoCD sync cloudnative-pg application
   # Monitor init-roles Job execution: kubectl get jobs -n apps -w
   ```

3. **Verify automation:**

   ```bash
   # Check job logs
   kubectl logs -n apps -l app.kubernetes.io/component=init-roles --tail=100

   # Confirm no application regressions
   kubectl get pods -n apps -l 'app.kubernetes.io/name in (harborguard,harbor,gitea,semaphore)'
   ```

4. **Optional - Report upstream:**
   - If CNPG managed roles reconciliation remains broken, file issue at:
     <https://github.com/cloudnative-pg/cloudnative-pg/issues>

## Rollback Plan

If init-roles Job causes issues:

1. **Disable Job:** Set `cnpg.cluster.enabled: false` temporarily in values.yaml
2. **Delete Job:** `kubectl delete job -n apps cnpg-main-init-roles`
3. **Revert commit:** `git revert <commit-sha>`
4. **Sync ArgoCD:** Manual sync or wait for auto-sync

Roles/databases already created manually will persist (safe).

## Impact Assessment

- **Risk:** Low - Job runs idempotently, won't break existing roles
- **Benefit:** High - Prevents future role creation failures
- **Dependencies:** None - Applications already have database access
- **Downtime:** None - Job runs before app sync-wave

## Memory Bank Status

Progress updated:

- ✅ **Done:** 10 items (diagnosis, manual fix, automation, documentation)
- 🔄 **Next:** 4 items (commit, monitor, verify, optional upstream report)

## Success Criteria Met

- [x] All PostgreSQL roles created manually
- [x] All databases accessible by applications
- [x] HarborGuard operational and healthy
- [x] Automation implemented for future prevention
- [x] Comprehensive documentation written
- [x] Chart version bumped appropriately
- [x] Changes validated with helm lint
- [x] Rollback procedure documented

**Status: Ready for production deployment** 🚀
