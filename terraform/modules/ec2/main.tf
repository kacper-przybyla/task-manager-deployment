terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
      }
    }
}

data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "deployer" {
    key_name = "${var.project_name}-key"
    public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_security_group" "web" {
    name = "${var.project_name}-security-group"
    description = "Security group for ${var.project_name} web server"
    vpc_id = var.vpc_id

    ingress {
        description = "SSH from anywhere"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP from anywhere"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTPS from anywhere"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow all outbound"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.project_name}-security-group"
    })
}

resource "aws_instance" "web" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    subnet_id = var.public_subnet_id
    vpc_security_group_ids = [aws_security_group.web.id]
    key_name = aws_key_pair.deployer.key_name
    user_data_replace_on_change = true
    
    user_data = <<-EOF
        #!/bin/bash
        apt-get update -y
        apt-get install -y docker.io
        apt-get install -y docker-compose
        systemctl start docker
        systemctl enable docker
        usermod -aG docker ubuntu
    EOF

    tags = merge(local.common_tags, {
        Name = "${var.project_name}-ec2-server"
    })
}