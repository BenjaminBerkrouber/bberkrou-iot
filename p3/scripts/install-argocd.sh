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