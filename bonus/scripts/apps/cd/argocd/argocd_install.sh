#!/bin/bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(
    cd "$SCRIPT_DIR/../../../.."
    pwd
)"

ARGOCD_CONF_DIR="$PROJECT_ROOT/confs/apps/cd/argocd"
DEV_CONF_DIR="$PROJECT_ROOT/confs/apps/cd/dev"


# ============================================================
# Kubernetes
# ============================================================

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

KUBECTL=(
    kubectl
    --kubeconfig
    "$KUBECONFIG_PATH"
)


# ============================================================
# Check CD node
# ============================================================

echo "===> Checking CD node"

"${KUBECTL[@]}" wait \
    --for=condition=Ready \
    node/cd \
    --timeout=180s


CD_WORKLOAD=$(
    "${KUBECTL[@]}" get node cd \
        -o jsonpath='{.metadata.labels.workload}'
)


if [ "$CD_WORKLOAD" != "cd" ]; then

    echo "ERROR: node cd does not have workload=cd"
    exit 1

fi

echo "CD node is ready."


# ============================================================
# Namespaces
# ============================================================

echo "===> Creating Argo CD namespace"

"${KUBECTL[@]}" apply \
    -f "$ARGOCD_CONF_DIR/namespace.yaml"


echo "===> Creating dev namespace"

"${KUBECTL[@]}" apply \
    -f "$DEV_CONF_DIR/namespace.yaml"


# ============================================================
# Install Argo CD
# ============================================================

echo "===> Installing Argo CD"

"${KUBECTL[@]}" apply \
    --server-side \
    --force-conflicts \
    -k "$ARGOCD_CONF_DIR"


# ============================================================
# Wait for CRDs
# ============================================================

echo "===> Waiting for Argo CD CRDs"

"${KUBECTL[@]}" wait \
    --for=condition=Established \
    crd/applications.argoproj.io \
    --timeout=180s


# ============================================================
# Wait for Argo CD
# ============================================================

echo "===> Waiting for Argo CD pods"

"${KUBECTL[@]}" wait \
    --namespace argocd \
    --for=condition=Ready \
    pod \
    --all \
    --timeout=600s


# ============================================================
# Verify placement
# ============================================================

echo "===> Checking Argo CD pod placement"

"${KUBECTL[@]}" get pods \
    -n argocd \
    -o wide


INVALID_PLACEMENT=$(
    "${KUBECTL[@]}" get pods \
        -n argocd \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.nodeName}{"\n"}{end}' \
    | awk '$2 != "cd" {print}'
)


if [ -n "$INVALID_PLACEMENT" ]; then

    echo "ERROR: Some Argo CD pods are not running on node cd:"
    echo "$INVALID_PLACEMENT"

    exit 1

fi


echo "All Argo CD pods are running on node cd."


# ============================================================
# Create Argo CD Application
# ============================================================

echo "===> Creating Argo CD Application"

"${KUBECTL[@]}" apply \
    -f "$ARGOCD_CONF_DIR/application.yaml"


# ============================================================
# Status
# ============================================================

echo
echo "===> Argo CD resources"

"${KUBECTL[@]}" get pods \
    -n argocd \
    -o wide


echo
echo "===> Argo CD applications"

"${KUBECTL[@]}" get applications \
    -n argocd


echo
echo "===> Dev resources"

"${KUBECTL[@]}" get all \
    -n dev \
    -o wide


echo
echo "================================"
echo " Argo CD installation complete"
echo "================================"