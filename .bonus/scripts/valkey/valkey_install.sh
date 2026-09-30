#!/bin/bash
set -euo pipefail

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

KUBECTL=(
    kubectl
    --kubeconfig
    "$KUBECONFIG_PATH"
)

HELM=(
    helm
    --kubeconfig
    "$KUBECONFIG_PATH"
)

VALKEY_CHART_VERSION="0.11.0"

# ============================================================
# Check requirements
# ============================================================

echo "===> Checking Helm"

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm is not installed."
    exit 1
fi

echo "===> Checking data node"

"${KUBECTL[@]}" wait \
    --for=condition=Ready \
    node/data \
    --timeout=180s

DATA_WORKLOAD=$(
    "${KUBECTL[@]}" get node data \
        -o jsonpath='{.metadata.labels.workload}'
)

if [ "$DATA_WORKLOAD" != "data" ]; then
    echo "ERROR: node data does not have workload=data"
    exit 1
fi

# ============================================================
# Configure Valkey Helm repository
# ============================================================

echo "===> Configuring Valkey Helm repository"

"${HELM[@]}" repo add \
    valkey \
    https://valkey.io/valkey-helm/ \
    --force-update

"${HELM[@]}" repo update

# ============================================================
# Valkey credentials
# ============================================================

echo "===> Checking Valkey credentials"

if ! "${KUBECTL[@]}" \
    -n gitlab \
    get secret gitlab-valkey-auth \
    >/dev/null 2>&1; then

    echo "===> Creating Valkey credentials"

    VALKEY_PASSWORD=$(openssl rand -hex 24)

    "${KUBECTL[@]}" \
        -n gitlab \
        create secret generic gitlab-valkey-auth \
        --from-literal="redis-password=${VALKEY_PASSWORD}"

else
    echo "Valkey credentials already exist."
fi

# ============================================================
# Install Valkey
# ============================================================

echo "===> Installing Valkey"

"${HELM[@]}" upgrade \
    --install \
    gitlab-valkey \
    valkey/valkey \
    --namespace gitlab \
    --version "$VALKEY_CHART_VERSION" \
    -f /vagrant/confs/valkey/values.yaml \
    --wait \
    --timeout 5m

# ============================================================
# Check deployment
# ============================================================

echo "===> Waiting for Valkey"

"${KUBECTL[@]}" \
    -n gitlab \
    wait \
    --for=condition=Available \
    deployment/gitlab-valkey \
    --timeout=180s

echo "===> Valkey pods"

"${KUBECTL[@]}" \
    -n gitlab \
    get pods \
    -l app.kubernetes.io/name=valkey \
    -o wide

echo "===> Valkey service"

"${KUBECTL[@]}" \
    -n gitlab \
    get services \
    -l app.kubernetes.io/name=valkey

echo "===> Valkey persistent volume"

"${KUBECTL[@]}" \
    -n gitlab \
    get pvc

echo "===> Valkey installation completed"