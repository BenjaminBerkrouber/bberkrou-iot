#!/bin/bash
set -euo pipefail

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
NAMESPACE="gitlab"

KUBECTL=(
    kubectl
    --kubeconfig
    "$KUBECONFIG_PATH"
)

HELM=(
    helm
    --kubeconfig
    "$KUBECONFIG_PATH"
)

GARAGE_VERSION="v2.2.0"
GARAGE_CHART_VERSION="0.9.2"

GARAGE_REPO="git+https://git.deuxfleurs.fr/Deuxfleurs/garage.git@script/helm?ref=${GARAGE_VERSION}"

GARAGE_KEY_NAME="gitlab-app-key"

BUCKETS=(
    git-lfs
    gitlab-agent-plan-content
    gitlab-artifacts
    gitlab-backups
    gitlab-ci-catalog-bundles
    gitlab-ci-secure-files
    gitlab-dependency-proxy
    gitlab-mr-diffs
    gitlab-packages
    gitlab-pages
    gitlab-terraform-state
    gitlab-uploads
    registry
    runner-cache
    tmp
)

# ============================================================
# Check requirements
# ============================================================

echo "===> Checking Garage requirements"

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm is not installed."
    exit 1
fi

"${KUBECTL[@]}" wait \
    --for=condition=Ready \
    node/data \
    --timeout=180s

DATA_WORKLOAD=$(
    "${KUBECTL[@]}" get node data \
        -o jsonpath='{.metadata.labels.workload}'
)

if [ "$DATA_WORKLOAD" != "data" ]; then
    echo "ERROR: node data does not have workload=data"
    exit 1
fi

# ============================================================
# Install helm-git
# ============================================================

echo "===> Checking helm-git plugin"

if ! helm plugin list | awk 'NR > 1 {print $1}' | grep -qx "helm-git"; then
    echo "===> Installing helm-git"

    helm plugin install \
        https://github.com/aslafy-z/helm-git \
        --verify=false
else
    echo "helm-git is already installed."
fi

# ============================================================
# Garage Helm repository
# ============================================================

echo "===> Configuring Garage Helm repository"

if "${HELM[@]}" repo list | awk 'NR > 1 {print $1}' | grep -qx "garage"; then
    "${HELM[@]}" repo remove garage
fi

"${HELM[@]}" repo add \
    garage \
    "$GARAGE_REPO"

"${HELM[@]}" repo update

# ============================================================
# Install Garage
# ============================================================

echo "===> Installing Garage ${GARAGE_VERSION}"

"${HELM[@]}" upgrade \
    --install garage \
    garage/garage \
    --namespace "$NAMESPACE" \
    --version "$GARAGE_CHART_VERSION" \
    -f /vagrant/confs/garage/values.yaml \
    --wait \
    --timeout 5m

# ============================================================
# Wait for Garage
# ============================================================

echo "===> Waiting for Garage"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    rollout status statefulset/garage \
    --timeout=180s

GARAGE_POD=$(
    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        get pods \
        -l app.kubernetes.io/name=garage \
        -o jsonpath='{.items[0].metadata.name}'
)

if [ -z "$GARAGE_POD" ]; then
    echo "ERROR: Garage pod was not found."
    exit 1
fi

echo "Garage pod: $GARAGE_POD"

# ============================================================
# Garage layout
# ============================================================

echo "===> Checking Garage layout"

GARAGE_NODE_ID=$(
    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage node id \
    | cut -d '@' -f 1
)

if [ -z "$GARAGE_NODE_ID" ]; then
    echo "ERROR: Unable to retrieve Garage node ID."
    exit 1
fi

echo "Garage node ID: $GARAGE_NODE_ID"

GARAGE_STATUS=$(
    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage status
)

if echo "$GARAGE_STATUS" | grep -q "NO ROLE ASSIGNED"; then

    echo "===> Initializing Garage layout"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage layout assign \
        -z gitlab-data \
        -c 5G \
        "$GARAGE_NODE_ID"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage layout apply \
        --version 1

else
    echo "Garage layout is already initialized."
fi

# ============================================================
# Create GitLab buckets
# ============================================================

echo "===> Creating GitLab buckets"

for BUCKET in "${BUCKETS[@]}"; do

    if "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage bucket info "$BUCKET" \
        >/dev/null 2>&1; then

        echo "Bucket already exists: $BUCKET"

    else

        echo "Creating bucket: $BUCKET"

        "${KUBECTL[@]}" \
            -n "$NAMESPACE" \
            exec "$GARAGE_POD" \
            -- /garage bucket create "$BUCKET"

    fi

done

# ============================================================
# Create Garage application key
# ============================================================

echo "===> Checking Garage application key"

if "${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get secret garage-s3-credentials \
    >/dev/null 2>&1; then

    echo "Garage credentials already exist."

    GARAGE_ACCESS_KEY=$(
        "${KUBECTL[@]}" \
            -n "$NAMESPACE" \
            get secret garage-s3-credentials \
            -o jsonpath='{.data.access-key}' \
        | base64 -d
    )

    GARAGE_SECRET_KEY=$(
        "${KUBECTL[@]}" \
            -n "$NAMESPACE" \
            get secret garage-s3-credentials \
            -o jsonpath='{.data.secret-key}' \
        | base64 -d
    )

else

    echo "===> Creating Garage application key"

    KEY_OUTPUT=$(
        "${KUBECTL[@]}" \
            -n "$NAMESPACE" \
            exec "$GARAGE_POD" \
            -- /garage key create "$GARAGE_KEY_NAME"
    )

    GARAGE_ACCESS_KEY=$(
        echo "$KEY_OUTPUT" \
        | awk '/Key ID:/ {print $3}'
    )

    GARAGE_SECRET_KEY=$(
        echo "$KEY_OUTPUT" \
        | awk '/Secret key:/ {print $3}'
    )

    if [ -z "$GARAGE_ACCESS_KEY" ] || [ -z "$GARAGE_SECRET_KEY" ]; then
        echo "ERROR: Unable to retrieve Garage S3 credentials."
        exit 1
    fi

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        create secret generic garage-s3-credentials \
        --from-literal="access-key=${GARAGE_ACCESS_KEY}" \
        --from-literal="secret-key=${GARAGE_SECRET_KEY}"

fi

# ============================================================
# Grant permissions
# ============================================================

echo "===> Granting GitLab access to buckets"

for BUCKET in "${BUCKETS[@]}"; do

    echo "Granting access to: $BUCKET"

    "${KUBECTL[@]}" \
        -n "$NAMESPACE" \
        exec "$GARAGE_POD" \
        -- /garage bucket allow \
        --read \
        --write \
        --key "$GARAGE_KEY_NAME" \
        "$BUCKET"

done

# ============================================================
# GitLab object storage secret
# ============================================================

echo "===> Creating GitLab object storage Secret"

cat > /tmp/gitlab-object-storage.yaml <<EOF
provider: AWS
region: garage
aws_access_key_id: ${GARAGE_ACCESS_KEY}
aws_secret_access_key: ${GARAGE_SECRET_KEY}
endpoint: "http://garage.${NAMESPACE}.svc.cluster.local:3900"
path_style: true
EOF

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    create secret generic gitlab-object-storage \
    --from-file=config=/tmp/gitlab-object-storage.yaml \
    --dry-run=client \
    -o yaml \
| "${KUBECTL[@]}" apply -f -

# ============================================================
# GitLab backup / s3cmd secret
# ============================================================

echo "===> Creating GitLab backup object storage Secret"

cat > /tmp/gitlab-object-storage-s3cmd <<EOF
[default]
access_key = ${GARAGE_ACCESS_KEY}
secret_key = ${GARAGE_SECRET_KEY}
host_base = garage.${NAMESPACE}.svc.cluster.local:3900
host_bucket = garage.${NAMESPACE}.svc.cluster.local:3900
use_https = False
EOF

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    create secret generic gitlab-object-storage-s3cmd \
    --from-file=config=/tmp/gitlab-object-storage-s3cmd \
    --dry-run=client \
    -o yaml \
| "${KUBECTL[@]}" apply -f -

# ============================================================
# GitLab Registry storage secret
# ============================================================

echo "===> Creating GitLab Registry storage Secret"

cat > /tmp/gitlab-registry-storage.yaml <<EOF
s3:
  accesskey: ${GARAGE_ACCESS_KEY}
  secretkey: ${GARAGE_SECRET_KEY}
  bucket: registry
  region: garage
  regionendpoint: http://garage.${NAMESPACE}.svc.cluster.local:3900
  secure: false
  v4auth: true
  pathstyle: true
EOF

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    create secret generic gitlab-registry-storage \
    --from-file=config=/tmp/gitlab-registry-storage.yaml \
    --dry-run=client \
    -o yaml \
| "${KUBECTL[@]}" apply -f -

# ============================================================
# Status
# ============================================================

echo "===> Garage status"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    exec "$GARAGE_POD" \
    -- /garage status

echo "===> Garage buckets"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    exec "$GARAGE_POD" \
    -- /garage bucket list

echo "===> Garage pods"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get pods \
    -l app.kubernetes.io/name=garage \
    -o wide

echo "===> Garage services"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get services \
    -l app.kubernetes.io/name=garage

echo "===> Garage volumes"

"${KUBECTL[@]}" \
    -n "$NAMESPACE" \
    get pvc

echo "===> Garage installation completed"