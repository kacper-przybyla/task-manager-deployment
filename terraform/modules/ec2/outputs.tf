output "web_public_ip" {
    description = "Public IP address of the EC2 instance"
    value = aws_eip.web.public_ip
}

output "web_public_dns" {
    description = "Public DNS hostname of the EC2 instance"
    value = aws_eip.web.public_dns
}

output "ssh_command" {
    description = "SSH command to connect to the instance"
    value = "ssh ubuntu@${aws_eip.web.public_ip}"
}

