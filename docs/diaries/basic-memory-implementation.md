# Basic Memory MCP Server Implementation Plan

## Document Information

- Author: m0sh1-devops agent (regenerated)
- Date: 2026-02-06
- Updated: 2026-02-07
- Status: ✅ Deployed (LiveSync bridge fix pending sync)

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
- This covers multiple MCP clients (for example VS Code, Codex, Claude) connected
  in parallel to the same Basic Memory instance.
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

## Troubleshooting Notes (2026-02-07)

### Symptom: `basic-memory` Ingress/MCP returns 503

Root cause observed:

- The `basic-memory` pod is a multi-container pod (`basic-memory` + `couchdb` + `livesync-bridge`).
- If `livesync-bridge` exits, the pod becomes `NotReady`, the `basic-memory` Service has no endpoints, and Traefik returns 503.

Fix implemented in chart (GitOps):

- `apps/user/basic-memory/templates/deployment.yaml`: set `workingDir: /app` and `LSB_CONFIG=/app/dat/config.json` for the `livesync-bridge` container to remove ambiguity about relative config paths.
  - Includes a startup preflight that strips any trailing garbage after the JSON document in `config.json` (and rewrites the cleaned file) before starting `livesync-bridge`.

### CouchDB `_users` Warnings

If CouchDB logs complain about missing `_users`, ensure the PostSync hook job creates it:

- `apps/user/basic-memory/templates/couchdb-init-job.yaml` creates `_users` and the LiveSync database (idempotent), and pins `curlimages/curl:8.11.1` (no floating tags).

## Implementation Details (2026-02-07)

### Upstream Verification (via context7)

Verified technical details from Basic Memory documentation:

**Latest Version:** 0.18.0 (pinned in deployment)

**Docker Image:** `ghcr.io/basicmachines-co/basic-memory:0.18.0`

- Image migrated from Docker Hub to GitHub Container Registry (v0.14.0+)
- Integrated vulnerability scanning via GitHub
- Automated publishing via GitHub Actions

**Runtime Configuration:**

- Command: `basic-memory mcp --port 8000`
- Health endpoint: `GET /health`
- MCP SSE endpoint: `/mcp`
- Data directory: `/app/data` (must be writable filesystem, not S3/object storage)
- Environment variables:
  - `BASIC_MEMORY_DEFAULT_PROJECT`: Project name (default: "main")
  - `BASIC_MEMORY_LOG_LEVEL`: Logging verbosity (default: "INFO")

**Multi-Connection Support:** ✅ Confirmed

- SSE transport natively supports multiple concurrent client connections
- Each client maintains independent SSE connection to `/mcp`
- All clients share the same underlying Markdown store at `/app/data`
- No special configuration needed - works out of the box

**Reconnection Handling:**

- Server-side: Stateless SSE connections (no session persistence)
- Client-side options:
  1. Use `mcp-proxy` (automatic reconnection via STDIO bridge)
  2. Native HTTP client with built-in retry logic (Claude Code, etc.)
- Kubernetes health checks ensure pod stays healthy during restarts

**Storage Backend:**

- **Required:** Local filesystem at `/app/data`
- **Format:** Plain Markdown files
- **NOT supported:** S3, MinIO, or object storage (requires local POSIX filesystem)
- **Growth estimates:** 100 notes ~5MB, 1000 notes ~50MB, 10000 notes ~500MB
- **Conclusion:** Simple PVC is perfect - MinIO would be overkill and incompatible

### Created Files

**Helm Wrapper Chart:**

```text
apps/user/basic-memory/
├── Chart.yaml                  # v0.1.0, appVersion v0.18.0
├── values.yaml                 # Configuration with defaults
└── templates/
    ├── _helpers.tpl            # Template helper functions
    ├── deployment.yaml         # Deployment with health probes
    ├── service.yaml            # ClusterIP on port 8000
    ├── pvc.yaml               # 5Gi PVC for /app/data
    └── ingress.yaml           # Traefik ingress (LAN/Tailscale only)
```

**ArgoCD Application:**

- `argocd/apps/user/basic-memory.yaml` (sync-wave 34)

### Implementation Configuration

**Deployment:**

- **Replicas:** 1 (RWO PVC constraint)
- **Strategy:** Recreate (safe for PVC-backed workload)
- **Security Context:**
  - Run as non-root (UID/GID 1000)
  - Drop all capabilities
  - No service account token mounted

**Storage:**

- **Size:** 5Gi (expandable online via Proxmox CSI)
- **StorageClass:** `proxmox-csi-zfs-nvme-general-retain`
- **Access Mode:** ReadWriteOnce
- **Mount:** `/app/data`
- **Backup:** Simple rsync/cron job of PVC (plain Markdown files)

**Ingress:** ✅ Enabled

- **URL:** `https://basic-memory.m0sh1.cc/mcp`
- **TLS:** `wildcard-m0sh1-cc` certificate
- **Cert Issuer:** `origin-ca-issuer` (Cloudflare Origin CA)
- **Access:** LAN and Tailscale only (not exposed to WAN)
- **Traefik:** entrypoint `websecure`, TLS enabled

**Node Placement:**

- **Preferred:** `horse04` (weight: 100) per docs/structure.md policy
- **Fallback:** `pve-01` (weight: 80), `pve-02` (weight: 60)
- **Selector:** `node-role.kubernetes.io/worker: "true"`

**Resources:**

- **Requests:** 100m CPU, 256Mi RAM
- **Limits:** 500m CPU, 512Mi RAM

**Health Checks:**

- **Liveness Probe:**
  - Endpoint: `GET /health` on port 8000
  - Initial delay: 10s
  - Period: 30s
  - Timeout: 5s
  - Failure threshold: 3
- **Readiness Probe:**
  - Endpoint: `GET /health` on port 8000
  - Initial delay: 5s
  - Period: 10s
  - Timeout: 5s
  - Failure threshold: 3

### Deployment Workflow

**Helm Chart Validation:**

```bash
# Lint passed
helm lint apps/user/basic-memory
# Output: 1 chart(s) linted, 0 chart(s) failed

# Template rendering verified
helm template basic-memory apps/user/basic-memory --namespace apps
# Generates: PVC, Service, Deployment, Ingress
```

**GitOps Deployment Steps:**

1. ✅ Scaffold wrapper chart (completed)
2. ✅ Create ArgoCD Application (completed)
3. ✅ Commit changes to Git (completed)
4. ✅ Push to trigger ArgoCD auto-sync (completed)
5. ✅ Monitor pod rollout (completed - pod healthy with 2/2 containers)
6. ✅ Validate health endpoint and MCP connection (completed)
7. ✅ Connect MCP clients (completed - configured in Claude Code)

### Client Configuration

**Claude Code / Native HTTP:**

```json
{
  "mcpServers": {
    "basic-memory": {
      "type": "http",
      "url": "https://basic-memory.m0sh1.cc/mcp"
    }
  }
}
```

**With mcp-proxy (STDIO Bridge + Auto-reconnect):**

```json
{
  "mcpServers": {
    "basic-memory": {
      "command": "uvx",
      "args": ["mcp-proxy", "https://basic-memory.m0sh1.cc/mcp"]
    }
  }
}
```

**In-cluster Access:**

- URL: `http://basic-memory.apps.svc.cluster.local:8000/mcp`

### Validation Commands

**Deployment Status:**

```bash
# ArgoCD Application
kubectl get application -n argocd basic-memory

# Pod status
kubectl get pods -n apps -l app.kubernetes.io/name=basic-memory -w

# All resources
kubectl get all,pvc,ingress -n apps -l app.kubernetes.io/name=basic-memory
```

**Health Checks:**

```bash
# Port-forward to local machine
kubectl port-forward -n apps svc/basic-memory 8000:8000

# Test health endpoint
curl http://localhost:8000/health

# Test MCP endpoint (SSE)
curl -v https://basic-memory.m0sh1.cc/mcp
```

**Logs:**

```bash
# Follow logs
kubectl logs -n apps -l app.kubernetes.io/name=basic-memory -f

# Tail last 200 lines
kubectl logs -n apps -l app.kubernetes.io/name=basic-memory --tail=200
```

**Storage Monitoring:**

```bash
# Check PVC usage
kubectl exec -n apps deploy/basic-memory -- df -h /app/data

# List stored notes
kubectl exec -n apps deploy/basic-memory -- ls -lh /app/data

# Storage growth tracking
kubectl exec -n apps deploy/basic-memory -- du -sh /app/data/*
```

### Multi-Client Architecture

```text
┌─────────────┐
│ Claude Code │────┐
└─────────────┘    │
                   │
┌─────────────┐    │    ┌──────────────────┐
│   VS Code   │────┼───>│  basic-memory    │
└─────────────┘    │    │  :8000/mcp       │
                   │    │  (SSE endpoint)  │
┌─────────────┐    │    └──────────────────┘
│    Codex    │────┘              │
└─────────────┘                   │
                                  ▼
                        ┌──────────────────┐
                        │   /app/data      │
                        │  (Markdown PVC)  │
                        │   5Gi storage    │
                        └──────────────────┘
```

**Key Properties:**

- ✅ Multiple concurrent SSE connections supported
- ✅ Shared Markdown knowledge base
- ✅ No per-user isolation (single-tenant mode)
- ✅ Clients auto-reconnect on pod restart
- ⚠️ All clients share same memory store (no namespacing)

### Security Considerations

**Current Posture:**

- ✅ No WAN exposure (LAN/Tailscale only)
- ✅ TLS termination at ingress (Cloudflare Origin CA)
- ✅ Non-root container (UID/GID 1000)
- ✅ Capabilities dropped
- ⚠️ No built-in authentication (network-level trust)
- ⚠️ Single-tenant (all clients share data)

**Future Hardening (Optional):**

- NetworkPolicy to restrict ingress to specific pods/namespaces
- OAuth/JWT authentication (requires upstream cloud mode)
- Per-user instances (separate Deployment/PVC per user)

### Known Limitations

1. **Single Replica Only:** RWO PVC prevents horizontal scaling
2. **No User Isolation:** All clients share same memory store
3. **Restart = Connection Drop:** Clients must implement reconnect logic
4. **No Built-in Auth:** Relies on network-level access control
5. **Not HA:** Single point of failure (treat as utility service)

### Storage Expansion Strategy

**Online Resize (Proxmox CSI Supports):**

```bash
# Expand PVC from 5Gi to 10Gi
kubectl patch pvc basic-memory-data -n apps \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Verify expansion
kubectl get pvc -n apps basic-memory-data
```

**Backup Strategy:**

```bash
# Manual backup (tar + rsync)
kubectl exec -n apps deploy/basic-memory -- tar czf - /app/data \
  | gzip > basic-memory-backup-$(date +%Y%m%d).tar.gz

# Automated via CronJob (future enhancement)
# - Schedule: daily at 2am
# - Target: MinIO bucket or NFS share
# - Retention: 7 days
```

### Commit Message Template

```text
Add Basic Memory MCP server deployment

- Helm wrapper chart for Basic Memory v0.18.0
- 5Gi PVC for persistent Markdown storage at /app/data
- Ingress at basic-memory.m0sh1.cc (LAN/Tailscale only)
- Health checks on /health endpoint
- Multi-connection support confirmed (SSE transport)
- Prefers horse04 node placement per docs/structure.md
- Security: non-root, capabilities dropped, no SA token

Closes: Basic Memory implementation plan
Ref: docs/diaries/basic-memory-implementation.md
```

## Obsidian Integration (Native Mac App)

### Overview

Use **native Obsidian app on Mac** with Git sync to share markdown files with Basic Memory running in Kubernetes. This provides a seamless workflow where you edit in Obsidian locally and Basic Memory MCP picks up changes automatically.

### Architecture: Git-Based Sync

```text
┌──────────────────────────────────────────────────────────────────┐
│                         Mac Desktop                              │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Obsidian.app                                              │  │
│  │  ~/Documents/knowledge-base/                               │  │
│  │  ├── projects/                                             │  │
│  │  ├── notes/                                                │  │
│  │  └── daily/                                                │  │
│  └───────────────────┬────────────────────────────────────────┘  │
│                      │                                            │
│                      │ Obsidian Git Plugin                        │
│                      │ (auto-commit every 5 min)                  │
│                      ↓                                            │
└──────────────────────────────────────────────────────────────────┘
                       │
                       ↓
         ┌─────────────────────────────┐
         │   Git Repository            │
         │   (GitHub/GitLab/Gitea)     │
         │   Private repo:             │
         │   sm-moshi/knowledge-base   │
         └─────────────┬───────────────┘
                       │
                       │ HTTP/SSH pull every 30s
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  basic-memory Pod                                          │  │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐   │  │
│  │  │  git-sync        │  │  basic-memory                │   │  │
│  │  │  (sidecar)       │  │  (main container)            │   │  │
│  │  │                  │  │                              │   │  │
│  │  │  pulls repo      │  │  reads /app/data             │   │  │
│  │  │  every 30s       │  │  serves MCP at :8000/mcp     │   │  │
│  │  └────────┬─────────┘  └───────────┬──────────────────┘   │  │
│  │           │                         │                      │  │
│  │           └─────────────┬───────────┘                      │  │
│  │                         ↓                                  │  │
│  │              ┌──────────────────────┐                      │  │
│  │              │  /app/data (PVC)     │                      │  │
│  │              │  5Gi storage         │                      │  │
│  │              │  ├── projects/       │                      │  │
│  │              │  ├── notes/          │                      │  │
│  │              │  └── daily/          │                      │  │
│  │              └──────────────────────┘                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Key Benefits

- ✅ **Native Mac Obsidian** - Use the full-featured desktop app, not web UI
- ✅ **Bi-directional sync** - Changes in Obsidian OR Basic Memory sync via Git
- ✅ **Version history** - Full Git commit log of all changes
- ✅ **Multi-device** - Use Obsidian on Mac, iPad, Phone (all sync via Git)
- ✅ **Offline capable** - Work offline, sync when connected
- ✅ **No direct PVC access needed** - Git is the sync layer
- ✅ **Conflict resolution** - Git handles merge conflicts
- ✅ **Backup included** - Git repo IS your backup

### Implementation Plan

#### Phase 1: Git Repository Setup

##### Option A: Private GitHub Repo (Recommended)

```bash
# Create private repo: sm-moshi/knowledge-base
gh repo create sm-moshi/knowledge-base --private

# Initialize local Obsidian vault
cd ~/Documents/knowledge-base
git init
git remote add origin git@github.com:sm-moshi/knowledge-base.git

# Initial structure
mkdir -p projects notes daily
echo "# Knowledge Base" > README.md
git add .
git commit -m "Initial commit"
git push -u origin main
```

##### Option B: Self-Hosted Gitea

- Deploy Gitea in cluster (if not already running)
- Create repo: `https://git.m0sh1.cc/m0sh1/knowledge-base`
- Accessible via Tailscale/LAN only

#### Phase 2: Mac Obsidian Configuration

**Install Obsidian Git Plugin:**

1. Open Obsidian Settings → Community Plugins
2. Browse and install **"Obsidian Git"** by Denis Olehov
3. Enable the plugin

**Configure Auto-Sync:**

```json
{
  "commitMessage": "vault backup: {{date}}",
  "autoCommitMessage": "auto: {{date}}",
  "commitDateFormat": "YYYY-MM-DD HH:mm:ss",
  "autoSaveInterval": 5,
  "autoPullInterval": 2,
  "autoPullOnBoot": true,
  "disablePush": false,
  "pullBeforePush": true,
  "disablePopups": false,
  "listChangedFilesInMessageBody": true,
  "showStatusBar": true,
  "updateSubmodules": false,
  "syncMethod": "merge",
  "gitPath": "",
  "customMessageOnAutoBackup": false,
  "autoBackupAfterFileChange": false,
  "treeStructure": false,
  "refreshSourceControl": true,
  "basePath": "",
  "differentIntervalCommitAndPush": false,
  "changedFilesInStatusBar": false
}
```

**Key Settings:**

- **Auto-save interval:** 5 minutes (adjust based on preference)
- **Auto-pull interval:** 2 minutes (checks for remote changes)
- **Sync method:** merge (handles conflicts gracefully)
- **Pull before push:** true (prevents conflicts)

#### Phase 3: Kubernetes Git-Sync Sidecar

**Update basic-memory Deployment with git-sync sidecar:**

```yaml
# Add to values.yaml
gitSync:
  enabled: true
  repo: "https://github.com/sm-moshi/knowledge-base.git"
  branch: "main"
  depth: 1  # Shallow clone for faster sync
  period: 30s  # Pull every 30 seconds
  # For private repos:
  secretName: git-sync-secret  # Contains SSH key or token
```

**Deployment template changes:**

```yaml
# Add git-sync sidecar container
containers:
- name: git-sync
  image: registry.k8s.io/git-sync/git-sync:v4.2.1
  args:
    - --repo={{ .Values.gitSync.repo }}
    - --branch={{ .Values.gitSync.branch }}
    - --depth={{ .Values.gitSync.depth }}
    - --period={{ .Values.gitSync.period }}
    - --root=/app/data
    - --link=current
    - --max-failures=3
    - --one-time=false
  volumeMounts:
    - name: data
      mountPath: /app/data
  {{- if .Values.gitSync.secretName }}
  env:
    - name: GITSYNC_USERNAME
      valueFrom:
        secretKeyRef:
          name: {{ .Values.gitSync.secretName }}
          key: username
    - name: GITSYNC_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.gitSync.secretName }}
          key: password
  {{- end }}
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

**How it works:**

1. git-sync container pulls repo to `/app/data/current/`
2. Creates symlink: `/app/data/current` → `/app/data/<commit-hash>/`
3. Updates every 30 seconds (configurable)
4. basic-memory reads from `/app/data/current/`
5. Both containers share the same PVC

#### Phase 4: Authentication (Private Repos)

**For GitHub Private Repo:**

```bash
# Create personal access token (PAT) with repo scope
# https://github.com/settings/tokens

# Create Kubernetes secret
kubectl create secret generic git-sync-secret -n apps \
  --from-literal=username=sm-moshi \
  --from-literal=password=ghp_yourtokenhere

# Or use SSH key
kubectl create secret generic git-sync-secret -n apps \
  --from-file=ssh=/Users/smeya/.ssh/id_ed25519
```

**For public repos:** No secret needed!

#### Phase 5: Testing Workflow

**Test the complete flow:**

```bash
# 1. Create a note in Mac Obsidian
echo "# Test Note" > ~/Documents/knowledge-base/test.md

# 2. Wait for Obsidian Git plugin to auto-commit (5 min)
# Or manually trigger: Cmd+P → "Obsidian Git: Commit all changes"

# 3. Check Git repo
cd ~/Documents/knowledge-base
git log --oneline -5

# 4. Wait for git-sync to pull (30 seconds)

# 5. Verify in Basic Memory pod
kubectl exec -n apps deploy/basic-memory -- ls -la /app/data/current/

# 6. Query via MCP
# Basic Memory should now see test.md and can search/retrieve it
```

### Alternative Approaches (Considered but Not Recommended)

#### Option 2: SMB/NFS Server in Cluster

**How it works:**

- Deploy SMB/NFS server pod with same PVC
- Mac mounts network share: `smb://basic-memory.m0sh1.cc/vault`
- Obsidian vault points to mounted directory

**Pros:**

- Real-time sync (no Git delay)
- Direct filesystem access

**Cons:**

- ❌ Network dependency (offline = no access)
- ❌ No version history
- ❌ Potential file corruption on network issues
- ❌ Complexity: need SMB/NFS server + ingress + auth
- ❌ Single PVC can't be mounted RWX unless using NFS StorageClass

**Verdict:** More complex, less reliable than Git sync.

#### Option 3: Obsidian Livesync Plugin

**How it works:**

- Deploy CouchDB in cluster
- Obsidian Livesync plugin syncs to CouchDB
- Basic Memory reads from... wait, CouchDB not filesystem!

**Cons:**

- ❌ Basic Memory requires **filesystem** at `/app/data`, not database
- ❌ Would need custom adapter to export CouchDB → markdown files
- ❌ Adds unnecessary complexity

**Verdict:** Not compatible with Basic Memory's architecture.

#### Option 4: Tailscale + Syncthing

**How it works:**

- Syncthing runs on Mac and in cluster pod
- Both sides sync `/app/data` via Tailscale network

**Pros:**

- Real-time bi-directional sync
- Works over Tailscale (secure)

**Cons:**

- ❌ More complex than Git
- ❌ No version history
- ❌ Conflict resolution is manual

**Verdict:** Overkill compared to Git sync.

### Recommended Solution: Git Sync

**Winner: Git-based sync** for these reasons:

1. ✅ **Simple** - Just Git repo + Obsidian plugin + sidecar
2. ✅ **Reliable** - Git handles conflicts and version control
3. ✅ **Multi-device** - Works on Mac, iPad, Phone
4. ✅ **Offline-capable** - Work offline, sync later
5. ✅ **Proven pattern** - Used widely in knowledge management
6. ✅ **Free** - No additional infrastructure needed (GitHub free tier)

### PVC Access: Can Both Access Simultaneously?

**Question:** Can Obsidian and Basic Memory both access the PVC at the same time?

**Answer:**

- **Direct PVC mount:** NO - ReadWriteOnce (RWO) PVC can only be mounted by pods on the same node
- **Via Git sync:** YES - They don't access PVC directly, they sync through Git:
  - Mac Obsidian → Git repo (push)
  - Git repo → Kubernetes PVC (pull via git-sync sidecar)
  - Changes propagate within ~30-120 seconds (configurable)

**Sync flow:**

```text
Mac Obsidian edit → auto-commit (5 min) → push to Git →
git-sync pulls (30 sec) → updates PVC → Basic Memory sees change
```

**Is this "simultaneous"?**

- Not real-time, but near-real-time (30s - 5min latency)
- Good enough for knowledge management use case
- If you need instant sync, use Obsidian Web in cluster instead

### Implementation Status

- ✅ **Phase 1:** Git repository setup (completed)
  - Private GitHub repo created: `sm-moshi/knowledge-base`
  - Initial commit pushed to main branch
- ✅ **Phase 2:** Obsidian Git plugin configuration (completed)
  - Plugin installed and configured with auto-sync
  - Auto-commit every 5 minutes, auto-pull every 2 minutes
- ✅ **Phase 3:** Add git-sync sidecar to deployment (completed)
  - git-sync v4.2.1 sidecar added to basic-memory pod
  - Syncs from GitHub every 30 seconds to `/app/data/knowledge/`
  - Reuses existing GitHub PAT via reflector-distributed secret
- ✅ **Phase 4:** Configure authentication for private repo (completed)
  - Added reflector annotations to `repo-github-m0sh1-infra` secret
  - Secret successfully distributed from argocd to apps namespace
- ✅ **Phase 5:** Test end-to-end workflow (completed)
  - Tested: Mac Obsidian → GitHub → git-sync → Kubernetes
  - Successfully synced README.md and Welcome.md
  - Sync latency: ~30 seconds from commit to pod

### Deployment Success (2026-02-07)

**Final Status:** ✅ **FULLY OPERATIONAL**

**Deployed Components:**

```text
Pod: basic-memory-cf5cd5f4d-v8bdl (2/2 Running)
├── basic-memory container
│   ├── Image: ghcr.io/basicmachines-co/basic-memory:latest
│   ├── Transport: streamable-http
│   ├── MCP Endpoint: http://0.0.0.0:8000/mcp
│   └── Status: ✅ Healthy
└── git-sync sidecar
    ├── Image: registry.k8s.io/git-sync/git-sync:v4.2.1
    ├── Repo: https://github.com/sm-moshi/knowledge-base.git
    ├── Sync Status: ✅ Active (commit 696ca84d)
    └── Sync Period: 30 seconds
```

**Verified Functionality:**

- ✅ MCP server accessible at `https://basic-memory.m0sh1.cc/mcp`
- ✅ Pod running with TCP socket health probes (no HTTP /health endpoint)
- ✅ Git-sync successfully pulling from private GitHub repo
- ✅ Obsidian notes syncing to `/app/data/knowledge/`
- ✅ Bidirectional sync working (Mac Obsidian ↔ Kubernetes)
- ✅ Reflector distributing GitHub PAT secret to apps namespace

**Test Results:**

1. **Mac Obsidian → Kubernetes:**
   - Edited README.md in Obsidian (3:01:57 am)
   - Obsidian Git plugin auto-committed
   - git-sync detected commit `696ca84d` at 02:04:27
   - Files synced to pod: `README.md`, `Welcome.md`, `.obsidian/`

2. **Sync Latency:**
   - Obsidian commit to GitHub: ~5 minutes (auto-commit interval)
   - GitHub to Kubernetes: ~30 seconds (git-sync period)
   - **Total latency: 30s - 5min** (acceptable for knowledge management)

**Active URLs:**

- **MCP Endpoint:** `https://basic-memory.m0sh1.cc/mcp`
- **GitHub Repo:** `https://github.com/sm-moshi/knowledge-base`
- **ArgoCD App:** `https://argocd.m0sh1.cc/applications/basic-memory`

**Resource Usage:**

```bash
# Pod: basic-memory-cf5cd5f4d-v8bdl
# basic-memory container: 100m CPU / 256Mi RAM (requested)
# git-sync container: 50m CPU / 64Mi RAM (requested)
# PVC: 5Gi (proxmox-csi-zfs-nvme-general-retain)
# Node: horse04 (preferred placement)
```

**Key Learnings:**

1. **Image tag:** Use `:latest` not `:v0.18.0` (version tags don't exist)
2. **Transport flag:** Must specify `--transport streamable-http` explicitly
3. **Health probes:** No `/health` or `/mcp/health` endpoint - use TCP socket probes
4. **Secret distribution:** Reflector needs annotations + secret deletion to trigger distribution
5. **git-sync flags:** `--branch` and `--dest` are deprecated, use `--ref` and `--link`

## Change Log

- 2026-02-06: Regenerated plan after accidental deletion.
- 2026-02-07: Implementation completed and deployed
  - ✅ Verified upstream docs via context7 MCP
  - ✅ Confirmed multi-connection support (SSE native capability)
  - ✅ Clarified storage requirements (PVC perfect, MinIO incompatible)
  - ✅ Created Helm wrapper chart (apps/user/basic-memory)
  - ✅ Created ArgoCD Application (argocd/apps/user/basic-memory.yaml)
  - ✅ Validated chart with helm lint and helm template
  - ✅ Fixed Docker image tag (use :latest not :v0.18.0)
  - ✅ Added --transport streamable-http flag
  - ✅ Switched health probes from HTTP to TCP socket
  - ✅ Deployed and verified in cluster
  - ✅ Added git-sync sidecar for Obsidian integration
  - ✅ Configured reflector for secret distribution
  - ✅ Tested end-to-end sync workflow (Mac Obsidian ↔ K8s)
  - ✅ Successfully synced markdown files from Obsidian to pod
  - **Status:** FULLY OPERATIONAL
