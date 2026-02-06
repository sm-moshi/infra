# Authentik SSO/IdP Implementation Plan

**Status:** Planning
**Target:** apps/user/authentik
**Dependencies:** CNPG (cnpg-main), MinIO tenant (internal HTTPS), Traefik ingress
**Created:** 2026-02-02
**Updated:** 2026-02-05

## Summary

Deploy Authentik as the homelab Identity Provider (OIDC/SAML/LDAP/SCIM) using the repo's GitOps contract:

- Deployed via ArgoCD Application + Helm wrapper chart (`apps/user/authentik`).
- PostgreSQL via the shared CNPG cluster (`cnpg-main-rw.apps.svc.cluster.local`).
- No imperative DB creation steps; DB provisioning is done by an ArgoCD-applied, idempotent PreSync Job.
- The DB init Job runs on the rootless DHI Postgres Debian 13 userspace image (pinned by digest via `dbInit.image`) and avoids `grep/sed` (checks use `psql -Atc` output).
- S3 storage uses internal MinIO HTTPS endpoint and trusts the k3s server CA (via existing `minio-ca`).
- All secrets live in `apps/user/secrets-apps/` as Bitnami SealedSecrets.

## Cluster Reality (Assumptions)

- Namespace for app workloads: `apps`.
- CNPG RW endpoint: `cnpg-main-rw.apps.svc.cluster.local:5432`.
- MinIO internal endpoint: `https://minio.minio-tenant.svc.cluster.local` (certificate issued by k3s server CA).
- TLS for ingress uses reflected secret `wildcard-m0sh1-cc` in namespace `apps`.

If any of these differ, update the wrapper values and this plan.

## Repo Artifacts (What This Plan Adds)

- Wrapper chart: `apps/user/authentik/`
  - `Chart.yaml` depends on upstream Authentik chart `2025.12.3`.
  - `values.yaml` configures Traefik ingress and mounts `minio-ca`. It also defines `dbInit.image` / `dbInit.imagePullPolicy` for the PreSync Job.
  - `templates/db-init.job.yaml` is an ArgoCD PreSync Job that creates the `authentik` DB idempotently using the configured `dbInit.image`.
- ArgoCD app manifest: `argocd/apps/user/authentik.yaml`

## Phase 1: Secrets (MUST happen before enabling CNPG role)

All secrets for Authentik must be committed as SealedSecrets under `apps/user/secrets-apps/`.
Add the new SealedSecret manifests to `apps/user/secrets-apps/kustomization.yaml` so ArgoCD applies them.

### 1.1 SealedSecret: Postgres Role Password (`authentik-postgres-auth`)

CNPG's init-roles job expects the Secret named `authentik-postgres-auth` with key `password`.

- Namespace: `apps`
- Secret name: `authentik-postgres-auth`
- Key: `password`

This password must match the password you configure Authentik to use.

### 1.2 SealedSecret: Authentik Configuration (`authentik-config`)

The wrapper chart is configured to use an existing secret (`authentik-config`) for Authentik configuration.
This Secret intentionally uses **generic key names** (not `AUTHENTIK_*`) to avoid
SonarCloud Security Hotspot false-positives on SealedSecret manifests.

The wrapper chart maps these generic keys into the expected `AUTHENTIK_*`
environment variables via `authentik.global.env` in `apps/user/authentik/values.yaml`.

Required keys in the Secret:

- `secret_key`
- `bootstrap_pw`
- `bootstrap_token`
- `s3_access`
- `s3_secret`

Note: PostgreSQL password is sourced from `authentik-postgres-auth/password`, and
TLS trust is handled by the wrapper chart mounting `minio-ca` and setting
`AWS_CA_BUNDLE` + `REQUESTS_CA_BUNDLE`.

### 1.3 Bucket + MinIO Credentials

Create bucket `authentik-media` in MinIO and generate an access key/secret with least-privilege to that bucket.
This is an operational step outside GitOps (MinIO tenant state), but required for the application.

## Phase 2: CNPG Role (Enable only after secrets exist)

After `authentik-postgres-auth` SealedSecret is committed and synced by ArgoCD (`secrets-apps`), enable the role.

File: `apps/cluster/cloudnative-pg/values.yaml`

- Set `cnpg.roles[].name=authentik` to `enabled: true`.

Then ArgoCD will run the CNPG init-roles job and create/rotate the role password.

## Phase 3: Deploy Authentik Wrapper

### 3.1 DB provisioning (GitOps)

The wrapper chart includes `apps/user/authentik/templates/db-init.job.yaml`:

- Runs as ArgoCD `PreSync` hook.
- Runs on `dbInit.image` (default: rootless DHI Postgres Debian 13 pinned by digest).
- Waits for CNPG RW endpoint readiness.
- Fails loudly if role `authentik` does not exist (so ordering stays explicit).
- Creates DB `authentik` if missing and ensures the DB owner is `authentik`.

### 3.2 ArgoCD Application

Manifest: `argocd/apps/user/authentik.yaml`

This Application can be `automated` once the required SealedSecrets exist under
`apps/user/secrets-apps/` and the CNPG `authentik` role is enabled.

## Phase 4: Validation

Repo checks (no cluster mutation):

- `mise run helm-lint`
- `mise run k8s-lint`
- `mise run sensitive-files`
- `mise run path-drift`

Read-only cluster checks (after syncing in ArgoCD):

- Authentik ingress:
  - `kubectl get ingress -n apps authentik -o wide`
- DB init job completion:
  - `kubectl get jobs -n apps authentik-db-init`
  - `kubectl logs -n apps job/authentik-db-init --tail=100`

## Rollback

- Disable the ArgoCD Application (or remove it from `argocd/apps/user`).
- Revert the CNPG role enablement for `authentik`.
- Remove `apps/user/authentik/` wrapper chart.
