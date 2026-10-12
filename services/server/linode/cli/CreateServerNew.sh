#!/usr/bin/env sh
# Strict error handling for POSIX compliance
set -ef

# 1. Define configuration variables
INSTANCE_LABEL="prod-web-server-$(date +%s)"
REGION="us-east"
PLAN_TYPE="g6-nanode-1"
IMAGE_DISTRO="linode/debian11"

# Generate a strong temporary root password safely
ROOT_PASS=$(openssl rand -base64 16)

# Read SSH key safely from disk if it exists
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    SSH_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
else
    echo "Error: Standard public key not found at $HOME/.ssh/id_rsa.pub" >&2
    exit 1
fi

echo "Deploying Linode instance: ${INSTANCE_LABEL}..." >&2

# 2. Execute the creation command in a robust, machine-readable format
# --text and --no-headers ensure plain text output without markdown/table borders
# --format 'id,ipv4' restricts the output fields precisely
RESULT=$(linode-cli linodes create \
    --label "${INSTANCE_LABEL}" \
    --region "${REGION}" \
    --type "${PLAN_TYPE}" \
    --image "${IMAGE_DISTRO}" \
    --root_pass "${ROOT_PASS}" \
    --authorized_keys "${SSH_KEY}" \
    --booted true \
    --text \
    --no-headers \
    --format 'id,ipv4' 2>/dev/null)

# Verify compilation status
if [ -z "$RESULT" ]; then
    echo "Deployment failed or linode-cli returned no data." >&2
    exit 1
fi

# 3. Parse the tab-delimited response variables robustly using POSIX built-ins
LINODE_ID=$(echo "$RESULT" | cut -f1)
LINODE_IP=$(echo "$RESULT" | cut -f2)

# Output target deployment metrics safely
echo "=========================================="
echo "SUCCESS: Linode Created."
echo "ID:       $LINODE_ID"
echo "IP:       $LINODE_IP"
echo "Password: $ROOT_PASS"
echo "=========================================="
