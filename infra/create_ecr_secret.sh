#!/bin/bash
set -e

# Resolve script directory and source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/env.sh" ]; then
  source "$SCRIPT_DIR/env.sh"
else
  echo "Error: env.sh not found in $SCRIPT_DIR. Please run 'terraform apply' first." >&2
  exit 1
fi

# Ensure ECR Registry is defined
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-379220350808}"
ECR_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Resolve AWS CLI command (fallback to aws.exe on WSL if native aws is missing)
if command -v aws >/dev/null 2>&1; then
  AWS_CMD="aws"
elif command -v aws.exe >/dev/null 2>&1; then
  AWS_CMD="aws.exe"
else
  echo "Error: AWS CLI (aws or aws.exe) not found." >&2
  exit 1
fi

echo "==> Fetching ECR login password locally..."
ECR_PASSWORD=$($AWS_CMD ecr get-login-password --region "$AWS_REGION")

echo "==> Creating 'regcred' secret on remote Kubernetes cluster..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_PATH -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" ubuntu@$PRIVATE_IP \
  "kubectl create secret docker-registry regcred \
     --docker-server=${ECR_SERVER} \
     --docker-username=AWS \
     --docker-password='${ECR_PASSWORD}' \
     --docker-email=no@email.com \
     --dry-run=client -o yaml | kubectl apply -f -"

echo "==> ECR secret 'regcred' successfully created/updated on Kubernetes cluster."
