#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y \
    openssh-server \
    netcat-openbsd \
    curl

systemctl enable --now ssh