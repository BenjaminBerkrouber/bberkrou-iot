#!/bin/bash

set -euo pipefail

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

NAMESPACE="gitlab"

VALUES_FILE="/vagrant/confs/gitlab/values.yaml"

GITLAB_CHART_VERSION="10.4.1"

GITLAB_CHART="oci://registry.gitlab.com/charts/charts.gitlab.io/release/gitlab"

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


# ============================================================
# Check configuration file
# ============================================================

echo "===> Checking GitLab configuration"

if [ ! -f "$VALUES_FILE" ]; then
    echo "ERROR: GitLab values file does not exist:"
    echo "$VALUES_FILE"
    exit 1
fi

echo "GitLab values file found:"
echo "$VALUES_FILE"


# ============================================================
# Check GitLab worker
# ============================================================

echo "===> Checking GitLab node"

"${KUBECTL[@]}" wait \
    --for=condition=Ready \
    node/gitlab \
    --timeout=180s

GITLAB_WORKLOAD=$(
    "${KUBECTL[@]}" \
        get node gitlab \
        -o jsonpath='{.metadata.labels.workload}'
)

if [ "$GITLAB_WORKLOAD" != "gitlab" ]; then

    echo "ERROR: node gitlab does not have workload=gitlab"
    exit 1

fi

echo "GitLab node is ready."


# ============================================================
# Check PostgreSQL
# ============================================================

echo "===> Checking PostgreSQL"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get service gitlab-postgresql-rw \
    >/dev/null

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    wait \
    --for=condition=Ready \
    cluster/gitlab-postgresql \
    --timeout=60s

echo "PostgreSQL is ready."


# ============================================================
# Check Valkey
# ============================================================

echo "===> Checking Valkey"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get service gitlab-valkey \
    >/dev/null

VALKEY_POD=$(
    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get pods \
        -l app.kubernetes.io/instance=gitlab-valkey \
        -o jsonpath='{.items[0].metadata.name}'
)

if [ -z "$VALKEY_POD" ]; then
    echo "ERROR: Valkey pod not found."
    exit 1
fi

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    wait \
    --for=condition=Ready \
    "pod/${VALKEY_POD}" \
    --timeout=60s

echo "Valkey is ready."


# ============================================================
# Check Garage
# ============================================================

echo "===> Checking Garage"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get service garage \
    >/dev/null

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    rollout status \
    statefulset/garage \
    --timeout=60s

echo "Garage is ready."


# ============================================================
# Check required secrets
# ============================================================

echo "===> Checking GitLab Secrets"

REQUIRED_SECRETS=(
    gitlab-postgresql-auth
    gitlab-valkey-auth
    gitlab-object-storage
    gitlab-object-storage-s3cmd
    gitlab-registry-storage
)

for SECRET in "${REQUIRED_SECRETS[@]}"; do

    if ! "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get secret "$SECRET" \
        >/dev/null 2>&1; then

        echo "ERROR: Secret not found: $SECRET"
        exit 1

    fi

    echo "Secret found: $SECRET"

done


# ============================================================
# Check Traefik
# ============================================================

echo "===> Checking Traefik IngressClass"

if ! "${KUBECTL[@]}" \
    get ingressclass traefik \
    >/dev/null 2>&1; then

    echo "ERROR: Traefik IngressClass was not found."
    exit 1

fi

echo "Traefik IngressClass found."


# ============================================================
# Render chart before installation
#
# This catches invalid YAML or invalid Helm configuration
# before Kubernetes resources are created.
# ============================================================

echo "===> Rendering GitLab Helm chart"

"${HELM[@]}" template \
    gitlab \
    "$GITLAB_CHART" \
    --version "$GITLAB_CHART_VERSION" \
    --namespace "$NAMESPACE" \
    -f "$VALUES_FILE" \
    > /tmp/gitlab-rendered.yaml

echo "GitLab Helm chart rendered successfully."


# ============================================================
# Install GitLab
# ============================================================

echo "===> Installing GitLab chart ${GITLAB_CHART_VERSION}"

if ! "${HELM[@]}" upgrade \
    --install \
    gitlab \
    "$GITLAB_CHART" \
    --version "$GITLAB_CHART_VERSION" \
    --namespace "$NAMESPACE" \
    -f "$VALUES_FILE" \
    --wait \
    --wait-for-jobs \
    --timeout 20m; then

    echo
    echo "ERROR: GitLab installation failed."
    echo

    echo "===> Helm status"

    "${HELM[@]}" \
        status gitlab \
        -n "$NAMESPACE" \
        || true

    echo
    echo "===> GitLab pods"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get pods \
        -o wide \
        || true

    echo
    echo "===> GitLab jobs"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get jobs \
        || true

    echo
    echo "===> GitLab PVCs"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get pvc \
        || true

    echo
    echo "===> Recent Kubernetes events"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get events \
        --sort-by='.lastTimestamp' \
        | tail -n 80 \
        || true

    exit 1
fi


# ============================================================
# Installation status
# ============================================================

echo
echo "===> GitLab Helm release"

"${HELM[@]}" \
    list \
    -n "$NAMESPACE"


echo
echo "===> GitLab pods"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get pods \
    -o wide


echo
echo "===> GitLab services"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get services


echo
echo "===> GitLab ingress"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get ingress


echo
echo "===> GitLab persistent volumes"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get pvc


echo
echo "===> GitLab installation completed"