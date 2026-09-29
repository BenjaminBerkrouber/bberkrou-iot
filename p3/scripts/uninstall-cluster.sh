#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-cluster}"

echo "===> Checking cluster '$CLUSTER_NAME'"

if ! k3d cluster get "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Cluster '$CLUSTER_NAME' does not exist."
    exit 0
fi

echo "===> Deleting cluster '$CLUSTER_NAME'"

k3d cluster delete "$CLUSTER_NAME"

echo "===> Cluster '$CLUSTER_NAME' deleted successfully."