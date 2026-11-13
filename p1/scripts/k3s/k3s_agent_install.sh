#!/bin/bash
set -euo pipefail

WORKER_IP="192.168.56.111"
SHARED_DIR="/shared"
CONF_SRC="/vagrant/confs/k3s-agent.yaml"
CONF_DST="/etc/rancher/k3s/config.yaml"

echo ">>> [worker] Detecting the network interface for ${WORKER_IP}..."
IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP" '$4 ~ ip {print $2; exit}')
echo ">>> [worker] Interface: ${IFACE}"

echo ">>> [worker] Waiting for the server node token..."
while [ ! -f "${SHARED_DIR}/node-token" ]; do sleep 2; done
TOKEN=$(cat "${SHARED_DIR}/node-token")

echo ">>> [worker] Writing the K3s configuration..."
mkdir -p /etc/rancher/k3s
sed "s/__IFACE__/${IFACE}/" "${CONF_SRC}" > "${CONF_DST}"

echo ">>> [worker] Installing K3s (agent)..."
curl -sfL https://get.k3s.io | K3S_TOKEN="${TOKEN}" INSTALL_K3S_EXEC="agent" sh -

echo ">>> [worker] K3s agent started and joined the cluster."