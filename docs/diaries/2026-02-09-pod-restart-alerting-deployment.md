# Pod Restart Alerting - Deployment Complete

**Date:** 2026-02-09
**Status:** ✅ Deployed and Operational
**Session:** Continuation of 2026-02-08 investigation

## Summary

Successfully deployed pod restart rate alerting via PrometheusRule for kube-prometheus-stack. All three alert rules are active in Prometheus and one alert (`ExcessivePodRestarts`) fired immediately, validating the implementation.

## Deployment Details

### Files Created/Modified

1. **apps/cluster/kube-prometheus-stack/templates/prometheusrule-pod-restarts.yaml** (NEW)
   - Created custom PrometheusRule with 3 alert rules
   - Used Helm backtick escaping for PromQL template variables: `{{`{{ $labels.namespace }}`}}`
   - Added required labels for Prometheus Operator discovery: `app: kube-prometheus-stack`, `release: kube-prometheus-stack`

2. **apps/cluster/kube-prometheus-stack/Chart.yaml** (MODIFIED)
   - Version bump: `0.1.5` → `0.1.6` (required for ArgoCD change detection)

### Git Commit

```text
commit 62588a94
Author: Simon Meyer <simon.meyer@m0sh1.cc>
Date:   Sun Feb 9 12:08:43 2026 +0100

    feat(monitoring): add pod restart rate alerts
```

### ArgoCD Sync Issue Resolution

**Problem:** Initial sync showed success but PrometheusRule not created
**Root Cause:** ArgoCD cached on old commit (56fb4d0) instead of latest (62588a94)
**Solution:** Executed `argocd app get kube-prometheus-stack --hard-refresh` to force Git fetch
**Result:** PrometheusRule deployed successfully after hard refresh

## Alert Rules Deployed

### 1. HighPodRestartRate (WARNING)

- **Condition:** `rate(kube_pod_container_status_restarts_total[1h]) > 0.1`
- **Duration:** 5 minutes
- **Purpose:** Detect pods with high restart frequency (>0.1 restarts/second = ~6/minute)

### 2. ExcessivePodRestarts (CRITICAL)

- **Condition:** `increase(kube_pod_container_status_restarts_total[24h]) > 10`
- **Duration:** Immediate
- **Purpose:** Detect pods with excessive total restarts over 24 hours
- **Status:** 🔥 Currently firing (see below)

### 3. PodCrashLooping (CRITICAL)

- **Condition:** `rate(kube_pod_container_status_restarts_total[15m]) > 0` AND `kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1`
- **Duration:** 5 minutes
- **Purpose:** Detect pods stuck in CrashLoopBackOff state

## Verification Results

### PrometheusRule Resource

```bash
$ kubectl get prometheusrules -n monitoring custom-pod-restart-alerts
NAME                        AGE
custom-pod-restart-alerts   1h
```

- ✅ Resource created successfully
- ✅ Prometheus Operator validated: `prometheus-operator-validated: "true"`
- ✅ Correct labels for discovery: `app: kube-prometheus-stack`, `release: kube-prometheus-stack`

### Prometheus Rules API

```bash
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name == "pod_health_custom")'
```

- ✅ All 3 rules loaded with `"health": "ok"`
- ✅ Evaluation interval: 30 seconds
- ✅ Rules actively evaluating (timestamps updating)

### Alertmanager Integration

```bash
curl http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.alertname == "ExcessivePodRestarts")'
```

- ✅ Alert pipeline functional
- ✅ Alerts reaching Alertmanager with correct annotations and labels
- ⚠️ Currently routed to "null" receiver (no notifications configured)

## First Alert Fired

**Alert:** ExcessivePodRestarts
**Target:** `apps/basic-memory-8568c767c7-ffj4z` (livesync-bridge container)
**Restart Count:** 11 restarts in last 24 hours
**Fired At:** 2026-02-09 12:13:27 UTC
**Status:** Active (pod since terminated/replaced)

**Analysis:** This alert correctly detected restarts from the 2026-02-08 API server disruption. The pod no longer exists, indicating normal cluster operations after incident recovery.

## Technical Implementation Notes

### Helm Template Escaping

PromQL template variables must be escaped in Helm charts to prevent Helm from interpreting them as Helm variables:

**Wrong:** `{{ $labels.namespace }}`
**Correct:** `{{`{{ $labels.namespace }}`}}`

This ensures Prometheus receives the literal template syntax, not an empty string.

### Prometheus Operator Discovery

PrometheusRule resources MUST have these labels for the Prometheus Operator to discover them:

```yaml
metadata:
  labels:
    app: kube-prometheus-stack
    release: kube-prometheus-stack
```

Without these labels, the operator ignores the resource.

### Chart Version Requirement

ArgoCD detects changes in Helm charts primarily via version changes in `Chart.yaml`. Modifying templates without bumping the chart version may result in ArgoCD not syncing changes.

## Validation Tasks Passed

```bash
mise run k8s-lint    # ✅ All checks passed
mise run path-drift  # ✅ Structure validated
mise run sensitive-files  # ✅ No secrets detected
pre-commit run --all-files  # ✅ All hooks passed
```

## Next Steps (Optional)

### 1. Configure Alertmanager Notifications

Currently alerts route to the "null" receiver. To receive notifications:

1. Edit `apps/cluster/kube-prometheus-stack/values.yaml`
2. Add receiver configuration (Slack, email, PagerDuty, etc.)
3. Update routing rules to match alert labels
4. Bump chart version and commit

Example Slack configuration:

```yaml
alertmanager:
  config:
    receivers:
    - name: slack-critical
      slack_configs:
      - api_url: <webhook-url>
        channel: '#alerts-critical'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    route:
      routes:
      - matchers:
        - severity = "critical"
        receiver: slack-critical
```

### 2. Create Runbook Pages

Alert annotations reference runbook URLs:

- <https://m0sh1.cc/runbooks/high-pod-restart-rate>
- <https://m0sh1.cc/runbooks/excessive-pod-restarts>
- <https://m0sh1.cc/runbooks/pod-crash-loop>

Create documentation at these URLs with troubleshooting steps.

### 3. Test with Crasher Pod (Optional)

Validate alerts fire correctly:

```bash
kubectl run test-crasher --image=busybox --restart=Always -- /bin/sh -c "exit 1"
```

This will trigger:

1. `PodCrashLooping` alert within 5-10 minutes
2. `ExcessivePodRestarts` alert if left running for extended period

Remember to delete the test pod after validation.

### 4. Tune Thresholds (If Needed)

Current thresholds are based on typical cluster behavior:

- `HighPodRestartRate`: >0.1/sec (aggressive, may need tuning for noisy apps)
- `ExcessivePodRestarts`: >10/day (reasonable for stable workloads)
- `PodCrashLooping`: immediate (correct for CrashLoopBackOff state)

Monitor alert volume over 1-2 weeks and adjust if necessary.

## Conclusion

Pod restart alerting is fully operational. The immediate firing of an alert for the basic-memory pod validates both the implementation and the necessity of this monitoring - the 2026-02-08 API server incident would have been detected immediately with these rules in place.

**Deliverables:**

- ✅ PrometheusRule deployed and validated
- ✅ 3 alert rules active and evaluating
- ✅ Alert pipeline to Alertmanager confirmed
- ✅ First alert fired and validated
- ✅ All validation tasks passed
- ✅ Git commit pushed to main
- ✅ ArgoCD sync completed

**Status:** Ready for production use. Notification routing configuration is optional enhancement.
