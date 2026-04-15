output "vpc_id" {
    description = "The VPC ID"
    value = aws_vpc.main.id
}

output "public_subnet_id" {
    description = "The public subnet ID"
    value = aws_subnet.public.id
}

output "vpc_cidr" {
    description = "The VPC CIDR block"
    value = aws_vpc.main.cidr_block
}

output "region" {
    description = "AWS region resources are deployed in"
    value = var.aws_region
}


