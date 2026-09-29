#!/bin/bash
set -e

source /vagrant/confs/cluster.env

echo "===> Firewall configuration for K3s"

ufw allow "${K3S_API_PORT}/tcp"
ufw allow from "$POD_CIDR" to any
ufw allow from "$SERVICE_CIDR" to any

echo "===> Installing K3s server configuration"

mkdir -p /etc/rancher/k3s
cp /vagrant/confs/k3s-server.yaml /etc/rancher/k3s/config.yaml

echo "===> Installation of K3s controller"

curl -sfL https://get.k3s.io | sh -

echo "===> Checking K3s controller status"

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


echo "===> Waiting for Kubernetes API"

for attempt in {1..60}; do

    if kubectl \
        --kubeconfig /etc/rancher/k3s/k3s.yaml \
        get nodes > /dev/null 2>&1; then

        echo "K3s API is ready."
        break
    fi

    if [ "$attempt" -eq 60 ]; then
        echo "K3s API unavailable after 120 seconds."
        journalctl -u k3s --no-pager -n 50
        exit 1
    fi

    echo "Waiting for K3s API... ($attempt/60)"
    sleep 2
done

echo "===> Kubernetes nodes"

kubectl \
    --kubeconfig /etc/rancher/k3s/k3s.yaml \
    get nodes

echo "===> Configuration of kubectl for the vagrant user"

mkdir -p /home/vagrant/.kube

cp /etc/rancher/k3s/k3s.yaml \
    /home/vagrant/.kube/config

chown -R vagrant:vagrant /home/vagrant/.kube
chmod 700 /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

grep -qxF \
    'export KUBECONFIG=/home/vagrant/.kube/config' \
    /home/vagrant/.bashrc || \
echo 'export KUBECONFIG=/home/vagrant/.kube/config' \
    >> /home/vagrant/.bashrc

echo "===> Exporting K3s token for worker"

cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "K3s token exported to $TOKEN_FILE"