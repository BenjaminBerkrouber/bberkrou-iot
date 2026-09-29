#!/bin/bash

set -euo pipefail

CLUSTER_NAME="mon-cluster"

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists."
    exit 0
fi

echo "===> Creating K3d cluster"

k3d cluster create "$CLUSTER_NAME" \
    --servers 1 \
    --agents 2

echo "===> Waiting for Kubernetes nodes"

kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=120s

kubectl get nodes