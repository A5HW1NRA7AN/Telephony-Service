terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── SSH Key (auto-generated) ──────────────────────────────────────────────────

resource "tls_private_key" "asterisk_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "asterisk_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.asterisk_key.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.asterisk_key.private_key_pem
  filename        = "${path.module}/asterisk-key.pem"
  file_permission = "0400"
}

# ── AMI (Debian 12) ──────────────────────────────────────────────────────────

data "aws_ami" "debian_12" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "asterisk_server" {
  ami           = data.aws_ami.debian_12.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.asterisk_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.asterisk_sg.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-USERDATA
#!/bin/bash
set -e
hostnamectl set-hostname freepbx.local
apt-get update -y
apt-get upgrade -y

# ── 1. Install FreePBX ────────────────────────────────────────────────
cd /usr/src
wget https://github.com/FreePBX/sng_freepbx_debian_install/raw/master/sng_freepbx_debian_install.sh -O sng_freepbx_debian_install.sh
chmod +x sng_freepbx_debian_install.sh
export DEBIAN_FRONTEND=noninteractive
./sng_freepbx_debian_install.sh

sleep 30

# ── 2. Auto-detect NAT (public IP + local subnet) ────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
LOCAL_CIDR=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/mac)/subnet-ipv4-cidr-block)

cat > /etc/asterisk/rtp_custom.conf <<'NATCFG'
[general]
externip=$PUBLIC_IP
localnet=$LOCAL_CIDR
NATCFG
sed -i "s|\$PUBLIC_IP|$PUBLIC_IP|g; s|\$LOCAL_CIDR|$LOCAL_CIDR|g" /etc/asterisk/rtp_custom.conf

# ── 3. SIP Trunk Configuration (provider-agnostic) ────────────────────
cat > /etc/asterisk/pjsip_custom.conf <<'EOC'
[sip-trunk]
type=endpoint
transport=0.0.0.0-udp
context=from-missed-call
disallow=all
allow=ulaw
aors=sip-trunk
rewrite_contact=yes
rtp_symmetric=yes
force_rport=yes

[sip-trunk]
type=aor
contact=sip:PLACEHOLDER_SIP_DOMAIN:5060

[sip-trunk]
type=identify
endpoint=sip-trunk
match=PLACEHOLDER_SIP_IPS

[0.0.0.0-udp](+)
type=transport
local_net=PLACEHOLDER_LOCAL_NET
external_media_address=PLACEHOLDER_PUBLIC_IP
external_signaling_address=PLACEHOLDER_PUBLIC_IP
EOC
sed -i "s|from-missed-call|${var.dialplan_context}|g; s|PLACEHOLDER_SIP_DOMAIN|${var.sip_provider_domain}|g; s|PLACEHOLDER_SIP_IPS|${var.sip_provider_ip_ranges}|g; s|PLACEHOLDER_LOCAL_NET|$LOCAL_CIDR|g; s|PLACEHOLDER_PUBLIC_IP|$PUBLIC_IP|g" /etc/asterisk/pjsip_custom.conf

# ── 4. AMI User ──────────────────────────────────────────────────────
cat > /etc/asterisk/manager_custom.conf <<'EOC'
[PLACEHOLDER_AMI_USER]
secret = PLACEHOLDER_AMI_PASS
deny=0.0.0.0/0.0.0.0
permit=0.0.0.0/0.0.0.0
read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate
write = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate
EOC
sed -i "s|PLACEHOLDER_AMI_USER|${var.ami_username}|g; s|PLACEHOLDER_AMI_PASS|${var.ami_password}|g" /etc/asterisk/manager_custom.conf

# Force AMI to listen on 0.0.0.0
sed -i 's/^enabled\s*=.*/enabled = yes/' /etc/asterisk/manager.conf
sed -i 's/^bindaddr\s*=.*/bindaddr = 0.0.0.0/' /etc/asterisk/manager.conf

# ── 5. Dialplan ──────────────────────────────────────────────────────
cat > /etc/asterisk/extensions_custom.conf <<'EOC'
[from-missed-call]
exten => _+.,1,NoOp(INCOMING CALL TO: $${EXTEN} FROM: $${CALLERID(num)})
same => n,Set(__CALLED_NUM=$${EXTEN})
same => n,Ringing()
same => n,Wait(2)
same => n,Answer()
same => n,Wait(1)
same => n,Playback(custom/greeting)
same => n,Hangup()

exten => h,1,NoOp(Call ended — context=$${CONTEXT} uniqueid=$${UNIQUEID})
EOC
sed -i "s|from-missed-call|${var.dialplan_context}|g" /etc/asterisk/extensions_custom.conf

# ── 6. Upload greeting audio ─────────────────────────────────────────
mkdir -p /var/lib/asterisk/sounds/custom

# ── 7. Set ownership and reload ──────────────────────────────────────
chown asterisk:asterisk /etc/asterisk/*_custom.conf
fwconsole reload
USERDATA

  tags = {
    Name = "Asterisk-FreePBX-Server"
  }
}

# ── Elastic IP ───────────────────────────────────────────────────────────────

resource "aws_eip" "asterisk_eip" {
  domain   = "vpc"
  instance = aws_instance.asterisk_server.id

  tags = {
    Name = "Asterisk-FreePBX-EIP"
  }
}
