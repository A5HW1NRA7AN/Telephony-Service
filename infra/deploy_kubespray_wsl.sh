#!/bin/bash
set -e

# Ensure file permissions on private key are correct
chmod 600 /home/rajan/Projects/Telephony/infra/freeswitch-key.pem

echo "==> Deploying Kubespray from WSL using optimized SSH multiplexing..."

# Copy host configuration to kubespray directory
cp -f /home/rajan/Projects/Telephony/infra/hosts_k8s.yaml /home/rajan/Projects/kubespray/inventory/mycluster/hosts.yaml

# Run playbook
cd /home/rajan/Projects/kubespray
/home/rajan/Projects/kubespray-venv/bin/ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root -u ubuntu --private-key=/home/rajan/Projects/Telephony/infra/freeswitch-key.pem cluster.yml
