#!/bin/bash

set -euo pipefail


readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" # Take the directory of the current script
readonly DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)" # Take the parent directory of the script directory

readonly CLUSTER_NAME="iot"
readonly ARGOCD_APP="${DIR}/confs/argocd-app.yaml"
readonly K3D_CONFIG="${DIR}/confs/k3d-config.yaml"
readonly ARGOCD_NAMESPACE="argocd"
readonly ARGOCD_NAMESPACE_PATH="${DIR}/confs/argocd-namespace.yaml"
readonly ARGOCD_VERSION="v3.2.0"
readonly DEV_NAMESPACE="dev"
readonly DEV_NAMESPACE_PATH="${DIR}/confs/dev-namespace.yaml"


if k3d cluster list --no-headers | grep -E "^${CLUSTER_NAME}[[:space:]]"; then
  echo "Cluster '${CLUSTER_NAME}' already exists."
else
  echo "Creating cluster '${CLUSTER_NAME}'..."
  k3d cluster create --config "${K3D_CONFIG}"
fi


kubectl config use-context "k3d-${CLUSTER_NAME}"

if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
  echo "Namespace '${ARGOCD_NAMESPACE}' already exists."
else
  echo "Creating namespace '${ARGOCD_NAMESPACE}'..."
  kubectl apply -f "${ARGOCD_NAMESPACE_PATH}"
  echo "Creating namespace '${DEV_NAMESPACE}'..."
  kubectl apply -f "${DEV_NAMESPACE_PATH}"
fi

echo "Deploying ArgoCD..."

kubectl apply \
  --server-side \
  --force-conflicts \
  --namespace "${ARGOCD_NAMESPACE}" \
  --filename https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml


echo "Waiting for ArgoCD deployments..."

kubectl wait \
  --for=condition=Available \
  deployment \
  --all \
  --namespace "${ARGOCD_NAMESPACE}" \
  --timeout=120s

kubectl rollout status \
  statefulset/argocd-application-controller \
  --namespace "${ARGOCD_NAMESPACE}" \
  --timeout=120s

echo "Deploying ArgoCD application..."

kubectl apply \
  --namespace "${ARGOCD_NAMESPACE}" \
  --filename "${ARGOCD_APP}"


# To access the ArgoCD UI, you can use port forwarding:

# kubectl port-forward -n argocd svc/argocd-server 8080:443

# Id will be : admin
# And you case use command 
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# To get the password

