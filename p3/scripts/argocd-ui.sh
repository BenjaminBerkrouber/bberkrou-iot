#!/usr/bin/env bash

set -euo pipefail

echo "Argo CD UI:"
echo "https://localhost:8443"
echo
echo "Press Ctrl+C to stop."

kubectl port-forward \
    -n argocd \
    svc/argocd-server \
    8443:443