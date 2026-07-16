module "network" {
  source           = "./modules/network"
  aws_region       = var.aws_region
  allowed_ip_range = var.allowed_ip_range
}

module "compute" {
  source               = "./modules/compute"
  vpc_id               = module.network.vpc_id
  public_subnets       = module.network.public_subnets
  lb_security_group_id = module.network.lb_security_group_id
}
