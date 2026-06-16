output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "bastion_public_ip" {
  description = "The public IP of the Bastion jump host"
  value       = aws_instance.bastion.public_ip
}

output "proxy_public_ip" {
  description = "The static IP for Twilio to send SIP/RTP traffic to and to access pgAdmin/APIs"
  value       = aws_eip.proxy_eip.public_ip
}

output "freeswitch_private_ip" {
  description = "The private IP of the FreeSWITCH stack instance"
  value       = aws_instance.freeswitch.private_ip
}

output "ssh_bastion_tunnel_cmd" {
  description = "SSH proxy jump command to connect to the private FreeSWITCH instance"
  value       = "ssh -i ./freeswitch-key.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.freeswitch.private_ip}"
}
