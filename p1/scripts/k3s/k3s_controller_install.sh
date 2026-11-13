#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
SHARED_DIR="/shared"
CONF_SRC="/vagrant/confs/k3s-server.yaml"
CONF_DST="/etc/rancher/k3s/config.yaml"

echo ">>> [server] Detecting the network interface for ${SERVER_IP}..."
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ ip {print $2; exit}')
echo ">>> [server] Interface: ${IFACE}"

echo ">>> [server] Writing the K3s configuration..."
mkdir -p /etc/rancher/k3s
sed "s/__IFACE__/${IFACE}/" "${CONF_SRC}" > "${CONF_DST}"

echo ">>> [server] Installing K3s (controller)..."
curl -sfL https://get.k3s.io | sh -

echo ">>> [server] Waiting for the node token..."
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do sleep 2; done

echo ">>> [server] Sharing the token with the worker..."
mkdir -p "${SHARED_DIR}"
cp /var/lib/rancher/k3s/server/node-token "${SHARED_DIR}/node-token"

echo ">>> [server] Waiting for the node to be Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done

echo ">>> [server] Cluster ready:"
kubectl get nodes -o wide