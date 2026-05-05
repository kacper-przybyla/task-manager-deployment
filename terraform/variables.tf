variable "aws_region" {
    description = "Region of AWS"
    type = string
    default = "eu-central-1"
}

variable "environment" {
    description = "Deployment environment"
    type = string
    default = "dev"
}

variable "project_name" {
    description = "Name of the project"
    type = string
    default = "task-manager"
}

variable "instance_type" {
    description = "EC2 instance type"
    type = string
    default = "t3.micro"
}