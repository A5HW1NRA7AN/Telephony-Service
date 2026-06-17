#!/bin/bash
set -e

# Resolve script directory and source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SH_PATH="${ENV_SH_PATH:-$SCRIPT_DIR/../../../On-Prem-Infrastructure/terraform/env.sh}"

if [ -f "$ENV_SH_PATH" ]; then
  source "$ENV_SH_PATH"
elif [ -f "$SCRIPT_DIR/env.sh" ]; then
  source "$SCRIPT_DIR/env.sh"
else
  echo "Error: env.sh not found. Please ensure env.sh exists or set ENV_SH_PATH." >&2
  exit 1
fi

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_PATH -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" ubuntu@$PRIVATE_IP \
  'kubectl exec -n default deployment/freeswitch -- fs_cli -p CluSt3r@Esl#2026! -x "originate loopback/1000/public &playback(/usr/share/freeswitch/sounds/custom/greeting.wav)"'
