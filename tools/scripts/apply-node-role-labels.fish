#!/usr/bin/env fish
# Apply node-role labels that cannot be set via kubelet
# Must be run after k3s cluster bootstrap is complete
# NOTE: Operator-only imperative helper (kubectl); do not run in CI. GitOps changes belong in Git/ArgoCD.
#
# Kubernetes rejects node-role.kubernetes.io/* labels when applied via kubelet
# (which is how k3s applies k3s_node_labels). These must be applied via kubectl
# after the cluster is running.

set -l CONTROL_PLANE lab-ctrl
set -l WORKERS horse01 horse02 horse03 horse04

# Check if kubectl is available
if not command -q kubectl
    echo "Error: kubectl not found in PATH" >&2
    exit 1
end

# Check if cluster is reachable
if not kubectl get nodes &>/dev/null
    echo "Error: Cannot reach Kubernetes cluster. Ensure kubeconfig is configured." >&2
    exit 1
end

echo "Applying node-role labels..."

# Label control plane
echo "  Labeling control plane: $CONTROL_PLANE"
kubectl label node $CONTROL_PLANE node-role.kubernetes.io/control-plane=true --overwrite

# Label workers
for worker in $WORKERS
    echo "  Labeling worker: $worker"
    kubectl label node $worker node-role.kubernetes.io/worker=true --overwrite
end

echo ""
echo "✅ Node role labels applied successfully"
echo ""
echo "Verify with:"
echo "  kubectl get nodes --show-labels | grep node-role"
