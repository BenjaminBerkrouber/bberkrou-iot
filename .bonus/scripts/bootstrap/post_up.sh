#!/bin/bash
set -euo pipefail

echo "===> Running post-cluster bootstrap"

echo "===> Installing PostgreSQL"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/postgresql/postgresql_install.sh"

echo "===> Installing Valkey"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/valkey/valkey_install.sh"

echo "===> Installing Garage"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/garage/garage_install.sh"

echo "===> Installing GitLab"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/gitlab/gitlab_install.sh"

echo "===> Post-cluster bootstrap completed"