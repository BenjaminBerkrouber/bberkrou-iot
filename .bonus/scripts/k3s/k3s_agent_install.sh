#!/bin/bash
set -euo pipefail

source /vagrant/confs/cluster.env

# ============================================================
# Parameters received from Vagrant
# ============================================================

: "${NODE_IP:?NODE_IP is required}"
: "${NODE_ROLE:?NODE_ROLE is required}"

NODE_NAME=$(hostname -s | tr '[:upper:]' '[:lower:]')

echo "===> K3s agent configuration"
echo "Node name : $NODE_NAME"
echo "Node IP   : $NODE_IP"
echo "Node role : $NODE_ROLE"

# ============================================================
# Wait for controller token
# ============================================================

echo "===> Waiting for K3s controller token"

while [ ! -f "$TOKEN_FILE" ]; do
    echo "Waiting for controller..."
    sleep 2
done

K3S_TOKEN=$(cat "$TOKEN_FILE")

# ============================================================
# Wait for Kubernetes API
# ============================================================

echo "===> Checking K3s API server"

until nc -z "$CONTROLLER_IP" "$K3S_API_PORT"; do
    echo "Waiting for K3s API server..."
    sleep 2
done

echo "K3s API server is reachable."

# ============================================================
# K3s agent configuration
# ============================================================

echo "===> Creating K3s agent configuration"

mkdir -p /etc/rancher/k3s

cat > /etc/rancher/k3s/config.yaml <<EOF
server: "https://${CONTROLLER_IP}:${K3S_API_PORT}"
node-ip: "${NODE_IP}"
node-name: "${NODE_NAME}"
node-label:
    - "workload=${NODE_ROLE}"
EOF

echo "===> Generated configuration"

cat /etc/rancher/k3s/config.yaml

# ============================================================
# Install K3s agent
# ============================================================

echo "===> Installing K3s agent"

cat > /etc/rancher/k3s/config.yaml <<EOF
server: "https://${CONTROLLER_IP}:${K3S_API_PORT}"
node-ip: "${NODE_IP}"
node-name: "${NODE_NAME}"
node-label:
    - "workload=${NODE_ROLE}"
    - "node-role.kubernetes.io/${NODE_ROLE}=true"
EOF
# ============================================================
# Check service
# ============================================================

echo "===> Checking K3s agent"

if systemctl is-active --quiet k3s-agent; then
    echo "K3s agent installation successful."
else
    echo "K3s agent installation failed."
    journalctl -u k3s-agent --no-pager -n 50
    exit 1
fi