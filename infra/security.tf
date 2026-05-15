data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "asterisk_sg" {
  name   = "asterisk_freepbx_sg"
  vpc_id = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FreePBX Web UI
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # AMI (Asterisk Manager Interface)
  ingress {
    from_port   = 5038
    to_port     = 5038
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SIP signalling (from your SIP provider)
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = var.sip_signalling_cidrs
  }

  # RTP media (from your SIP provider)
  ingress {
    from_port   = 10000
    to_port     = 20000
    protocol    = "udp"
    cidr_blocks = var.sip_media_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Asterisk-FreePBX-SG"
  }
}
