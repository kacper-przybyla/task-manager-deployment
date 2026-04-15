variable "aws_region" {
    description = "AWS region to deploy resources in"
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
