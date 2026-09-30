#!/bin/bash

set -euo pipefail

echo "===> Running post-cluster bootstrap"


echo "===> Checking passwordless sudo"

vagrant ssh bberkrouS \
    -c "sudo -n true"


echo "===> Installing PostgreSQL"

vagrant ssh bberkrouS \
    -c "sudo -n /vagrant/scripts/apps/postgresql/postgresql_install.sh"


echo "===> Installing Valkey"

vagrant ssh bberkrouS \
    -c "sudo -n /vagrant/scripts/apps/valkey/valkey_install.sh"


echo "===> Installing Garage"

vagrant ssh bberkrouS \
    -c "sudo -n /vagrant/scripts/apps/garage/garage_install.sh"


echo "===> Installing GitLab"

vagrant ssh bberkrouS \
    -c "sudo -n /vagrant/scripts/apps/gitlab/gitlab_install.sh"


echo "===> Installing Argo CD"

vagrant ssh bberkrouS \
    -c "sudo -n /vagrant/scripts/apps/cd/argo/argo_install.sh"


echo "===> Post-cluster bootstrap completed"