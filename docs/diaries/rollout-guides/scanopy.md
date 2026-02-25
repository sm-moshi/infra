# Scanopy Rollout Guide

## Overview

Scanopy network discovery server deployment with hybrid daemon topology (in-cluster server + external daemons) and Authentik OIDC authentication.

**Status:** Chart/app ready, awaiting secrets and external daemon setup.

---

## Prerequisites Checklist

### 1. Database Setup

Create CNPG role and database for Scanopy:

```sql
-- Execute via apps/cluster/cloudnative-pg init-roles job or manual psql connection
CREATE ROLE scanopy WITH LOGIN PASSWORD '<secure-password>';
CREATE DATABASE scanopy OWNER scanopy;
GRANT ALL PRIVILEGES ON DATABASE scanopy TO scanopy;
```

### 2. Authentik OIDC Provider

Configure Authentik application for Scanopy:

1. Navigate to Authentik admin → Applications → Create
2. Settings:
   - **Name:** Scanopy
   - **Slug:** scanopy
   - **Provider:** Create new OAuth2/OpenID provider
   - **Redirect URIs:** `https://scanopy.m0sh1.cc/api/auth/oidc/callback/authentik`
   - **Client type:** Confidential
   - **Grant type:** Authorization Code
3. Save and copy **Client ID** and **Client Secret**

### 3. SealedSecrets Creation

#### 3.1 Create `scanopy-postgres-auth`

```bash
# Use password from CNPG role creation
PASSWORD="<secure-password>"
URI="postgresql://scanopy:${PASSWORD}@cnpg-main-rw.apps.svc.cluster.local:5432/scanopy"

kubectl create secret generic scanopy-postgres-auth \
  --dry-run=client -o yaml \
  --namespace=apps \
  --from-literal=uri="${URI}" | \
  kubeseal --format=yaml > apps/user/secrets-apps/scanopy-postgres-auth.sealedsecret.yaml
```

#### 3.2 Create `scanopy-oidc`

```bash
# Create oidc.toml from template
cat > /tmp/scanopy-oidc.toml <<EOF
[[oidc_providers]]
name = "Authentik"
slug = "authentik"
logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/authentik.svg"
issuer_url = "https://auth.m0sh1.cc/application/o/scanopy/"
client_id = "<CLIENT_ID_FROM_AUTHENTIK>"
client_secret = "<CLIENT_SECRET_FROM_AUTHENTIK>"
EOF

kubectl create secret generic scanopy-oidc \
  --dry-run=client -o yaml \
  --namespace=apps \
  --from-file=oidc.toml=/tmp/scanopy-oidc.toml | \
  kubeseal --format=yaml > apps/user/secrets-apps/scanopy-oidc.sealedsecret.yaml

rm /tmp/scanopy-oidc.toml
```

#### 3.3 Add Secrets to Kustomization

Uncomment the secret resources in `apps/user/secrets-apps/kustomization.yaml`:

```yaml
- scanopy-postgres-auth.sealedsecret.yaml
- scanopy-oidc.sealedsecret.yaml
```

### 4. External Daemon Setup (Hybrid Topology Requirement)

**Requirement:** At least one Scanopy daemon must run **outside** the Kubernetes cluster for cross-VLAN network discovery.

#### Example: Docker-based External Daemon

On a host outside K8s (e.g., infra VLAN host):

```bash
# Pull daemon image
docker pull ghcr.io/scanopy/scanopy/daemon:latest

# Run daemon with host network
docker run -d \
  --name scanopy-daemon-vlan10 \
  --network=host \
  --privileged \
  --restart=unless-stopped \
  -e SCANOPY_SERVER_URL=https://scanopy.m0sh1.cc \
  -e SCANOPY_BIND_ADDRESS=0.0.0.0 \
  -e SCANOPY_DAEMON_PORT=60073 \
  -e SCANOPY_NAME=daemon-vlan10 \
  -e SCANOPY_MODE=daemon_poll \
  -e SCANOPY_HEARTBEAT_INTERVAL=30 \
  -e SCANOPY_LOG_LEVEL=info \
  ghcr.io/scanopy/scanopy/daemon:latest

# Verify daemon is running
docker logs scanopy-daemon-vlan10
```

**Network considerations:**

- Daemon needs outbound HTTPS to `scanopy.m0sh1.cc`
- Daemon performs local network scanning (ICMP, nmap) on its attached subnet
- Deploy daemons strategically across VLANs for full visibility

---

## Deployment Steps

### 1. Commit Secrets

```bash
# Add sealed secrets to Git
git add apps/user/secrets-apps/scanopy-*.sealedsecret.yaml
git add apps/user/secrets-apps/kustomization.yaml
git commit -m "Add Scanopy SealedSecrets"
git push
```

### 2. Sync ArgoCD Applications

```bash
# Sync secrets-apps first
argocd app sync secrets-apps --timeout 300

# Wait for SealedSecrets controller to unseal
kubectl wait --for=condition=Ready secret/scanopy-postgres-auth -n apps --timeout=120s
kubectl wait --for=condition=Ready secret/scanopy-oidc -n apps --timeout=120s

# Sync Scanopy application
argocd app sync scanopy --timeout 300
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n apps -l app.kubernetes.io/name=scanopy

# Check server logs
kubectl logs -n apps -l app.kubernetes.io/component=server -f

# Check ingress
kubectl get ingress -n apps scanopy-server

# Test UI access
curl -I https://scanopy.m0sh1.cc
```

### 4. Configure First Scan

1. Navigate to `https://scanopy.m0sh1.cc`
2. Log in with Authentik (or local admin if needed)
3. Register external daemon(s) (if not auto-registered)
4. Configure subnet/VLAN scan targets
5. Trigger first discovery cycle

---

## Post-Deployment Validation

### Health Checks

```bash
# Server health
kubectl exec -n apps deployment/scanopy-server -- curl -f http://localhost:60072/api/health

# Database connectivity
kubectl exec -n apps deployment/scanopy-server -- \
  sh -c 'psql $SCANOPY_DATABASE_URL -c "SELECT version();"'
```

### OIDC Authentication

1. Test SSO login via Authentik
2. Verify user session creation
3. Confirm local admin fallback works (registration not disabled)

### Daemon Registration

```bash
# Check daemon heartbeats in server logs
kubectl logs -n apps -l app.kubernetes.io/component=server | grep -i daemon

# Verify daemon appears in UI under Settings → Daemons
```

---

## Troubleshooting

### Server won't start

```bash
# Check secret mounting
kubectl describe pod -n apps -l app.kubernetes.io/component=server

# Verify database connectivity
kubectl logs -n apps -l app.kubernetes.io/component=server | grep -i "database\|postgres"
```

### OIDC not working

```bash
# Check oidc.toml mounted correctly
kubectl exec -n apps deployment/scanopy-server -- cat /oidc.toml

# Verify Authentik redirect URI matches
# Should be: https://scanopy.m0sh1.cc/api/auth/oidc/callback/authentik
```

### External daemon not connecting

```bash
# Check daemon logs
docker logs scanopy-daemon-vlan10

# Verify server URL reachability
docker exec scanopy-daemon-vlan10 curl -I https://scanopy.m0sh1.cc

# Check firewall rules for outbound HTTPS
```

---

## Operational Notes

### Backup/Restore

- Database: Included in CNPG automated backups (MinIO S3)
- Configuration: Stored in Git (GitOps pattern)
- Scan history: Persisted in Scanopy PostgreSQL database

### Scaling

- Server: Increase `replicaCount` in `values.yaml` (currently 1)
- In-cluster daemon: Enable `daemon.inCluster.enabled=true` for node-local scanning
- External daemons: Deploy additional daemons across VLANs as needed

### Monitoring

- Metrics: Expose via `server.metrics.existingSecret` if metrics token configured
- Logs: Aggregated in Loki via standard pod log collection
- Alerts: Define custom alerts for daemon heartbeat failures

---

## References

- Chart: `apps/user/scanopy/`
- ArgoCD App: `argocd/apps/user/scanopy.yaml`
- Secret Templates: `apps/user/secrets-apps/templates/scanopy-*`
- Upstream Docs: <https://scanopy.net/docs/>
- Plan: session plan.md (implementation complete)
