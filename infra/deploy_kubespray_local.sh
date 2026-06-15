#!/bin/bash
set -e

# Ensure file permissions on private key are correct
chmod 600 /home/rajan/Projects/Telephony/infra/freeswitch-key.pem

echo "==> Connecting to private server 10.0.1.143 to trigger remote local installation..."

ssh -i /home/rajan/Projects/Telephony/infra/freeswitch-key.pem -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i /home/rajan/Projects/Telephony/infra/freeswitch-key.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@18.183.139.53" ubuntu@10.0.1.143 'bash -s' << 'EOF'
set -e

echo "==> Updating apt package cache..."
sudo apt-get update -y
sudo apt-get install -y git python3-venv python3-pip python3-dev build-essential libssl-dev libffi-dev screen

echo "==> Cloning Kubespray repository..."
if [ ! -d "kubespray" ]; then
  git clone --branch v2.25.0 https://github.com/kubernetes-sigs/kubespray.git
fi
cd kubespray

echo "==> Creating Python virtual environment..."
if [ ! -d "kubespray-venv" ]; then
  python3 -m venv kubespray-venv
fi
source kubespray-venv/bin/activate
pip install -U pip
pip install -r requirements.txt

echo "==> Configuring single-node local host inventory..."
mkdir -p inventory/localcluster
cat << 'INVENTORY' > inventory/localcluster/hosts.yaml
all:
  hosts:
    node1:
      ansible_host: 127.0.0.1
      ip: 127.0.0.1
      ansible_connection: local
  children:
    kube_control_plane:
      hosts:
        node1:
    kube_node:
      hosts:
        node1:
    etcd:
      hosts:
        node1:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
INVENTORY

echo "==> Starting Kubespray installation in background screen session..."
sudo screen -d -m -S kubespray-install bash -c "cd /home/ubuntu/kubespray && source kubespray-venv/bin/activate && ansible-playbook -i inventory/localcluster/hosts.yaml --become cluster.yml > /home/ubuntu/kubespray_install.log 2>&1"

echo "========================================================================"
echo "Kubespray bootstrap has started locally on the private server!"
echo "It will continue running even if your local SSH session or Wi-Fi drops."
echo ""
echo "To monitor the installation log:"
echo "  tail -f /home/ubuntu/kubespray_install.log"
echo ""
echo "To attach to the live screen session:"
echo "  sudo screen -r kubespray-install"
echo "========================================================================"
EOF
