variable "aws_region" {
    description = "Region of AWS"
    type = string
}

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