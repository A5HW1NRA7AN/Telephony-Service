output "asterisk_public_ip" {
  description = "Public IP of the Asterisk/FreePBX server"
  value       = aws_eip.asterisk_eip.public_ip
}

output "ssh_command" {
  description = "SSH command to access the server"
  value       = "ssh -i asterisk-key.pem admin@${aws_eip.asterisk_eip.public_ip}"
}

output "freepbx_url" {
  description = "FreePBX web admin URL"
  value       = "http://${aws_eip.asterisk_eip.public_ip}"
}

output "ami_host" {
  description = "AMI host for lead-service application.properties"
  value       = aws_eip.asterisk_eip.public_ip
}

output "ami_port" {
  description = "AMI port (default)"
  value       = 5038
}
