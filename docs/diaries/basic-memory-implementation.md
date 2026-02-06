# Basic Memory MCP Server Implementation Plan

## Document Information

- Author: m0sh1-devops agent (regenerated)
- Date: 2026-02-06
- Status: Draft Implementation Plan

## Summary

Deploy Basic Memory as a Kubernetes service (SSE transport) so MCP-capable clients can
connect over HTTP and persist notes/prompts/instructions in a durable, local-first
Markdown store.

Basic Memory upstream Docker image runs an MCP server over SSE on port 8000 and serves
the MCP endpoint at `/mcp`.

## Scope

In scope:

- GitOps deployment via ArgoCD
- Persistent storage (PVC) for `/app/data`
- Internal Service for SSE clients
- Optional Ingress for access from the homelab network / tailnet
- Basic guardrails (NetworkPolicy recommendation, resource limits, node placement)

Out of scope:

- Migrating existing Markdown knowledge into Basic Memory (do later, operationally)
- Writing any custom Basic Memory plugins or upstream modifications

## Hard Rules (Repo Contract)

- GitOps only: do not mutate the cluster imperatively. Changes flow Git -> ArgoCD -> cluster.
- No secrets in Git: use SealedSecrets (or Vault for host-side secrets).
- No repo structure drift: do not invent new layouts beyond the existing `apps/*` patterns.

## Upstream Notes (as of 2026-02-06)

- Docker guide: <https://docs.basicmemory.com/guides/docker/>
- Technical info: <https://docs.basicmemory.com/technical/technical-information/>
- Source: <https://github.com/basicmachines-co/basic-memory>

From upstream docs:

- Container listens on `0.0.0.0:8000`.
- Health endpoint: `/health`.
- MCP SSE endpoint: `/mcp`.
- Data directory is under `/app/data` (bind-mount in Docker examples).

## Architecture (Kubernetes)

Kubernetes objects (target namespace: `apps`):

- Deployment: `basic-memory`
- Service: `basic-memory` (ClusterIP, port 8000)
- PVC: `basic-memory-data` mounted at `/app/data`

Optional:

- Ingress: `basic-memory.m0sh1.cc` (Traefik + TLS), or no ingress and access only
  from inside the cluster.

Transport:

- Run Basic Memory in SSE mode (HTTP server) so it stays alive in Kubernetes.

## Security Posture

Basic Memory is effectively a knowledge store. Treat it as sensitive.

- Prefer no public ingress.
- If ingress is required, ensure it is private (tailnet-only / internal-only) and
  backed by TLS.
- Add a NetworkPolicy allowing ingress only from known client pods/namespaces.

Note: do not assume Basic Memory provides strong built-in auth. Plan for network
controls regardless.

## Multi-User + Concurrency Notes

Multiple concurrent connections:

- Yes: the MCP SSE endpoint (`/mcp`) is served over HTTP and can accept multiple
  client connections at the same time (each client holds its own SSE connection).
- In this plan we deploy a single replica (because the data store is a PVC mounted
  at `/app/data`). A restart will drop active connections; clients should reconnect.

Multiple users:

- Local/self-hosted mode is effectively single-tenant: anyone who can reach the
  service will be interacting with the same underlying memory store.
- If you need per-user isolation, the simplest pattern is “one Basic Memory instance
  per user” (separate Deployment/Service/PVC per user) and restrict access via
  NetworkPolicy/Ingress.
- Upstream also has a “cloud mode” with OAuth/JWT tenant isolation (multi-user),
  but that’s a different deployment shape than “local PVC-backed Markdown store”.

Horizontal scaling:

- Do not assume you can scale replicas >1 with an RWO PVC.
- Even with RWX storage, SSE workloads typically require sticky routing and careful
  coordination around shared state; treat HA as a separate design effort.

## Node Placement (Repo Policy)

Per `docs/structure.md`:

- Basic Memory MCP: prefer `horse04` unless it becomes critical.

Implementation approach:

- Prefer `horse04` by using node affinity on `kubernetes.io/hostname: horse04`
  (or an equivalent dedicated node label if you maintain one).
- Keep resource requests small but explicit to avoid noisy-neighbor issues.

## Storage

Basic Memory requires persistent storage.

Recommendation:

- PVC size: start with `5Gi` (increase if the store grows).
- StorageClass: use the default "general" NVMe class used for utility apps (align
  with what pgadmin4 uses in this repo).
- Mount: `/app/data`.

## Wrapper Chart Plan (Git)

Create a wrapper chart under `apps/user/basic-memory/`.

- Chart name: `basic-memory`
- Values:
  - image repository + tag (pin an explicit version; avoid `latest`)
  - service port 8000
  - persistence enabled with PVC
  - `automountServiceAccountToken: false`
  - `securityContext`: run as non-root; drop all capabilities
  - `resources`: requests and limits
  - node placement targeting horse04

ArgoCD:

- Application: `argocd/apps/user/basic-memory.yaml`
- Sync wave: place near other utility apps (after namespaces + secrets-apps; no
  strong ordering constraints unless ingress/certs are required).

## Implementation Steps

1. Confirm upstream image and runtime requirements
   - Verify the image exposes port 8000 and supports running in SSE/HTTP mode.
   - Confirm `/health` and `/mcp` behavior.

2. Scaffold the wrapper chart
   - `apps/user/basic-memory/Chart.yaml`
   - `apps/user/basic-memory/values.yaml`
   - `apps/user/basic-memory/templates/` for Deployment/Service/PVC/Ingress

3. Add ArgoCD Application
   - `argocd/apps/user/basic-memory.yaml`

4. Deploy via GitOps
   - Commit changes and let ArgoCD reconcile.

5. Validate (read-only)
   - Confirm pod is running and service endpoints exist.
   - Probe `/health` and `/mcp` from a debug pod or via port-forward.

6. Harden
   - Add NetworkPolicy restricting ingress.

- If ingress is enabled, confirm it is private-only and TLS is valid.

## Validation Commands (Read-Only)

```bash
# Pod / rollout
kubectl get deploy -n apps basic-memory
kubectl get pod -n apps -l app.kubernetes.io/name=basic-memory

# Service
kubectl get svc -n apps basic-memory
kubectl get endpoints -n apps basic-memory

# Logs
kubectl logs -n apps -l app.kubernetes.io/name=basic-memory --tail=200
```

Suggested functional checks (read-only, no resource creation):

```bash
# Port-forward the Service locally, then curl the health endpoint
kubectl port-forward -n apps svc/basic-memory 18000:8000
curl -fsS http://127.0.0.1:18000/health
```

## Client Configuration (MCP)

Once deployed, MCP clients should use the SSE endpoint.

- In-cluster URL: `http://basic-memory.apps.svc.cluster.local:8000/mcp`
- If exposed via ingress: `https://basic-memory.m0sh1.cc/mcp`

Keep ingress private if you enable it.

## Rollback Plan

- Remove or disable the ArgoCD Application (`argocd/apps/user/basic-memory.yaml`) in Git.
- If the workload is causing resource pressure, scale to zero via Git (set replicas=0).

## Change Log

- 2026-02-06: Regenerated plan after accidental deletion.
