#!/bin/bash
set -euo pipefail

source /vagrant/confs/system/cluster.env

# ============================================================
# Kubectl configuration
# ============================================================

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

KUBECTL=(
    kubectl
    --kubeconfig
    "$KUBECONFIG_PATH"
)

# ============================================================
# Remove stale token
# ============================================================

rm -f "$TOKEN_FILE"

# ============================================================
# Firewall configuration
# ============================================================

echo "===> Firewall configuration for K3s"

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "${K3S_API_PORT}/tcp"
ufw allow from "$POD_CIDR" to any
ufw allow from "$SERVICE_CIDR" to any

# ============================================================
# K3s server configuration
# ============================================================

echo "===> Installing K3s server configuration"

mkdir -p /etc/rancher/k3s

cp /vagrant/confs/system/k3s-server.yaml \
    /etc/rancher/k3s/config.yaml

echo "===> K3s configuration"

cat /etc/rancher/k3s/config.yaml
echo

# ============================================================
# Download K3s installer
# ============================================================

echo "===> Downloading K3s installer"

curl -fL \
    --retry 5 \
    --retry-delay 3 \
    --retry-all-errors \
    https://raw.githubusercontent.com/k3s-io/k3s/main/install.sh \
    -o /tmp/install-k3s.sh

chmod +x /tmp/install-k3s.sh

# ============================================================
# Install K3s controller
# ============================================================

echo "===> Installation of K3s controller"

/tmp/install-k3s.sh

# ============================================================
# Check K3s service
# ============================================================

echo "===> Checking K3s service"

if ! systemctl cat k3s.service >/dev/null 2>&1; then
    echo "ERROR: k3s.service was not created."
    exit 1
fi

if systemctl is-active --quiet k3s; then
    echo "K3s controller installation successful."
else
    echo "K3s controller installation failed."

    echo "===> K3s status"
    systemctl status k3s --no-pager -l || true

    echo "===> K3s logs"
    journalctl -u k3s --no-pager -n 100 || true

    exit 1
fi

# ============================================================
# Wait for Kubernetes API
# ============================================================

echo "===> Waiting for Kubernetes API"

for attempt in {1..60}; do

    if "${KUBECTL[@]}" get nodes >/dev/null 2>&1; then
        echo "K3s API is ready."
        break
    fi

    if [ "$attempt" -eq 60 ]; then
        echo "K3s API unavailable after 120 seconds."

        systemctl status k3s --no-pager -l || true
        journalctl -u k3s --no-pager -n 100 || true

        exit 1
    fi

    echo "Waiting for K3s API... ($attempt/60)"
    sleep 2

done

# ============================================================
# Kubernetes nodes
# ============================================================

echo "===> Kubernetes nodes"

"${KUBECTL[@]}" get nodes

# ============================================================
# Configure kubectl for vagrant user
# ============================================================

echo "===> Configuration of kubectl for the vagrant user"

mkdir -p /home/vagrant/.kube

cp "$KUBECONFIG_PATH" \
    /home/vagrant/.kube/config

chown -R vagrant:vagrant /home/vagrant/.kube

chmod 700 /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

grep -qxF \
    'export KUBECONFIG=/home/vagrant/.kube/config' \
    /home/vagrant/.bashrc || \
echo 'export KUBECONFIG=/home/vagrant/.kube/config' \
    >> /home/vagrant/.bashrc

# ============================================================
# Export token for workers
# ============================================================

echo "===> Exporting K3s token for workers"

cat /var/lib/rancher/k3s/server/node-token \
    > "$TOKEN_FILE"

chmod 600 "$TOKEN_FILE"

echo "K3s token exported to $TOKEN_FILE"

# ============================================================
# Create Kubernetes namespaces
# ============================================================

echo "===> Creating Kubernetes namespaces"

"${KUBECTL[@]}" apply \
    -f /vagrant/confs/system/namespaces/

# ============================================================
# Show namespaces
# ============================================================

echo "===> Kubernetes namespaces"

"${KUBECTL[@]}" get namespaces

# ============================================================
# Show Kubernetes resources
# ============================================================

echo "===> Kubernetes resources"

"${KUBECTL[@]}" get pods -A
"${KUBECTL[@]}" get services -A
"${KUBECTL[@]}" get ingress -A
