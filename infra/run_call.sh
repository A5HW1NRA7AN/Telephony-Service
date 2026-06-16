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
  'kubectl exec -n default deployment/freeswitch -- fs_cli -p CluSt3r@Esl#2026! -x "originate loopback/1000/public &playback(/usr/share/freeswitch/sounds/custom/greeting.wav)"'
