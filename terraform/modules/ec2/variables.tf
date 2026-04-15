variable "environment" {
    description = "Deployment environment"
    type = string
}

variable "project_name" {
    description = "Name of the project"
    type = string
}


variable "instance_type" {
    description = "EC2 instance type"
    type = string
}

variable "vpc_id" {
    description = "VPC ID"
    type = string
}


variable "public_subnet_id" {
    description = "The public subnet ID to launch the instance in"
    type = string
}