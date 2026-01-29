# CloudNative-PG Managed Roles Issue

**Date:** 2026-01-17
**Status:** ✅ Resolved (manual intervention required)
**Impact:** Critical - All applications using cnpg-main cluster could not authenticate

## Problem Statement

The CloudNative-PG operator failed to automatically create PostgreSQL roles defined in the cluster's `managed.roles` specification, causing all dependent applications to fail database authentication.

## Symptoms

- HarborGuard: `Authentication failed against database server, the provided database credentials for 'harborguard' are not valid`
- All CNPG Database resources showing: `ERROR: role "X" does not exist (SQLSTATE 42704)`
- Database connections failing despite correct credentials in SealedSecrets
- CNPG Cluster status showing `managedRolesStatus: {}` (empty)

## Root Cause

The CNPG operator did not reconcile managed roles from the cluster spec into actual PostgreSQL user accounts. The roles were defined in:

```yaml
spec:
  managed:
    roles:
      - name: harborguard
        ensure: present
        comment: HarborGuard security scanning platform
        login: true
        inherit: true
        passwordSecret:
          name: harborguard-db-secret
```

But the PostgreSQL database only contained default roles:

- `postgres` (superuser)
- `app` (bootstrap user)
- `streaming_replica` (replication)

**Affected Roles:**

- `harborguard` - HarborGuard application
- `harbor` - Harbor registry
- `gitea` - Gitea SCM
- `semaphore` - Semaphore CI/CD

## Investigation Steps

1. Checked DATABASE_URL environment variable - ✅ Correctly formatted
2. Verified SealedSecret decryption - ✅ Password extracted correctly
3. Queried PostgreSQL users - ❌ Roles did not exist
4. Checked CNPG Cluster status - ⚠️ `managedRolesStatus: {}`
5. Reviewed CNPG operator logs - No errors related to role creation

## Solution (Manual Intervention)

Created roles and databases manually via psql in cnpg-main-1 pod:

```bash
# HarborGuard
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE ROLE harborguard WITH LOGIN PASSWORD '<password>' INHERIT;"
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE DATABASE harborguard WITH OWNER harborguard TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C';"

# Harbor
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE ROLE harbor WITH LOGIN PASSWORD '<password>' INHERIT;"
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE DATABASE harbor WITH OWNER harbor TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C';"

# Gitea
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE ROLE gitea WITH LOGIN PASSWORD '<password>' INHERIT;"
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE DATABASE gitea WITH OWNER gitea TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C';"

# Semaphore
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE ROLE semaphore WITH LOGIN PASSWORD '<password>' INHERIT;"
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "CREATE DATABASE semaphore WITH OWNER semaphore TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C';"
```

### Result

After creating roles and restarting application pods:

```text
✅ HarborGuard: Connected successfully, migrations applied
✅ Harbor: Database accessible (existing databases already present)
✅ Gitea: Database created successfully
✅ Semaphore: Database created successfully
```

## Automation Implementation

To prevent this issue from recurring, implemented a Kubernetes Job that runs as an init step to ensure roles exist before applications start.

**File:** `apps/cluster/cloudnative-pg/templates/init-roles-job.yaml`

This job:

1. Runs after CNPG cluster is healthy (sync-wave: "11")
2. Reads passwords from the same secrets CNPG references
3. Creates roles idempotently (`CREATE ROLE IF NOT EXISTS`)
4. Creates databases with proper ownership and encoding
5. Runs to completion, then ArgoCD prunes it on next sync

## Prevention Strategy

1. **Immediate:** Init Job ensures roles exist before app sync-wave "15"
2. **Short-term:** Monitor CNPG operator reconciliation logs
3. **Long-term:**
   - Report issue to CloudNative-PG project if confirmed bug
   - Consider switching to bootstrap initdb if managed roles remain unreliable
   - Evaluate alternatives like postgres-operator if issues persist

## Verification Commands

```bash
# Check roles exist
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c "SELECT usename FROM pg_user ORDER BY usename;"

# Check databases and ownership
kubectl exec -n apps cnpg-main-1 -- psql -U postgres -c \
  "SELECT datname, datdba::regrole AS owner FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres' ORDER BY datname;"

# Test connection as app user
kubectl exec -n apps cnpg-main-1 -- psql -U harborguard -d harborguard -c "SELECT version();"
```

## Related Resources

- CNPG Cluster: `apps/cnpg-main`
- Operator Namespace: `cnpg-system`
- Chart: `apps/cluster/cloudnative-pg/`
- Secrets: `apps` namespace (SealedSecrets)

## Timeline

- **2026-01-16 07:11:** HarborGuard SealedSecret created
- **2026-01-17 09:32:** Issue discovered during HarborGuard troubleshooting
- **2026-01-17 09:33:** Roles created manually
- **2026-01-17 09:32:** HarborGuard operational after pod restart
- **2026-01-17 09:35:** Automation implemented (init-roles-job.yaml)

## Lessons Learned

1. **Trust but verify:** Even declarative operators may have reconciliation bugs
2. **Explicit is better than implicit:** Init containers/jobs provide guaranteed ordering
3. **Defense in depth:** Secrets existing ≠ roles created - validate end-to-end
4. **Monitor operator health:** CNPG operator logs should be part of observability stack

## References

- [CloudNative-PG Managed Roles Docs](https://cloudnative-pg.io/documentation/current/declarative_role_management/)
- [PostgreSQL Role Management](https://www.postgresql.org/docs/current/user-manag.html)
- Issue Report: TBD (if filed with CNPG project)
