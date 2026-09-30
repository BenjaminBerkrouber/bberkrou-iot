#!/bin/bash
set -euo pipefail

echo "===> Running post-cluster bootstrap"

echo "===> Installing PostgreSQL"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/apps/gitlab/requirements/postgresql/postgresql_install.sh"

echo "===> Installing Valkey"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/apps/gitlab/requirements/valkey/valkey_install.sh"

echo "===> Installing Garage"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/apps/gitlab/requirements/garage/garage_install.sh"

echo "===> Installing GitLab"

vagrant ssh bberkrouS \
    -c "sudo /vagrant/scripts/apps/gitlab/gitlab_install.sh"

echo "===> Post-cluster bootstrap completed"