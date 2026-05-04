terraform {
    backend "s3" {
      bucket = "kacper-przybyla-terraform-state"
      key = "task-manager/terraform.tfstate"
      region = "eu-central-1"
    }
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
      }
    }
}

provider "aws" {
    region = var.aws_region
}