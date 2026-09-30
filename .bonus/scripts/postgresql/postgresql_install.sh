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

CNPG_CHART_VERSION="0.29.1"

# ============================================================
# Check cluster
# ============================================================

echo "===> Checking Kubernetes cluster"

EXPECTED_NODES=(
    bberkrous
    gitlab
    data
    cd
)

for NODE in "${EXPECTED_NODES[@]}"; do

    if ! "${KUBECTL[@]}" get node "$NODE" >/dev/null 2>&1; then
        echo "Cluster is not complete yet."
        echo "Missing node: $NODE"
        echo "PostgreSQL installation skipped."
        exit 0
    fi

done

# ============================================================
# Wait for nodes
# ============================================================

echo "===> Waiting for Kubernetes nodes"

for NODE in "${EXPECTED_NODES[@]}"; do

    echo "Waiting for node: $NODE"

    "${KUBECTL[@]}" wait \
        --for=condition=Ready \
        "node/${NODE}" \
        --timeout=180s

done

# ============================================================
# Check data node
# ============================================================

echo "===> Checking data node label"

DATA_WORKLOAD=$(
    "${KUBECTL[@]}" get node data \
        -o jsonpath='{.metadata.labels.workload}'
)

if [ "$DATA_WORKLOAD" != "data" ]; then
    echo "ERROR: node data does not have workload=data"
    exit 1
fi

echo "Node data is correctly labelled."

# ============================================================
# Check Helm
# ============================================================

echo "===> Checking Helm"

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm is not installed."
    exit 1
fi

helm version

# ============================================================
# Check storage
# ============================================================

echo "===> Checking local-path StorageClass"

if ! "${KUBECTL[@]}" get storageclass local-path \
    >/dev/null 2>&1; then

    echo "ERROR: local-path StorageClass was not found."
    exit 1
fi

# ============================================================
# CloudNativePG repository
# ============================================================

echo "===> Configuring CloudNativePG Helm repository"

"${HELM[@]}" repo add \
    cnpg \
    https://cloudnative-pg.github.io/charts \
    --force-update

"${HELM[@]}" repo update

# ============================================================
# CloudNativePG operator
# ============================================================

echo "===> Installing CloudNativePG operator"

"${HELM[@]}" upgrade \
    --install \
    cnpg \
    cnpg/cloudnative-pg \
    --namespace cnpg-system \
    --create-namespace \
    --version "$CNPG_CHART_VERSION" \
    --wait \
    --timeout 5m

echo "===> Waiting for CloudNativePG operator"

"${KUBECTL[@]}" wait \
    --namespace cnpg-system \
    --for=condition=Available \
    deployment \
    --all \
    --timeout=180s

# ============================================================
# PostgreSQL credentials
# ============================================================

echo "===> Checking PostgreSQL credentials"

if ! "${KUBECTL[@]}" \
    --namespace gitlab \
    get secret gitlab-postgresql-auth \
    >/dev/null 2>&1; then

    echo "Creating PostgreSQL credentials"

    POSTGRES_PASSWORD=$(openssl rand -hex 24)

    "${KUBECTL[@]}" \
        --namespace gitlab \
        create secret generic gitlab-postgresql-auth \
        --type=kubernetes.io/basic-auth \
        --from-literal=username=gitlab \
        --from-literal="password=${POSTGRES_PASSWORD}"

else

    echo "PostgreSQL credentials already exist."

fi

# ============================================================
# PostgreSQL cluster
# ============================================================

echo "===> Deploying PostgreSQL"

"${KUBECTL[@]}" apply \
    -f /vagrant/confs/postgresql/cluster.yaml

# ============================================================
# Wait for PostgreSQL
# ============================================================

echo "===> Waiting for PostgreSQL"

"${KUBECTL[@]}" \
    --namespace gitlab \
    wait \
    --for=condition=Ready \
    cluster/gitlab-postgresql \
    --timeout=10m

# ============================================================
# PostgreSQL status
# ============================================================

echo "===> PostgreSQL cluster"

"${KUBECTL[@]}" \
    --namespace gitlab \
    get clusters

echo "===> PostgreSQL pods"

"${KUBECTL[@]}" \
    --namespace gitlab \
    get pods \
    -o wide

echo "===> PostgreSQL services"

"${KUBECTL[@]}" \
    --namespace gitlab \
    get services

echo "===> PostgreSQL volumes"

"${KUBECTL[@]}" \
    --namespace gitlab \
    get pvc

echo "===> PostgreSQL installation completed"