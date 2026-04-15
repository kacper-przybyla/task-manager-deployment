output "vpc_id" {
    description = "The VPC ID"
    value = module.networking.vpc_id
}

output "public_subnet_id" {
    description = "The public subnet ID"
    value = module.networking.public_subnet_id 
}

output "web_public_ip" {
    description = "The public IP of the EC2 server"
    value = module.ec2.web_public_ip
}

output "web_public_dns" {
    description = "The public DNS hostname of the EC2 server"
    value = module.ec2.web_public_dns
}

output "ssh_command" {
    description = "SSH command to connect to the instance"
    value = module.ec2.ssh_command
}