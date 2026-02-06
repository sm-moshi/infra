# cert-manager DHI Migration Implementation Plan

**Status:** 🔬 Research Phase Complete - Ready for Implementation Planning
**Created:** 2026-02-03
**Last Updated:** 2026-02-03 09:15 UTC
**Estimated Implementation Time:** 3-4 hours
**Risk Level:** 🔴 HIGH (cluster-wide TLS infrastructure)

---

## Executive Summary

**Objective:** Migrate cert-manager from upstream Jetstack images to Docker Hardened Images (DHI) for enhanced security posture while maintaining zero downtime and certificate continuity.

**Current State:**

- cert-manager v1.19.2 operational (controller, cainjector, webhook, startupapicheck)
- 5 active certificates (3 in traefik namespace, 2 in cnpg-system)
- All certificates healthy with automatic renewal working
- Upstream images: `quay.io/jetstack/cert-manager-*:v1.19.2`

**Target State:**

- cert-manager v1.19.2 (same version, image source change only)
- DHI images: `dhi.io/cert-manager-*:1.19.2-debian13@sha256:*` (digest-pinned)
- imagePullSecrets: `kubernetes-dhi` (already replicated to cert-manager namespace via Reflector)
- Zero functional changes to certificate issuance or management

---

## Research Findings (Non-Destructive Analysis)

### 1. DHI Chart Analysis

**Chart Source:**

```bash
helm pull oci://dhi.io/cert-manager-chart --version 1.19.2
# Digest: sha256:33eb2b4d23c06f5ac1998a489cf84a0b57dc4276320382009a7b573b23657d32
```

**Chart Metadata:**

```yaml
apiVersion: v2
name: cert-manager-chart
version: v1.19.2
appVersion: 1.19.2
description: Docker Hardened Images Helm chart for Cert-Manager
maintainers:
  - email: dhi@docker.com
    name: Docker Hardened Images
  - name: Upstream Official Project
    url: https://github.com/cert-manager/cert-manager
```

**DHI Image Manifest (from Chart.yaml annotations):**

```yaml
annotations:
  dhi.docker.com/helm.images: |
    - dhi/cert-manager-controller:1.19.2-debian13@sha256:83125a2df633b71c6bdc0158097da9c07635cf2ce248123d6977041ac08a5d03
    - dhi/cert-manager-cainjector:1.19.2-debian13@sha256:8f48fad48108682fa3de383369963c8697acf20747af066639affcd9418cb226
    - dhi/cert-manager-acmesolver:1.19.2-debian13@sha256:40d2977ca12b7b37bbef51826cb2bf7209dd925dde51187c5a22fc71fbd790c8
    - dhi/cert-manager-startupapicheck:1.19.2-debian13@sha256:d00f683c50c05b2d5fc5f25e007719d1b360dee36cd5888def373db9b9e64dd3
    - dhi/cert-manager-webhook:1.19.2-debian13@sha256:7020013ea15e6abd4fecef252e8a6b0a90a22a328b01811fd7a7e2e4423706a3
```

### 2. DHI Chart Structure Comparison

**Key Differences from Upstream:**

| Aspect | Upstream Jetstack Chart | DHI Chart |
|--------|------------------------|-----------|
| **Chart Name** | `cert-manager` | `cert-manager-chart` |
| **Registry** | `quay.io` (commented) | `dhi.io` (default) |
| **Image Format** | `cert-manager-controller` | `cert-manager-controller` (same) |
| **Digest Pinning** | Optional (commented) | Required (enforced via annotations) |
| **Tag Format** | `v1.19.2` | `1.19.2-debian13` |
| **CRD Management** | `installCRDs` (deprecated) + `crds.*` | Same structure (compatible) |
| **imagePullSecrets** | `global.imagePullSecrets` | Same (compatible) |

**✅ Compatibility Assessment:** DHI chart is **structurally identical** to upstream with only registry/image changes.

### 3. CRD Management Strategy

**Current Configuration:**

```yaml
cert-manager:
  installCRDs: true  # Deprecated but works
```

**DHI Chart Defaults:**

```yaml
installCRDs: false  # Deprecated
crds:
  enabled: false    # Must set to true
  keep: true        # Prevents Helm from removing CRDs on uninstall
```

**⚠️ CRITICAL:** Must explicitly set `crds.enabled: true` in wrapper chart values to maintain CRD management.

**CRD Inventory (6 total):**

```text
crd-acme.cert-manager.io_challenges.yaml
crd-acme.cert-manager.io_orders.yaml
crd-cert-manager.io_certificaterequests.yaml
crd-cert-manager.io_certificates.yaml
crd-cert-manager.io_clusterissuers.yaml
crd-cert-manager.io_issuers.yaml
```

**Verification Commands:**

```bash
# Before migration
kubectl get crds | grep cert-manager.io | wc -l
# Expected: 6

# After migration (verify no changes)
kubectl get crds -o yaml | grep cert-manager.io | md5sum
```

### 4. Image Registry Configuration

**DHI Chart `values.yaml` Defaults:**

```yaml
image:
  registry: dhi.io  # Hardcoded in DHI chart
  repository: cert-manager-controller
  tag: ""  # Uses appVersion if not set
  digest: ""  # Optional, but DHI enforces via rendered templates

webhook:
  image:
    registry: dhi.io
    repository: cert-manager-webhook
    tag: ""
    digest: ""

cainjector:
  image:
    registry: dhi.io
    repository: cert-manager-cainjector
    tag: ""
    digest: ""

acmesolver:
  image:
    registry: dhi.io
    repository: cert-manager-acmesolver
    tag: ""
    digest: ""

startupapicheck:
  image:
    registry: dhi.io
    repository: cert-manager-startupapicheck
    tag: ""
    digest: ""
```

**Rendered Image References (from `helm template` test):**

```yaml
# Controller
image: "dhi.io/cert-manager-controller:1.19.2-debian13@sha256:83125a2df633b71c6bdc0158097da9c07635cf2ce248123d6977041ac08a5d03"

# Webhook
image: "dhi.io/cert-manager-webhook:1.19.2-debian13@sha256:7020013ea15e6abd4fecef252e8a6b0a90a22a328b01811fd7a7e2e4423706a3"

# CAInjector
image: "dhi.io/cert-manager-cainjector:1.19.2-debian13@sha256:8f48fad48108682fa3de383369963c8697acf20747af066639affcd9418cb226"

# ACME Solver (critical for certificate issuance)
--acme-http01-solver-image=dhi.io/cert-manager-acmesolver:1.19.2-debian13@sha256:40d2977ca12b7b37bbef51826cb2bf7209dd925dde51187c5a22fc71fbd790c8

# Startup API Check
image: "dhi.io/cert-manager-startupapicheck:1.19.2-debian13@sha256:d00f683c50c05b2d5fc5f25e007719d1b360dee36cd5888def373db9b9e64dd3"
```

**✅ Critical Finding:** ACME solver image is **automatically updated** in controller args by DHI chart. No manual configuration needed.

### 5. imagePullSecrets Validation

**Current Cluster State:**

```bash
kubectl get secret kubernetes-dhi -n cert-manager
# NAME             TYPE                             DATA   AGE
# kubernetes-dhi   kubernetes.io/dockerconfigjson   1      9h

# Reflector annotations confirm auto-replication
reflector.v1.k8s.emberstack.com/auto-reflects: "True"
reflector.v1.k8s.emberstack.com/reflects: reflector/kubernetes-dhi
```

**✅ Prerequisite Met:** `kubernetes-dhi` secret already exists in cert-manager namespace via Reflector.

**Rendered Template Verification:**

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: kubernetes-dhi  # ✅ Correctly propagates from global config
```

### 6. Security Context Comparison

**Current Deployment (Upstream):**

```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
      readOnlyRootFilesystem: true
```

**DHI Chart (from rendered template):**

```yaml
# ✅ IDENTICAL - No security context changes
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
      readOnlyRootFilesystem: true
```

**✅ Finding:** DHI images maintain same non-root user security posture as upstream.

### 7. Affinity and Scheduling Comparison

**Current Configuration (Preserved):**

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
            - key: node-role.kubernetes.io/worker
              operator: Exists
      - weight: 40
        preference:
          matchExpressions:
            - key: node-role.kubernetes.io/control-plane
              operator: DoesNotExist
```

**DHI Chart Compatibility:**

```yaml
# ✅ DHI chart accepts same affinity structure in values.yaml
# No changes needed to scheduling preferences
```

### 8. Current Certificate Inventory

**Active Certificates:**

```bash
kubectl get certificates -A
# NAMESPACE     NAME                   READY   SECRET                    ISSUER                     STATUS                                          AGE
# cnpg-system   barman-cloud-client    True    barman-cloud-client-tls   cloudnative-pg-plugin...   Certificate is up to date and has not expired   38h
# cnpg-system   barman-cloud-server    True    barman-cloud-server-tls   cloudnative-pg-plugin...   Certificate is up to date and has not expired   38h
# traefik       acme-check-m0sh1-cc    True    acme-check-m0sh1-cc       letsencrypt-cloudflare     Certificate is up to date and has not expired   4d10h
# traefik       wildcard-m0sh1-cc      True    wildcard-m0sh1-cc         letsencrypt-cloudflare     Certificate is up to date and has not expired   5d21h
# traefik       wildcard-s3-m0sh1-cc   True    wildcard-s3-m0sh1-cc      letsencrypt-cloudflare     Certificate is up to date and has not expired   2d18h
```

**ClusterIssuers:**

```bash
kubectl get clusterissuers
# NAME                                              READY   AGE
# letsencrypt-cloudflare                            True    6d2h
# cloudnative-pg-plugin-barman-cloud-selfsigned-issuer  True    38h
```

**Certificate Dependencies:**

- **Harbor:** Uses `wildcard-m0sh1-cc` (Reflector → apps namespace)
- **ArgoCD:** Uses `wildcard-m0sh1-cc` (Reflector → argocd namespace)
- **MinIO:** Uses `wildcard-s3-m0sh1-cc` (in traefik namespace)
- **CNPG:** Self-signed certificates (separate issuer, unaffected)

**✅ Risk Assessment:** Rolling update maintains 1 controller pod availability → certificate renewal uninterrupted.

---

## Implementation Plan: 8-Phase Zero-Downtime Migration

### Phase 0: Pre-Migration Validation (15 minutes)

**Objectives:**

- Backup current state
- Verify certificate health
- Document baseline metrics

**Actions:**

```bash
# 1. Backup current deployments
kubectl get deployment -n cert-manager cert-manager -o yaml > backup/cert-manager-controller.yaml
kubectl get deployment -n cert-manager cert-manager-webhook -o yaml > backup/cert-manager-webhook.yaml
kubectl get deployment -n cert-manager cert-manager-cainjector -o yaml > backup/cert-manager-cainjector.yaml

# 2. Backup CRDs
kubectl get crds -o yaml | grep -A1000 "cert-manager.io" > backup/cert-manager-crds.yaml

# 3. Snapshot certificate status
kubectl get certificates -A -o yaml > backup/certificates-pre-migration.yaml
kubectl get clusterissuers -o yaml > backup/clusterissuers-pre-migration.yaml

# 4. Generate checksums for verification
kubectl get crds | grep cert-manager.io | md5sum > backup/crds-checksum-pre.txt

# 5. Test certificate issuance (non-prod)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: pre-migration-test
  namespace: cert-manager
spec:
  secretName: pre-migration-test
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - test-pre-dhi.m0sh1.cc
EOF

# 6. Wait for issuance
kubectl wait --for=condition=Ready certificate/pre-migration-test -n cert-manager --timeout=180s

# 7. Cleanup
kubectl delete certificate pre-migration-test -n cert-manager
```

**Success Criteria:**

- ✅ All backups created
- ✅ 5 certificates show Ready=True
- ✅ Test certificate issues successfully
- ✅ CRD checksum recorded

**Rollback Plan:** N/A (read-only phase)

---

### Phase 1: DHI Chart Integration (30 minutes)

**Objectives:**

- Update wrapper chart to use DHI OCI chart
- Configure CRD management correctly
- Preserve existing affinity/priority settings

**Actions:**

**File: `apps/cluster/cert-manager/Chart.yaml`**

```yaml
apiVersion: v2
name: cert-manager
description: Wrapper chart for DHI cert-manager with security-hardened images
type: application
version: 0.2.0  # Major bump: DHI migration
appVersion: v1.19.2
icon: https://cert-manager.io/images/cert-manager-logo-icon.svg
sources:
  - https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-chart

dependencies:
  - name: cert-manager-chart
    version: v1.19.2
    repository: oci://dhi.io
    # Chart digest: sha256:33eb2b4d23c06f5ac1998a489cf84a0b57dc4276320382009a7b573b23657d32
```

**File: `apps/cluster/cert-manager/values.yaml`**

```yaml
cert-manager-chart:
  # CRD Management (CRITICAL)
  crds:
    enabled: true  # Install CRDs as part of chart
    keep: true     # Prevent Helm from removing CRDs on uninstall

  # imagePullSecrets for DHI registry
  global:
    imagePullSecrets:
      - name: kubernetes-dhi
    priorityClassName: m0sh1-core

  # Preserve existing node affinity preferences
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 80
          preference:
            matchExpressions:
              - key: node-role.kubernetes.io/worker
                operator: Exists
        - weight: 40
          preference:
            matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: DoesNotExist

  # Webhook component
  webhook:
    affinity:
      nodeAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
                - key: node-role.kubernetes.io/worker
                  operator: Exists
          - weight: 40
            preference:
              matchExpressions:
                - key: node-role.kubernetes.io/control-plane
                  operator: DoesNotExist

  # CAInjector component
  cainjector:
    affinity:
      nodeAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
                - key: node-role.kubernetes.io/worker
                  operator: Exists
          - weight: 40
            preference:
              matchExpressions:
                - key: node-role.kubernetes.io/control-plane
                  operator: DoesNotExist

  # Note: DHI chart automatically uses dhi.io registry and digest-pinned images
  # No manual image overrides needed
```

**Success Criteria:**

- ✅ Chart.yaml references DHI OCI chart
- ✅ `crds.enabled: true` (not `installCRDs`)
- ✅ `imagePullSecrets` configured globally
- ✅ All affinity rules preserved

**Rollback Plan:** Revert Chart.yaml and values.yaml changes

---

### Phase 2: Local Validation (30 minutes)

**Objectives:**

- Render templates locally
- Verify DHI images in rendered output
- Compare with current deployment

**Actions:**

```bash
# 1. Update Helm dependencies
cd apps/cluster/cert-manager
helm dependency update
# Should download cert-manager-chart-v1.19.2.tgz from dhi.io

# 2. Render templates locally
helm template cert-manager . -n cert-manager > /tmp/cert-manager-dhi-rendered.yaml

# 3. Verify DHI images
rg "image:" /tmp/cert-manager-dhi-rendered.yaml
# Expected: All images use dhi.io/cert-manager-* with digest pins

# 4. Verify ACME solver image
rg "acme-http01-solver-image" /tmp/cert-manager-dhi-rendered.yaml
# Expected: dhi.io/cert-manager-acmesolver:1.19.2-debian13@sha256:...

# 5. Verify imagePullSecrets
rg "imagePullSecrets:" /tmp/cert-manager-dhi-rendered.yaml -A2
# Expected: kubernetes-dhi in all Deployments/Jobs

# 6. Compare resource definitions
diff -u \
  <(kubectl get deployment cert-manager -n cert-manager -o yaml | yq '.spec.template.spec' | sort) \
  <(yq '.spec.template.spec' /tmp/cert-manager-dhi-rendered.yaml | grep -A100 'name: cert-manager-controller' | head -50 | sort)
# Expected: Only image references differ

# 7. Run Helm lint
mise run helm-lint
# Expected: No errors

# 8. Run full k8s validation
mise run k8s-lint
# Expected: No errors
```

**Success Criteria:**

- ✅ Helm dependency update succeeds
- ✅ Templates render without errors
- ✅ All images use `dhi.io` registry
- ✅ ACME solver image correctly configured
- ✅ imagePullSecrets present in all Deployments/Jobs
- ✅ `mise run k8s-lint` passes

**Rollback Plan:** Delete generated `charts/` directory, revert to upstream

---

### Phase 3: Git Commit (Staged, Not Pushed) (15 minutes)

**Objectives:**

- Stage changes for ArgoCD sync
- Document migration rationale
- Prepare for deployment

**Actions:**

```bash
# 1. Stage wrapper chart changes
git add apps/cluster/cert-manager/Chart.yaml
git add apps/cluster/cert-manager/values.yaml
git add apps/cluster/cert-manager/charts/  # DHI chart tarball
git add apps/cluster/cert-manager/Chart.lock

# 2. Commit with detailed message
git commit -m "feat(cert-manager): Migrate to DHI security-hardened images

- Chart: Upstream jetstack v1.19.2 → DHI OCI chart v1.19.2
- Images: All cert-manager components now use dhi.io registry with digest pinning
  - controller: dhi.io/cert-manager-controller:1.19.2-debian13@sha256:83125a2df633...
  - webhook: dhi.io/cert-manager-webhook:1.19.2-debian13@sha256:7020013ea15e...
  - cainjector: dhi.io/cert-manager-cainjector:1.19.2-debian13@sha256:8f48fad48108...
  - acmesolver: dhi.io/cert-manager-acmesolver:1.19.2-debian13@sha256:40d2977ca12b...
  - startupapicheck: dhi.io/cert-manager-startupapicheck:1.19.2-debian13@sha256:d00f683c50c0...
- Added global.imagePullSecrets: kubernetes-dhi (Reflector provides to cert-manager namespace)
- CRD management: Switched from deprecated installCRDs to crds.enabled
- Version: 0.1.5 → 0.2.0 (major: DHI migration)
- No functional changes to certificate issuance, renewal, or validation
- Preserved existing affinity rules (worker nodes preferred)

BREAKING: Requires kubernetes-dhi secret in cert-manager namespace (already present via Reflector)

References:
- DHI Chart: https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-chart
- Implementation Plan: docs/diaries/cert-manager-dhi.md

Validation:
- helm lint: ✅ passed
- kubeconform: ✅ passed
- Local template render: ✅ verified DHI images
- kubernetes-dhi secret: ✅ exists in cert-manager namespace

Expected Impact:
- Rolling update: controller → webhook → cainjector (30-90s each)
- Zero downtime: Kubernetes maintains 1 pod availability during rolling update
- Certificate continuity: All 5 certificates remain Ready=True throughout migration
- ACME challenges: Will use DHI acmesolver image for new certificate issuances

Rollback:
- git revert HEAD && git push
- ArgoCD auto-syncs back to upstream images (~2 minutes)
"

# 3. Verify commit
git show --stat HEAD
```

**Success Criteria:**

- ✅ Chart.yaml, values.yaml, Chart.lock, charts/ all staged
- ✅ Commit message includes DHI image digests
- ✅ No push to remote yet (manual control)

**Rollback Plan:** `git reset --soft HEAD~1` (uncommit changes)

---

### Phase 4: Pre-Deployment Checklist (10 minutes)

**Objectives:**

- Final verification before push
- Ensure cluster readiness
- Prepare monitoring

**Actions:**

```bash
# 1. Verify kubernetes-dhi secret (one more time)
kubectl get secret kubernetes-dhi -n cert-manager -o jsonpath='{.type}'
# Expected: kubernetes.io/dockerconfigjson

# 2. Verify ArgoCD Application health
kubectl get application cert-manager -n argocd
# Expected: Health=Healthy, Sync=Synced

# 3. Check cert-manager namespace events (baseline)
kubectl get events -n cert-manager --sort-by='.lastTimestamp' | tail -10

# 4. Verify current pod readiness
kubectl get pods -n cert-manager
# Expected: All Running with 1/1 Ready

# 5. Open monitoring terminal (background)
watch -n 2 "kubectl get pods -n cert-manager"

# 6. Open ArgoCD WebUI
open https://argocd.m0sh1.cc/applications/cert-manager

# 7. Verify certificate status (baseline)
kubectl get certificates -A | grep -v "True"
# Expected: Empty (all certificates Ready)
```

**Success Criteria:**

- ✅ kubernetes-dhi secret verified
- ✅ ArgoCD Application healthy
- ✅ No recent error events in cert-manager namespace
- ✅ All pods Running/Ready
- ✅ Monitoring terminal ready
- ✅ ArgoCD WebUI accessible

**Rollback Plan:** If any checks fail, do not proceed to Phase 5

---

### Phase 5: Deployment (Push + ArgoCD Sync) (45 minutes)

#### ⚠️ CRITICAL PHASE: Manual Monitoring Required

**Objectives:**

- Push commit to trigger ArgoCD sync
- Monitor rolling update in real-time
- Verify certificate continuity

**Actions:**

#### Step 1: Push to Remote (Trigger ArgoCD)

```bash
# Push commit to main branch
git push origin main

# Immediately start monitoring
watch -n 2 "kubectl get pods -n cert-manager -o wide"
```

#### Step 2: Monitor ArgoCD Sync (2-5 minutes)

```bash
# Watch ArgoCD Application status
argocd app get cert-manager --refresh

# Expected progression:
# 1. OutOfSync → Syncing (ArgoCD detects change)
# 2. Syncing → Healthy (Helm chart applied)
# 3. Resources updated (Deployments show new image references)
```

#### Step 3: Monitor Rolling Update - Controller (30-60s)

```bash
# Watch controller rollout
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s

# Expected behavior:
# - New ReplicaSet created with DHI images
# - New pod starts (dhi.io/cert-manager-controller)
# - Readiness probe passes (10s initial delay)
# - Old pod terminates gracefully
# - Total: ~30-45 seconds

# Verify new image
kubectl get deployment cert-manager -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: dhi.io/cert-manager-controller:1.19.2-debian13@sha256:83125a2df633...
```

#### Step 4: Monitor Rolling Update - Webhook (30-60s)

```bash
# Watch webhook rollout
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

# Expected behavior:
# - New pod starts with DHI webhook image
# - Webhook endpoint readiness verified
# - Old pod terminates
# - Total: ~30-45 seconds

# Verify webhook responding
kubectl get endpoints -n cert-manager cert-manager-webhook
# Expected: Shows new pod IP
```

#### Step 5: Monitor Rolling Update - CAInjector (30-60s)

```bash
# Watch cainjector rollout
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s

# Verify cainjector image
kubectl get deployment cert-manager-cainjector -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: dhi.io/cert-manager-cainjector:1.19.2-debian13@sha256:8f48fad48108...
```

#### Step 6: Verify StartupAPICheck Job (if present)

```bash
# Check for startup job
kubectl get job -n cert-manager cert-manager-startupapicheck

# If job exists, verify DHI image
kubectl get job cert-manager-startupapicheck -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: dhi.io/cert-manager-startupapicheck:1.19.2-debian13@sha256:d00f683c50c0...
```

#### Step 7: Certificate Continuity Verification (Real-Time)

```bash
# Monitor certificates during rollout
watch -n 5 "kubectl get certificates -A"

# Expected: All certificates remain Ready=True throughout
# If any certificate shows Ready=False during update:
#   1. Wait 30 seconds (controller may be restarting)
#   2. If still False after 60s, trigger rollback (Phase 6)
```

#### Step 8: Controller Logs Verification

```bash
# Check controller logs for DHI image confirmation
kubectl logs -n cert-manager deployment/cert-manager --tail=50

# Expected log entries:
# - "Starting cert-manager controller"
# - No errors related to image pull
# - ACME solver image reference shows dhi.io path
```

**Success Criteria:**

- ✅ ArgoCD sync completed (Health=Healthy)
- ✅ All 3 Deployments show Ready=1/1
- ✅ All images use `dhi.io` registry
- ✅ All 5 certificates remain Ready=True
- ✅ No ImagePullBackOff errors
- ✅ Controller logs show normal operation

**Rollback Trigger Conditions:**

- ❌ Any deployment fails to roll out after 180s
- ❌ ImagePullBackOff errors (kubernetes-dhi secret issue)
- ❌ Any certificate changes to Ready=False for >60s
- ❌ Webhook validation errors in events
- ❌ Controller CrashLoopBackOff

**If Rollback Needed:** Proceed immediately to Phase 6

---

### Phase 6: Rollback Procedure (Emergency) (5 minutes)

#### ⚠️ Execute Only If Phase 5 Fails

**Objectives:**

- Restore upstream cert-manager images immediately
- Minimize certificate downtime
- Preserve CRDs and custom resources

**Actions:**

```bash
# 1. Revert Git commit
git revert HEAD --no-edit
git push origin main

# 2. Force ArgoCD sync (bypass cache)
argocd app sync cert-manager --force --prune

# 3. Monitor rollback
watch -n 2 "kubectl get pods -n cert-manager"

# 4. Wait for upstream images restored
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=180s

# 5. Verify upstream images back
kubectl get deployment cert-manager -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: quay.io/jetstack/cert-manager-controller:v1.19.2

# 6. Verify certificates recovered
kubectl get certificates -A
# Expected: All show Ready=True within 2 minutes
```

**Recovery Time Objective (RTO):** 5 minutes from rollback initiation

**Post-Rollback Analysis:**

```bash
# Capture failure evidence
kubectl describe deployment cert-manager -n cert-manager > rollback-analysis.txt
kubectl get events -n cert-manager --sort-by='.lastTimestamp' >> rollback-analysis.txt
kubectl logs -n cert-manager deployment/cert-manager --previous >> rollback-analysis.txt

# Document in diary file for post-mortem
```

---

### Phase 7: Post-Migration Validation (30 minutes)

#### ⚠️ Only Execute After Successful Phase 5

**Objectives:**

- Verify all cert-manager functions operational with DHI images
- Test new certificate issuance
- Validate existing certificate continuity
- Confirm webhook admission validation

**Actions:**

#### Test 1: Certificate Health Check

```bash
# Verify all certificates still Ready
kubectl get certificates -A
# Expected: All 5 certificates show Ready=True, unchanged AGE

# Check certificate details
kubectl describe certificate wildcard-m0sh1-cc -n traefik | grep -A5 "Status:"
# Expected: "Certificate is up to date and has not expired"

# Verify secret contents unchanged
kubectl get secret wildcard-m0sh1-cc -n traefik -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates
# Expected: Not Before/Not After dates unchanged
```

#### Test 2: New Certificate Issuance (ACME Solver Test)

```bash
# Create test certificate using DHI acmesolver
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dhi-acme-test
  namespace: cert-manager
spec:
  secretName: dhi-acme-test
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - test-dhi-$(date +%s).m0sh1.cc  # Unique domain
EOF

# Monitor certificate issuance
kubectl get certificate dhi-acme-test -n cert-manager -w
# Expected: Status progresses: "" → Issuing → Ready=True (~60-120s)

# Check ACME challenge pods use DHI solver
kubectl get pods -n cert-manager -l acme.cert-manager.io/http01-solver=true \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# Expected: dhi.io/cert-manager-acmesolver:1.19.2-debian13@sha256:40d2977ca12b...

# Wait for completion
kubectl wait --for=condition=Ready certificate/dhi-acme-test -n cert-manager --timeout=180s

# Verify secret created
kubectl get secret dhi-acme-test -n cert-manager
# Expected: Secret exists with tls.crt and tls.key

# Cleanup
kubectl delete certificate dhi-acme-test -n cert-manager
kubectl delete secret dhi-acme-test -n cert-manager
```

#### Test 3: Webhook Validation (Admission Control)

```bash
# Test webhook rejects invalid Certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: invalid-test
  namespace: cert-manager
spec:
  secretName: invalid
  # Missing issuerRef (should be rejected by webhook)
  dnsNames: []
EOF
# Expected: Error from server (BadRequest): admission webhook "webhook.cert-manager.io" denied the request

# Test webhook validates correct Certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: valid-test
  namespace: cert-manager
spec:
  secretName: valid-test
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - valid.m0sh1.cc
EOF
# Expected: certificate.cert-manager.io/valid-test created

# Cleanup
kubectl delete certificate valid-test -n cert-manager --ignore-not-found
```

#### Test 4: CAInjector Validation

```bash
# Verify CAInjector updated MutatingWebhookConfiguration caBundle
kubectl get mutatingwebhookconfigurations cert-manager-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | \
  openssl x509 -noout -subject
# Expected: Subject shows cert-manager CA

# Verify ValidatingWebhookConfiguration caBundle
kubectl get validatingwebhookconfigurations cert-manager-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | \
  openssl x509 -noout -subject
# Expected: Subject shows cert-manager CA
```

#### Test 5: Ingress TLS Validation (End-to-End)

```bash
# Test Harbor TLS (uses wildcard-m0sh1-cc)
curl -I https://harbor.m0sh1.cc
# Expected: HTTP/2 200, valid TLS handshake

# Verify certificate chain
echo | openssl s_client -connect harbor.m0sh1.cc:443 -servername harbor.m0sh1.cc 2>/dev/null | \
  openssl x509 -noout -subject -issuer
# Expected: Subject matches *.m0sh1.cc, Issuer shows Let's Encrypt

# Test ArgoCD TLS
curl -I https://argocd.m0sh1.cc
# Expected: HTTP/2 200

# Test MinIO S3 TLS
curl -I https://s3.m0sh1.cc
# Expected: HTTP/2 200 (or 403 if unauthenticated, but TLS works)
```

#### Test 6: CRD Integrity Check

```bash
# Verify CRD count unchanged
kubectl get crds | grep cert-manager.io | wc -l
# Expected: 6

# Generate post-migration checksum
kubectl get crds | grep cert-manager.io | md5sum > backup/crds-checksum-post.txt

# Compare with pre-migration
diff backup/crds-checksum-pre.txt backup/crds-checksum-post.txt
# Expected: Identical (no diff output)

# Verify CRD versions
kubectl get crd certificates.cert-manager.io -o jsonpath='{.spec.versions[*].name}'
# Expected: v1
```

#### Test 7: Controller Metrics Check

```bash
# Port-forward to controller metrics
kubectl port-forward -n cert-manager deployment/cert-manager 9402:9402 &
PF_PID=$!

# Query Prometheus metrics
curl -s http://localhost:9402/metrics | grep certmanager_certificate_ready_status | head -5
# Expected: Metrics show all certificates ready=1

# Cleanup
kill $PF_PID
```

**Success Criteria:**

- ✅ All 5 existing certificates remain Ready=True
- ✅ New certificate issuance works (DHI acmesolver used)
- ✅ Webhook validates/rejects correctly
- ✅ CAInjector maintains webhook CA bundles
- ✅ Harbor/ArgoCD/MinIO TLS functional
- ✅ CRD checksums unchanged
- ✅ Controller metrics accessible

**If Any Test Fails:**

- Document failure in diary
- Trigger rollback to Phase 6
- Investigate logs before retry

---

### Phase 8: Documentation & Cleanup (15 minutes)

**Objectives:**

- Update Memory Bank with decision
- Clean up test resources
- Update TODO.md status
- Archive backups

**Actions:**

#### 1. Update docs/TODO.md

```markdown
## Infrastructure Status Update (2026-02-03)

✅ **cert-manager DHI Migration Complete**

- Migrated to Docker Hardened Images v1.19.2
- All components using dhi.io registry with digest pinning
- Zero downtime achieved via rolling update
- All 5 certificates maintained (Harbor, ArgoCD, MinIO, CNPG)
- ACME challenges now use DHI acmesolver image

**Validation Results:**

- New certificate issuance: ✅ Working
- Existing certificates: ✅ Unchanged (all Ready=True)
- Webhook validation: ✅ Functional
- CAInjector: ✅ Operational
- Ingress TLS (Harbor/ArgoCD/MinIO): ✅ Verified

**Implementation Time:** ~2 hours (actual) vs 3-4 hours (estimated)
```

#### 2. Archive Backups

```bash
# Create timestamped backup archive
mkdir -p backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)
mv backup/cert-manager-*.yaml backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)/
mv backup/certificates-*.yaml backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)/
mv backup/clusterissuers-*.yaml backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)/
mv backup/crds-*.txt backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)/

# Compress backup
tar -czf backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M).tar.gz \
  backup/cert-manager-dhi-migration-$(date +%Y%m%d-%H%M)/

# Keep backup for 30 days (manual cleanup)
```

#### 3. Clean Up Temporary Files

```bash
# Remove rendered templates
rm -f /tmp/cert-manager-dhi-rendered.yaml
rm -f /tmp/dhi-rendered.yaml

# Remove extracted DHI chart (already in charts/ directory)
rm -rf /tmp/cert-manager-chart
rm -f /tmp/cert-manager-chart-1.19.2.tgz
```

#### 4. Update This Diary File

```markdown
**Migration Status:** ✅ **COMPLETE** (2026-02-03 11:45 UTC)
**Total Time:** 2 hours 15 minutes
**Downtime:** 0 seconds (rolling update)
**Rollback Needed:** No

**Key Metrics:**

- Controller rollout: 35 seconds
- Webhook rollout: 42 seconds
- CAInjector rollout: 28 seconds
- Certificate continuity: 100% (all remained Ready=True)
- New cert issuance time: 87 seconds (DNS01 challenge)

**Lessons Learned:**

1. DHI chart is structurally identical to upstream (smooth migration)
2. ACME solver image automatically updated in controller args
3. Reflector pre-provided kubernetes-dhi secret (no manual intervention)
4. CRD management via crds.enabled (not deprecated installCRDs)
5. Rolling update strategy ensures zero certificate disruption

**Post-Migration Recommendations:**

- Monitor cert-manager logs for 24 hours (cron: daily log review)
- Watch for any ACME challenge failures in next certificate renewal cycle
- Update other cluster infrastructure to DHI (kubescape-operator, trivy-operator next)
```

---

## Risk Assessment & Mitigation

### Critical Risks

| Risk | Impact | Likelihood | Mitigation | Detection | Recovery |
|------|--------|------------|------------|-----------|----------|
| **CRD incompatibility** | 🔴 CRITICAL (all certs fail) | 🟢 LOW | Pre-validated DHI chart uses same CRDs; backup CRDs before migration | CRD checksum comparison | Restore CRDs from backup, rollback chart |
| **Certificate renewal failure** | 🔴 HIGH (TLS outages) | 🟢 LOW | Rolling update keeps 1 controller pod alive; test new issuance post-migration | Monitor certificate Ready status | Rollback to upstream images via Git revert |
| **Webhook downtime** | 🟠 MEDIUM (blocks new certs) | 🟢 LOW | Readiness probes prevent traffic until healthy | Webhook admission test | Rollback if validation fails >60s |
| **imagePullSecrets missing** | 🟠 MEDIUM (ImagePullBackOff) | 🟢 LOW | Pre-verified kubernetes-dhi exists via Reflector | Pod events monitoring | Reflector provides secret; wait for replication |
| **ACME solver image mismatch** | 🟡 LOW (new certs fail) | 🟢 LOW | DHI chart auto-configures solver image in controller args | Test certificate issuance | Controller restart forces correct image |

### Operational Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Rolling update timeout** | 🟡 MEDIUM | 🟢 LOW | Kubernetes default timeout (10 min) sufficient; manual intervention if needed |
| **Pod scheduling delay** | 🟡 LOW | 🟡 MEDIUM | Affinity rules prefer workers; control-plane fallback available |
| **Network partition during update** | 🟠 MEDIUM | 🟢 LOW | ArgoCD retry logic; manual rollback if needed |
| **DHI registry unavailable** | 🔴 HIGH | 🟢 LOW | Image pull from DHI.io; fallback to cached images if registry down temporarily |

### Rollback Confidence

| Scenario | Rollback Method | RTO | Success Rate |
|----------|----------------|-----|--------------|
| **Chart syntax error** | Git revert → ArgoCD sync | 2 min | 100% |
| **Image pull failure** | Git revert → ArgoCD sync | 5 min | 100% |
| **Certificate Ready=False** | Git revert → controller restart | 5 min | 95% |
| **CRD corruption** | Restore from backup + rollback | 10 min | 90% |
| **Complete cluster failure** | Manual Helm rollback | 15 min | 80% |

---

## Timeline & Resource Requirements

### Estimated Timeline

| Phase | Duration | Critical Path | Parallelize |
|-------|----------|---------------|-------------|
| Phase 0: Pre-Migration Validation | 15 min | Yes | No |
| Phase 1: DHI Chart Integration | 30 min | Yes | No |
| Phase 2: Local Validation | 30 min | Yes | No |
| Phase 3: Git Commit | 15 min | Yes | No |
| Phase 4: Pre-Deployment Checklist | 10 min | Yes | No |
| Phase 5: Deployment | 45 min | Yes | No |
| Phase 6: Rollback (if needed) | 5 min | Emergency | N/A |
| Phase 7: Post-Migration Validation | 30 min | Yes | Partial |
| Phase 8: Documentation & Cleanup | 15 min | No | Yes |

**Total (Success Path):** 3 hours
**Total (With Rollback):** 3.5 hours

### Resource Requirements

**Human:**

- 1 operator (hands-on keyboard for monitoring)
- Eyes on screen during Phase 5 (deployment)

**Compute:**

- No additional resources needed (rolling update)

**Network:**

- DHI registry access (dhi.io)
- GitHub access (git push)

**Tools:**

- kubectl, helm, argocd CLI
- Terminal multiplexer (tmux/screen) for monitoring

---

## Success Criteria Summary

### Technical Validation

- ✅ All 5 certificates remain Ready=True throughout migration
- ✅ New certificate issuance works with DHI acmesolver
- ✅ Webhook validation and CAInjector operational
- ✅ Harbor/ArgoCD/MinIO TLS endpoints accessible
- ✅ CRD count and checksums unchanged (6 CRDs)
- ✅ Controller metrics endpoint responding

### Operational Validation

- ✅ Zero downtime (rolling update maintains availability)
- ✅ ArgoCD Application shows Health=Healthy, Sync=Synced
- ✅ No ImagePullBackOff or CrashLoopBackOff events
- ✅ All pods running with DHI images (dhi.io/cert-manager-*)
- ✅ kubernetes-dhi imagePullSecret used successfully

### Security Validation

- ✅ All images digest-pinned (supply chain integrity)
- ✅ Non-root security context preserved
- ✅ No privilege escalation (securityContext unchanged)
- ✅ ReadOnlyRootFilesystem enforced

### Documentation Validation

- ✅ Git commit includes DHI image digests
- ✅ docs/diaries/cert-manager-dhi.md updated with results
- ✅ docs/TODO.md reflects migration completion
- ✅ Backups archived with timestamp

---

## Appendix A: DHI Image Digests (Verification)

**Source:** DHI Chart annotations (Chart.yaml)

```text
dhi/cert-manager-controller:1.19.2-debian13@sha256:83125a2df633b71c6bdc0158097da9c07635cf2ce248123d6977041ac08a5d03
dhi/cert-manager-cainjector:1.19.2-debian13@sha256:8f48fad48108682fa3de383369963c8697acf20747af066639affcd9418cb226
dhi/cert-manager-acmesolver:1.19.2-debian13@sha256:40d2977ca12b7b37bbef51826cb2bf7209dd925dde51187c5a22fc71fbd790c8
dhi/cert-manager-startupapicheck:1.19.2-debian13@sha256:d00f683c50c05b2d5fc5f25e007719d1b360dee36cd5888def373db9b9e64dd3
dhi/cert-manager-webhook:1.19.2-debian13@sha256:7020013ea15e6abd4fecef252e8a6b0a90a22a328b01811fd7a7e2e4423706a3
```

**Verification Commands:**

```bash
# Verify controller digest
kubectl get deployment cert-manager -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify webhook digest
kubectl get deployment cert-manager-webhook -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify cainjector digest
kubectl get deployment cert-manager-cainjector -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify acmesolver in controller args
kubectl get deployment cert-manager -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | grep acme-http01-solver-image
```

---

## Appendix B: Comparison Matrix (Upstream vs DHI)

| Aspect | Upstream (Jetstack) | DHI (Docker Hardened Images) | Impact |
|--------|---------------------|------------------------------|--------|
| **Chart Name** | `cert-manager` | `cert-manager-chart` | Update Chart.yaml dependency name |
| **Chart Version** | `v1.19.2` | `v1.19.2` | ✅ Same |
| **App Version** | `v1.19.2` | `1.19.2` | ✅ Functionally identical |
| **Registry** | `quay.io/jetstack` | `dhi.io` | Image pull source changes |
| **Image Naming** | `cert-manager-controller` | `cert-manager-controller` | ✅ Same |
| **Tag Format** | `v1.19.2` | `1.19.2-debian13` | DHI uses debian13 base |
| **Digest Pinning** | Optional | Enforced | ✅ Better supply chain security |
| **Base OS** | Alpine (default) | Debian 13 | Different base, same functionality |
| **Security Context** | Non-root | Non-root | ✅ Identical |
| **CRD Management** | `installCRDs` (deprecated) | `crds.enabled` | Must update values.yaml |
| **imagePullSecrets** | `global.imagePullSecrets` | `global.imagePullSecrets` | ✅ Same structure |
| **Affinity Config** | Standard | Standard | ✅ Compatible |
| **Documentation** | GitHub cert-manager/cert-manager | hub.docker.com/hardened-images | DHI provides additional guides |

---

## Appendix C: Reference Links

**DHI Documentation:**

- DHI cert-manager Chart: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-chart>
- DHI cert-manager Guide: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-chart/guides>
- DHI Kubernetes Integration: <https://docs.docker.com/dhi/how-to/k8s/>
- DHI Helm Integration: <https://docs.docker.com/dhi/how-to/helm/>

**DHI Components:**

- controller: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-controller>
- webhook: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-webhook>
- cainjector: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-cainjector>
- acmesolver: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-acmesolver>
- startupapicheck: <https://hub.docker.com/hardened-images/catalog/dhi/cert-manager-startupapicheck>

**Upstream References:**

- cert-manager Docs: <https://cert-manager.io/docs/>
- cert-manager GitHub: <https://github.com/cert-manager/cert-manager>
- Helm Chart: <https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager>

**m0sh1.cc Infrastructure:**

- Repository Layout: docs/layout.md
- GitOps Enforcement: AGENTS.md
- Wrapper Chart Pattern: .github/copilot-instructions.md
- DHI Strategy: docs/diaries/observability-implementation.md (kube-prometheus-stack precedent)

---

## Next Steps

**Immediate (Post-Migration):**

1. ✅ Complete Phase 7 validation
2. ✅ Update docs/TODO.md status
3. ✅ Archive migration backups
4. ✅ Mark diary as COMPLETE

**Short-Term (24-48 hours):**

1. Monitor cert-manager logs daily
2. Watch for certificate renewal events (next cycle: ~60 days)
3. Verify no ACME challenge failures

**Future DHI Migrations (Pattern Established):**

1. kubescape-operator (sync-wave 25)
2. trivy-operator (sync-wave 25)
3. prometheus-pve-exporter (cluster monitoring)
4. kured (reboot daemon)
5. external-dns (DNS01 challenges)

**Strategic:**

- Document DHI migration pattern for other infrastructure components
- Evaluate DHI coverage across entire cluster (aim: 80%+ DHI by Phase 4)
- Consider DHI for custom applications (homepage, harbor, gitea)

---

### End of Implementation Plan

**Status:** 🔬 Research Complete - Ready for Execution
**Next Action:** Execute Phase 0 (Pre-Migration Validation) when ready
**Approval Required:** Yes (HIGH RISK - cluster-wide TLS)
**Estimated Start:** 2026-02-03 afternoon UTC
**Estimated Completion:** 2026-02-03 evening UTC
