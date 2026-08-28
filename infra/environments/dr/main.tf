data "aws_availability_zones" "available" {
  count = var.enable_dr ? 1 : 0
  state = "available"
}

locals {
  azs = var.enable_dr ? slice(data.aws_availability_zones.available[0].names, 0, 3) : []

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Portfolio   = "true"
    DataClass   = "synthetic-only"
    DR          = "scaffold"
  }
}

module "network" {
  count  = var.enable_dr ? 1 : 0
  source = "../../modules/network"

  name = "${var.project_name}-dr"
  cidr = "10.30.0.0/16"
  azs  = local.azs

  public_subnets   = ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"]
  private_subnets  = ["10.30.10.0/24", "10.30.11.0/24", "10.30.12.0/24"]
  database_subnets = ["10.30.20.0/24", "10.30.21.0/24", "10.30.22.0/24"]

  single_nat_gateway = true
  tags               = local.common_tags
}

module "eks" {
  count  = var.enable_dr ? 1 : 0
  source = "../../modules/eks"

  name               = "${var.project_name}-dr"
  region             = var.aws_region
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network[0].vpc_id
  vpc_cidr_block     = module.network[0].vpc_cidr_block
  private_subnet_ids = module.network[0].private_subnets

  endpoint_public_access       = var.eks_endpoint_public_access
  endpoint_public_access_cidrs = var.allowed_eks_api_cidrs
  cluster_admin_principal_arn  = var.cluster_admin_principal_arn

  node_instance_types = ["t3.medium"]
  node_min_size       = 1
  node_desired_size   = 1
  node_max_size       = 3

  tags = local.common_tags
}

# Intentionally no always-on DR database in milestone 1.
# The disaster-recovery runbook defines restore/promotion as an explicit recovery step.
