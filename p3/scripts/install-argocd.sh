#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "===> Creating namespaces"

kubectl apply \
    -f "$ROOT_DIR/confs/argocd/namespace.yaml"

kubectl apply \
    -f "$ROOT_DIR/confs/dev/namespace.yaml"

echo "===> Installing Argo CD"

kubectl apply \
    --server-side \
    --force-conflicts \
    -k "$ROOT_DIR/confs/argocd"

echo "===> Waiting for Argo CD CRDs"

kubectl wait \
    --for=condition=Established \
    crd/applications.argoproj.io \
    --timeout=120s

echo "===> Waiting for Argo CD"

kubectl wait \
    --for=condition=Ready \
    pod \
    --all \
    -n argocd \
    --timeout=300s

echo "===> Creating Argo CD Application"

kubectl apply \
    -f "$ROOT_DIR/confs/argocd/application.yaml"

echo "===> Argo CD resources"

kubectl get pods -n argocd

echo
echo "===> Dev resources"

kubectl get all -n dev

echo
echo "================================"
echo " Argo CD installation complete"
echo "================================"
echo
echo "To access the Argo CD UI:"
echo
echo "kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo
echo "Then open:"
echo "https://localhost:8080"