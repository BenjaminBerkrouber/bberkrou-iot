#!/bin/bash

set -e

curl -sfL https://get.k3s.io | sh -

sudo systemctl enable k3s
sudo systemctl start k3s

until [ -f /etc/rancher/k3s/k3s.yaml ]; do
	echo "Waiting for k3s.yaml..."
	sleep 2
done

mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube/config

TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
echo "$TOKEN" > /vagrant/token # K10xxx::server:xxx


