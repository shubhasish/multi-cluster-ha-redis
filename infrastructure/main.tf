variable "region" {
  default = "us-east-1"
}

variable "env" {
  default = "develop"
}

provider "aws" {
  region = var.region
}

module "vpc1" {
  source          = "./modules/network/"
  name            = "${var.env}-vpc"
  env             = var.env
  cidr            = "10.5.0.0/16"
  public_subnets  = ["10.5.1.0/24", "10.5.2.0/24"]
  private_subnets = ["10.5.11.0/24", "10.5.12.0/24"]

  azs = "us-east-1a,us-east-1b"

  region             = var.region
  zone_id_private    = ""
  nat_gateways_count = 1
}

module "vpc2" {
  source          = "./modules/network/"
  name            = "${var.env}-vpc2"
  env             = var.env
  cidr            = "10.6.0.0/16"
  public_subnets  = ["10.6.1.0/24", "10.6.2.0/24"]
  private_subnets = ["10.6.11.0/24", "10.6.12.0/24"]

  azs = "us-east-1a,us-east-1b"

  region             = var.region
  zone_id_private    = ""
  nat_gateways_count = 1
}

module "vpc_peering" {
  source                 = "./modules/vpc_peering"
  vpc_id                 = module.vpc1.vpc_id
  vpc1_route_table_id    = module.vpc1.route_table_id
  vpc_id_cidr_block      = "10.5.0.0/16"
  peer_vpc_id            = module.vpc2.vpc_id
  vpc2_route_table_id    = module.vpc2.route_table_id
  peer_vpc_id_cidr_block = "10.6.0.0/16"
  env                    = var.env
  depends_on             = [module.vpc1, module.vpc2]
}

module "internal_route53_zone" {
  source        = "./modules/route53"
  name          = "redis-ha"
  first_vpc_id  = module.vpc1.vpc_id
  second_vpc_id = module.vpc2.vpc_id
  depends_on    = [module.vpc1, module.vpc2, module.vpc_peering]
}



module "eks1" {
  source               = "./modules/eks"
  vpc_id               = module.vpc1.vpc_id
  subnet_ids           = module.vpc1.private_subnets
  name                 = "redis1"
  depends_on           = [module.vpc1, module.vpc2, module.vpc_peering, module.internal_route53_zone]
  cross_vpc_cidr_block = ["10.6.0.0/16"]
  vpc_cidr_block       = ["10.5.0.0/16"]
}

module "eks2" {
  source               = "./modules/eks"
  vpc_id               = module.vpc2.vpc_id
  subnet_ids           = module.vpc2.private_subnets
  name                 = "redis2"
  depends_on           = [module.vpc1, module.vpc2, module.vpc_peering, module.internal_route53_zone]
  cross_vpc_cidr_block = ["10.5.0.0/16"]
  vpc_cidr_block       = ["10.6.0.0/16"]
}