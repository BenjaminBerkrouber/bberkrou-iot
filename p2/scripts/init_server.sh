#!/bin/bash

set -e

curl -sfL https://get.k3s.io | sh -

sudo systemctl enable k3s
sudo systemctl start k3s

until sudo kubectl get nodes >/dev/null 2>&1; do
	echo "Waiting for k3s.yaml..."
	sleep 2
done

mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube/config
echo 'export KUBECONFIG="$HOME/.kube/config"' >> /home/vagrant/.bashrc


kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

kubectl get nodes
kubectl get deployments
kubectl get services
kubectl get ingress
