module "networking" {
    source = "./modules/networking"

    aws_region = var.aws_region
    environment = var.environment
    project_name = var.project_name
}

module "ec2" {
    source = "./modules/ec2"

    environment = var.environment
    project_name = var.project_name
    instance_type = var.instance_type
    vpc_id = module.networking.vpc_id
    public_subnet_id = module.networking.public_subnet_id 
}