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

while [ ! -s "$TOKEN_FILE" ]; do
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
flannel-iface: "enp0s8"
node-label:
  - "workload=${NODE_ROLE}"
EOF


echo "===> Generated configuration"
cat /etc/rancher/k3s/config.yaml


# ============================================================
# Download K3s installer
# ============================================================

echo "===> Downloading K3s installer"

curl -fL \
    --retry 5 \
    --retry-delay 3 \
    --retry-all-errors \
    https://get.k3s.io \
    -o /tmp/install-k3s.sh

chmod +x /tmp/install-k3s.sh


# ============================================================
# Install K3s agent
# ============================================================

echo "===> Installing K3s agent"

K3S_URL="https://${CONTROLLER_IP}:${K3S_API_PORT}" \
K3S_TOKEN="$K3S_TOKEN" \
INSTALL_K3S_EXEC="agent" \
/tmp/install-k3s.sh


# ============================================================
# Check service
# ============================================================

echo "===> Checking K3s agent service"

if ! systemctl cat k3s-agent.service >/dev/null 2>&1; then
    echo "ERROR: k3s-agent.service was not created."
    exit 1
fi

if systemctl is-active --quiet k3s-agent; then
    echo "K3s agent installation successful."
else
    echo "K3s agent installation failed."

    systemctl status k3s-agent --no-pager -l || true
    journalctl -u k3s-agent --no-pager -n 100 || true

    exit 1
fi