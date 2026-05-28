#!/bin/bash
# ==============================================================================
# Git Branch Switching Helper with Terraform State & Key Preservation
# ==============================================================================

set -e

TARGET_BRANCH=$1

if [ -z "$TARGET_BRANCH" ]; then
  echo "[-] Usage: ./switch_branch.sh <target-branch>"
  echo "    Example: ./switch_branch.sh asterisk"
  exit 1
fi

# Change directory to the infra folder (where state/key files reside)
cd "$(dirname "$0")/infra"

CURRENT_BRANCH=$(git branch --show-current)

# If we are already on the target branch, do nothing
if [ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]; then
  echo "[+] Already on branch $TARGET_BRANCH."
  exit 0
fi

BACKUP_DIR=".state_backups/$CURRENT_BRANCH"
echo "[+] Backing up current state and keys for branch '$CURRENT_BRANCH' to '$BACKUP_DIR'..."
mkdir -p "../$BACKUP_DIR"

# Copy tfstate and pem files if they exist
[ -f terraform.tfstate ] && cp terraform.tfstate "../$BACKUP_DIR/terraform.tfstate" || true
[ -f terraform.tfstate.backup ] && cp terraform.tfstate.backup "../$BACKUP_DIR/terraform.tfstate.backup" || true
[ -f freeswitch-key.pem ] && cp freeswitch-key.pem "../$BACKUP_DIR/freeswitch-key.pem" || true
[ -f asterisk-key.pem ] && cp asterisk-key.pem "../$BACKUP_DIR/asterisk-key.pem" || true

echo "[+] Switching git branch to '$TARGET_BRANCH'..."
git checkout "$TARGET_BRANCH"

RESTORE_DIR=".state_backups/$TARGET_BRANCH"
if [ -d "../$RESTORE_DIR" ]; then
  echo "[+] Restoring saved state and keys for branch '$TARGET_BRANCH'..."
  [ -f "../$RESTORE_DIR/terraform.tfstate" ] && cp "../$RESTORE_DIR/terraform.tfstate" terraform.tfstate || true
  [ -f "../$RESTORE_DIR/terraform.tfstate.backup" ] && cp "../$RESTORE_DIR/terraform.tfstate.backup" terraform.tfstate.backup || true
  [ -f "../$RESTORE_DIR/freeswitch-key.pem" ] && cp "../$RESTORE_DIR/freeswitch-key.pem" freeswitch-key.pem || true
  [ -f "../$RESTORE_DIR/asterisk-key.pem" ] && cp "../$RESTORE_DIR/asterisk-key.pem" asterisk-key.pem || true
else
  echo "[!] No state backups found for branch '$TARGET_BRANCH'."
  # Clean old state files if any, to avoid cross-branch state pollution
  rm -f terraform.tfstate terraform.tfstate.backup freeswitch-key.pem asterisk-key.pem
fi

echo "[+] Successfully switched to '$TARGET_BRANCH'."
