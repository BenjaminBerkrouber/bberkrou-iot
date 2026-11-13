#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
CONF_SRC="/vagrant/confs/cluster/k3s-single.yaml"
CONF_DST="/etc/rancher/k3s/config.yaml"
WORKLOADS="/vagrant/confs/workloads"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo ">>> Detecting the network interface for ${SERVER_IP}..."
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ ip {print $2; exit}')
echo ">>> Interface: ${IFACE}"

echo ">>> Writing the K3s configuration..."
mkdir -p /etc/rancher/k3s
sed "s/__IFACE__/${IFACE}/" "${CONF_SRC}" > "${CONF_DST}"

echo ">>> Installing K3s (server)..."
curl -sfL https://get.k3s.io | sh -

echo ">>> Waiting for the node to be Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done

echo ">>> Deploying applications and routing..."
kubectl apply -f "${WORKLOADS}/"

echo ">>> Waiting for deployments to roll out..."
kubectl rollout status deployment/app1
kubectl rollout status deployment/app2
kubectl rollout status deployment/app3

echo ">>> Final status:"
kubectl get all
echo "---"
kubectl get ingress