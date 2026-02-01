# CloudNativePG Implementation

**Date Range:** 2026-01-17 to 2026-02-01
**Status:** ✅ Running (WAL + base backups verified in RustFS)

## Goals

- Deploy CNPG operator and a shared cluster in the apps namespace
- Use GitOps-only backups via the Barman Cloud plugin to RustFS
- Provide a repeatable role/database bootstrap path for app users

## Architecture Overview

- Operator: `apps/cluster/cloudnative-pg` (wrapper chart), namespace `cnpg-system`
- Cluster: `cnpg-main` in `apps` namespace
- Storage: Proxmox CSI (data: nvme-fast, WAL: nvme-general)
- Backups: Barman Cloud plugin (`barman-cloud.cloudnative-pg.io`)
- ObjectStore CR: `cnpg-backups` (RustFS S3 endpoint)
- Scheduled backup: `cnpg-main-backup` (cron `0 0 2 * * *`)

## Implementation Summary

- Installed CNPG operator and Barman Cloud plugin via wrapper chart
- Switched backups to plugin-only flow (ObjectStore + plugins block)
- Configured RustFS endpoint: `http://rustfs.rustfs.svc:9000`
- Enabled WAL archiving with zstd compression
- Enabled base backups with snappy compression (zstd is WAL-only)
- Added `ScheduledBackup` using plugin configuration
- Added a GitOps-triggered one-off `Backup` CR for manual verification
- Implemented init-roles Job to bootstrap application roles and databases

## Managed Roles Issue (2026-01-17)

**Problem:** CNPG did not reconcile `managed.roles` into actual PostgreSQL
roles, so applications could not authenticate. `managedRolesStatus` remained
empty and only default roles existed (`postgres`, `app`, `streaming_replica`).

**Symptoms:**

- Application DB auth failures (HarborGuard, Harbor, Gitea, Semaphore)
- CNPG Database resources failing with missing role errors

**Resolution:**

1. Manual role/database creation via `psql` (temporary unblock)
2. Added `init-roles` Job to `apps/cluster/cloudnative-pg/templates/`:
   - Runs after cluster is healthy (sync-wave 11)
   - Reads passwords from the same SealedSecrets
   - Creates roles/databases idempotently
   - Honors login flags for non-login roles

This ensures GitOps ordering and prevents future role drift.

## Backup Verification (2026-02-01)

- RustFS bucket `cnpg-backups` exists and accepts writes
- WALs archived to `s3://cnpg-backups/cnpg-main/wals/`
- Manual `Backup` CR completed successfully
- Base backup written to `s3://cnpg-backups/cnpg-main/base/<timestamp>/`

**Commands used:**

```bash
kubectl get backup -n apps cnpg-main-backup-20260201-1
mc ls --recursive rustfs/cnpg-backups/cnpg-main/
```

## Current State

- CNPG operator + plugin running in `cnpg-system`
- Cluster `cnpg-main` healthy in `apps`
- Scheduled backups configured and active
- Manual backup trigger disabled after verification
- Managed roles list is empty unless roles are explicitly enabled

## Follow-ups

- Enable per-app roles only when apps/secrets are ready
- Keep `cnpg-backup-credentials` synced with RustFS credentials
- Consider snapshot backups later with Proxmox CSI (out of scope for now)
