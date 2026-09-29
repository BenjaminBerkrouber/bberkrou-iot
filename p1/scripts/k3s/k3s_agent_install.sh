#!/bin/bash
set -e

source /vagrant/confs/cluster.env

echo "===> Waiting for K3s controller token"

while [ ! -f "$TOKEN_FILE" ]; do
    echo "Waiting for controller..."
    sleep 2
done

K3S_TOKEN=$(cat "$TOKEN_FILE")

echo "===> Checking K3s API server"

until nc -z "$CONTROLLER_IP" "$K3S_API_PORT"; do
    echo "Waiting for K3s API server..."
    sleep 2
done

echo "K3s API server is reachable."

echo "===> Installing K3s agent configuration"

mkdir -p /etc/rancher/k3s
cp /vagrant/confs/k3s-agent.yaml /etc/rancher/k3s/config.yaml

echo "===> Installing K3s agent"

curl -sfL https://get.k3s.io | \
K3S_URL="https://${CONTROLLER_IP}:${K3S_API_PORT}" \
K3S_TOKEN="$K3S_TOKEN" \
sh -

echo "===> Checking K3s agent"

if systemctl is-active --quiet k3s-agent; then
    echo "K3s agent installation successful."
else
    echo "K3s agent installation failed."
    journalctl -u k3s-agent --no-pager -n 50
    exit 1
fi