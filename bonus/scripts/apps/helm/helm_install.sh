#!/bin/bash
set -euo pipefail

HELM_VERSION="v4.3.0"
HELM_ARCHIVE="helm-${HELM_VERSION}-linux-amd64.tar.gz"
HELM_URL="https://get.helm.sh/${HELM_ARCHIVE}"

echo "===> Checking Helm"

if command -v helm >/dev/null 2>&1; then
    CURRENT_VERSION=$(helm version --short)

    if [[ "$CURRENT_VERSION" == *"$HELM_VERSION"* ]]; then
        echo "Helm ${HELM_VERSION} is already installed."
        exit 0
    fi
fi

echo "===> Downloading Helm ${HELM_VERSION}"

curl -fL \
    --retry 5 \
    --retry-delay 3 \
    --retry-all-errors \
    "$HELM_URL" \
    -o "/tmp/${HELM_ARCHIVE}"

echo "===> Downloading Helm checksum"

curl -fL \
    "${HELM_URL}.sha256sum" \
    -o "/tmp/${HELM_ARCHIVE}.sha256sum"

echo "===> Verifying Helm archive"

cd /tmp
sha256sum -c "${HELM_ARCHIVE}.sha256sum"

echo "===> Extracting Helm"

tar -xzf "$HELM_ARCHIVE"

echo "===> Installing Helm"

install \
    -m 0755 \
    /tmp/linux-amd64/helm \
    /usr/local/bin/helm

echo "===> Helm installed"

helm version