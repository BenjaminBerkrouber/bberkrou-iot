#!/bin/bash

# Get env variables
SERVER_IP=$1
TOKEN=$(cat /vagrant/token)

# Installation part
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" K3S_TOKEN="$TOKEN" sh -
# Need ot replace SERVER_IP and TOKEN
