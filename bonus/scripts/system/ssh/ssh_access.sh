#!/bin/bash
set -e

SSH_FILE="/tmp/id_ed25519.pub"

if [ ! -f "$SSH_FILE" ]; then
    echo "SSH public key not found."
    echo "Check that ~/.ssh/id_ed25519.pub exists on the host machine."
    exit 1
fi

mkdir -p /home/vagrant/.ssh
touch /home/vagrant/.ssh/authorized_keys
grep -qxF "$(cat "$SSH_FILE")" /home/vagrant/.ssh/authorized_keys || cat "$SSH_FILE" >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/authorized_keys