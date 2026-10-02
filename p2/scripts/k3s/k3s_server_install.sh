#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
CONF_SRC="/vagrant/confs/cluster/k3s-single.yaml"
CONF_DST="/etc/rancher/k3s/config.yaml"
WORKLOADS="/vagrant/confs/workloads"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo ">>> Détection de l'interface réseau pour ${SERVER_IP}..."
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ ip {print $2; exit}')
echo ">>> Interface : ${IFACE}"

echo ">>> Mise en place de la config K3s..."
mkdir -p /etc/rancher/k3s
sed "s/__IFACE__/${IFACE}/" "${CONF_SRC}" > "${CONF_DST}"

echo ">>> Installation de K3s (server)..."
curl -sfL https://get.k3s.io | sh -

echo ">>> Attente que le noeud soit Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done

echo ">>> Déploiement des applications et du routage..."
kubectl apply -f "${WORKLOADS}/"

echo ">>> Attente du rollout..."
kubectl rollout status deployment/app1
kubectl rollout status deployment/app2
kubectl rollout status deployment/app3

echo ">>> État final :"
kubectl get all
echo "---"
kubectl get ingress