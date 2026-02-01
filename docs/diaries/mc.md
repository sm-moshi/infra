# mc CLI Guide for RustFS

**Date:** 2026-02-01
**Status:** ✅ Verified (port-forward + LAN endpoints)

## Purpose

Use MinIO `mc` to interact with RustFS S3 for bucket/object checks and CNPG
backups.

## Prereqs

- kubectl access to the cluster
- `mc` installed (`mc --version`)
- RustFS credentials from `rustfs-root-credentials` (namespace `rustfs`)

## Quickstart (local workstation via port-forward)

1. Port-forward the RustFS service:

```bash
kubectl port-forward -n rustfs svc/rustfs 9000:9000
```

2. Fetch credentials:

```bash
kubectl get secret -n rustfs rustfs-root-credentials \
  -o jsonpath='{.data.RUSTFS_ACCESS_KEY}' | base64 -d
kubectl get secret -n rustfs rustfs-root-credentials \
  -o jsonpath='{.data.RUSTFS_SECRET_KEY}' | base64 -d
```

3. Configure an alias:

```bash
mc alias set rustfs http://127.0.0.1:9000 <access-key> <secret-key>
```

## Common commands

```bash
mc ls rustfs
mc ls rustfs/cnpg-backups/cnpg-main/
mc ls --recursive rustfs/cnpg-backups/cnpg-main/wals/
mc ls --recursive rustfs/cnpg-backups/cnpg-main/base/
mc mb rustfs/<bucket-name>
mc cp ./file rustfs/<bucket>/path/
mc alias rm rustfs
```

## In-cluster endpoint

- RustFS service: `http://rustfs.rustfs.svc:9000`

## Notes

- CNPG backups land under `s3://cnpg-backups/cnpg-main/`.
- Keep credentials in SealedSecrets; do not write secrets to Git.
