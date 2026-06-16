variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "Prefix name for the resources"
  type        = string
  default     = "freeswitch-telephony"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the FreeSWITCH server"
  type        = string
  default     = "t3.xlarge"
}

variable "key_name" {
  description = "Name for the auto-generated SSH key pair"
  type        = string
  default     = "freeswitch-key-pair"
}

variable "sip_signalling_cidrs" {
  description = "List of CIDR blocks to allow SIP (UDP 5060) inbound (Twilio signaling)"
  type        = list(string)
  default = [
    "54.172.60.0/30", "54.244.51.0/30", "54.171.127.192/30",
    "35.156.191.128/30", "54.65.63.192/30", "54.169.127.128/30",
    "54.252.254.64/30", "177.71.206.192/30"
  ]
}

variable "sip_media_cidrs" {
  description = "List of CIDR blocks to allow RTP media (UDP 16384-32768) (Twilio media)"
  type        = list(string)
  default = [
    "54.172.60.0/23", "34.203.250.0/23", "54.244.51.0/24",
    "35.166.33.0/24", "54.171.127.192/26", "52.215.127.0/24",
    "35.156.191.128/26", "18.195.48.0/24", "54.65.63.192/26",
    "3.112.80.0/24", "54.169.127.128/26", "3.0.73.0/24",
    "54.252.254.64/26", "3.104.90.0/24", "177.71.206.192/26",
    "18.228.249.0/24", "168.86.128.0/18"
  ]
}

variable "allowed_http_ingress_cidrs" {
  description = "List of CIDR blocks allowed to access HTTP reverse proxy (pgAdmin, lead-service)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
