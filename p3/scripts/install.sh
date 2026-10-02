#!/bin/bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

K3D_VERSION="${K3D_VERSION:-v5.9.0}"

# ============================================================
# Helpers
# ============================================================

log() {
    echo
    echo "===> $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# Root check
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Run this script with sudo: sudo bash $0"
fi

# User who launched sudo.
REAL_USER="${SUDO_USER:-$USER}"

# ============================================================
# OS check
# ============================================================

log "Checking operating system"

if [ ! -f /etc/os-release ]; then
    error "/etc/os-release not found."
fi

source /etc/os-release

case "$ID" in
    ubuntu|debian)
        ;;
    *)
        error "Unsupported distribution: $ID. Ubuntu or Debian is required."
        ;;
esac

echo "Distribution: $PRETTY_NAME"
echo "Architecture: $(uname -m)"

# ============================================================
# Architecture
# ============================================================

case "$(uname -m)" in
    x86_64)
        KUBECTL_ARCH="amd64"
        ;;
    aarch64|arm64)
        KUBECTL_ARCH="arm64"
        ;;
    *)
        error "Unsupported architecture: $(uname -m)"
        ;;
esac

# ============================================================
# Basic dependencies
# ============================================================

log "Checking basic dependencies"

PACKAGES=()

for package in curl ca-certificates git gnupg; do
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        PACKAGES+=("$package")
    else
        echo "$package already installed."
    fi
done

if [ "${#PACKAGES[@]}" -gt 0 ]; then
    log "Installing missing packages: ${PACKAGES[*]}"

    apt-get update
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "${PACKAGES[@]}"
fi

# ============================================================
# Docker
# ============================================================

log "Checking Docker"

install_docker() {

    log "Installing Docker Engine"

    # Remove packages that may conflict with Docker's official packages.
    for pkg in \
        docker.io \
        docker-compose \
        docker-compose-v2 \
        docker-doc \
        podman-docker
    do
        apt-get remove -y "$pkg" >/dev/null 2>&1 || true
    done

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL \
        "https://download.docker.com/linux/${ID}/gpg" \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    if [ "$ID" = "ubuntu" ]; then
        DOCKER_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    else
        DOCKER_CODENAME="$VERSION_CODENAME"
    fi

    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${DOCKER_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update

    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
}

if command_exists docker; then
    echo "Docker already installed:"
    docker --version
else
    install_docker
fi

# ============================================================
# Docker service
# ============================================================

log "Checking Docker service"

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker

if ! systemctl is-active --quiet docker; then
    error "Docker service is not running."
fi

echo "Docker service is running."

# ============================================================
# Docker user permissions
# ============================================================

log "Configuring Docker permissions"

DOCKER_GROUP_ADDED=0

if id "$REAL_USER" >/dev/null 2>&1; then

    if id -nG "$REAL_USER" | grep -qw docker; then
        echo "$REAL_USER is already in the docker group."
    else
        usermod -aG docker "$REAL_USER"
        DOCKER_GROUP_ADDED=1
        echo "$REAL_USER added to the docker group."
    fi

else
    error "User '$REAL_USER' does not exist."
fi

# ============================================================
# Docker test
# ============================================================

log "Testing Docker"

if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is unavailable."
fi

echo "Docker is operational."

# ============================================================
# kubectl
# ============================================================

log "Checking kubectl"

if command_exists kubectl; then

    echo "kubectl already installed:"
    kubectl version --client

else

    log "Installing kubectl"

    KUBECTL_VERSION="$(
        curl -fsSL https://dl.k8s.io/release/stable.txt
    )"

    echo "kubectl version: $KUBECTL_VERSION"

    TMP_DIR="$(mktemp -d)"

    curl -fsSL \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl" \
        -o "$TMP_DIR/kubectl"

    curl -fsSL \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl.sha256" \
        -o "$TMP_DIR/kubectl.sha256"

    echo "$(
        cat "$TMP_DIR/kubectl.sha256"
    )  $TMP_DIR/kubectl" | sha256sum --check

    install \
        -o root \
        -g root \
        -m 0755 \
        "$TMP_DIR/kubectl" \
        /usr/local/bin/kubectl

    rm -rf "$TMP_DIR"

fi

# ============================================================
# K3d
# ============================================================

log "Checking K3d"

if command_exists k3d; then

    echo "K3d already installed:"
    k3d version

else

    log "Installing K3d ${K3D_VERSION}"

    TMP_DIR="$(mktemp -d)"

    curl -fsSL \
        https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
        -o "$TMP_DIR/install-k3d.sh"

    TAG="$K3D_VERSION" bash "$TMP_DIR/install-k3d.sh"

    rm -rf "$TMP_DIR"

fi

# ============================================================
# Final checks
# ============================================================

log "Final verification"

FAILED=0

for command in docker kubectl k3d git curl; do

    if command_exists "$command"; then
        printf "%-10s : OK\n" "$command"
    else
        printf "%-10s : MISSING\n" "$command"
        FAILED=1
    fi

done

if ! systemctl is-active --quiet docker; then
    echo "docker service : ERROR"
    FAILED=1
else
    echo "docker service : OK"
fi

if [ "$FAILED" -ne 0 ]; then
    error "Some dependencies are missing."
fi

echo
echo "=========================================="
echo " Installation completed successfully"
echo "=========================================="
echo

docker --version
newgrp docker

echo
kubectl version --client
echo
k3d version

echo
echo "User: $REAL_USER"
echo

if ! id -nG "$REAL_USER" | grep -qw docker; then
    echo "WARNING: Docker group configuration failed."
elif [ "$REAL_USER" != "root" ]; then
    echo "If Docker was just configured for $REAL_USER,"
    echo "log out and log back in before using K3d."
fi

echo
echo "You can then create a cluster with:"
echo
echo "    k3d cluster create iot"
echo