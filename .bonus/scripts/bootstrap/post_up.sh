#!/bin/bash
set -euo pipefail

echo "===> Running post-cluster bootstrap"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/postgresql/postgresql_install.sh"