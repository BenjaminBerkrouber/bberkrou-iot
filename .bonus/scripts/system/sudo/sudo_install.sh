#!/bin/bash

set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/vagrant"

echo "===> Configuring passwordless sudo for vagrant"

cat > "$SUDOERS_FILE" <<'EOF'
vagrant ALL=(ALL) NOPASSWD: ALL
EOF

chmod 0440 "$SUDOERS_FILE"

echo "===> Validating sudoers configuration"

visudo -cf "$SUDOERS_FILE"

echo "===> Passwordless sudo configured"