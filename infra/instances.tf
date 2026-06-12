# ── AMI (Ubuntu 24.04 LTS) ────────────────────────────────────────────────────

data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Instances ─────────────────────────────────────────────────────────────────

# 1. Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.freeswitch_key_pair.key_name

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.cluster_name}-bastion"
  }

  lifecycle {
    ignore_changes = [key_name, associate_public_ip_address]
  }
}

# 2. Private FreeSWITCH Server (Private Subnet)
resource "aws_instance" "freeswitch" {
  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.freeswitch_key_pair.key_name

  subnet_id              = module.vpc.private_subnets[0]
  private_ip             = "10.0.1.143"
  vpc_security_group_ids = [aws_security_group.freeswitch_sg.id]

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-USERDATA
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl gnupg lsb-release git
USERDATA

  tags = {
    Name = "${var.cluster_name}-server"
  }

  lifecycle {
    ignore_changes = [key_name]
  }
}

# 3. Nginx / SIP Proxy Host (Public Subnet)
resource "aws_instance" "proxy" {
  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.freeswitch_key_pair.key_name

  subnet_id                   = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  associate_public_ip_address = true

  user_data = <<-USERDATA
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Pre-configure debconf to avoid prompts during iptables-persistent install
echo iptables-persistent iptables-persistent/prules select true | debconf-set-selections
echo iptables-persistent iptables-persistent/prev6rules select true | debconf-set-selections

apt-get update -y
apt-get install -y nginx iptables-persistent curl

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Setup NAT / DNAT rules
PRIVATE_FS_IP="${aws_instance.freeswitch.private_ip}"

# SIP (UDP 5060)
iptables -t nat -A PREROUTING -p udp --dport 5060 -j DNAT --to-destination $PRIVATE_FS_IP:5060
# SIP (TCP 5060)
iptables -t nat -A PREROUTING -p tcp --dport 5060 -j DNAT --to-destination $PRIVATE_FS_IP:5060
# RTP range (UDP 16384-32768)
iptables -t nat -A PREROUTING -p udp --dport 16384:32768 -j DNAT --to-destination $PRIVATE_FS_IP

# POSTROUTING Masquerade
iptables -t nat -A POSTROUTING -j MASQUERADE

# Save iptables rules
netfilter-persistent save

# Configure Nginx Reverse Proxy
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location /pgadmin/ {
        proxy_pass http://\$PRIVATE_FS_IP:5050/;
        proxy_set_header Host \$host;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Script-Name /pgadmin;
        proxy_redirect off;
    }

    location /leads/ {
        proxy_pass http://\$PRIVATE_FS_IP:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

systemctl restart nginx
USERDATA

  tags = {
    Name = "${var.cluster_name}-proxy"
  }

  lifecycle {
    ignore_changes = [key_name, associate_public_ip_address]
  }
}

# ── Elastic IP for the Proxy (Twilio & Web Traffic entry point) ──────────────

resource "aws_eip" "proxy_eip" {
  domain   = "vpc"
  instance = aws_instance.proxy.id

  tags = {
    Name = "${var.cluster_name}-proxy-eip"
  }
}
