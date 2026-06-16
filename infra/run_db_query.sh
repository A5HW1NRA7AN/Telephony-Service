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

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_PATH -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" ubuntu@$PRIVATE_IP \
  'kubectl exec -n default deployment/postgres -- psql -P pager=off -U lead_user -d lead_db -c "SELECT id, processing_status, idempotency_key, sent_at FROM telephony_call_lead_ingest_log ORDER BY updated_at DESC LIMIT 3;"'
