data "aws_availability_zones" "available" {
  count = var.enable_cloud_resources ? 1 : 0
  state = "available"
}

locals {
  azs = var.enable_cloud_resources ? slice(data.aws_availability_zones.available[0].names, 0, 3) : []

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Profile     = var.deployment_profile
    ManagedBy   = "Terraform"
    Portfolio   = "true"
    DataClass   = "synthetic-only"
  }
}

check "cloud_opt_in_prerequisites" {
  assert {
    condition = !var.enable_cloud_resources || (
      var.github_oidc_provider_arn != null &&
      var.github_publisher_role_arn != null &&
      var.github_repository != "REPLACE_ME/enterprise-multiregion-cloud-platform" &&
      var.cluster_admin_principal_arn != null
    )
    error_message = "Cloud opt-in requires a real GitHub repository, the account GitHub OIDC provider ARN, and an explicit EKS administrator role."
  }
}

module "network" {
  count  = var.enable_cloud_resources ? 1 : 0
  source = "../../modules/network"

  name = "${var.project_name}-primary"
  cidr = "10.20.0.0/16"
  azs  = local.azs

  public_subnets   = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
  private_subnets  = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
  database_subnets = ["10.20.20.0/24", "10.20.21.0/24", "10.20.22.0/24"]

  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

module "eks" {
  count  = var.enable_cloud_resources ? 1 : 0
  source = "../../modules/eks"

  name               = "${var.project_name}-primary"
  region             = var.aws_region
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network[0].vpc_id
  vpc_cidr_block     = module.network[0].vpc_cidr_block
  private_subnet_ids = module.network[0].private_subnets

  endpoint_public_access       = var.eks_endpoint_public_access
  endpoint_public_access_cidrs = var.allowed_eks_api_cidrs
  cluster_admin_principal_arn  = var.cluster_admin_principal_arn

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size

  tags = local.common_tags
}

resource "aws_security_group" "careflow_pods" {
  count       = var.enable_cloud_resources ? 1 : 0
  name_prefix = "${var.project_name}-careflow-pods-"
  description = "Network identity for CareFlow pods; not shared with worker nodes"
  vpc_id      = module.network[0].vpc_id

  tags = merge(local.common_tags, {
    Name                                                  = "${var.project_name}-careflow-pods"
    "kubernetes.io/cluster/${module.eks[0].cluster_name}" = "owned"
  })
}

resource "aws_vpc_security_group_egress_rule" "careflow_dns_udp" {
  count             = var.enable_cloud_resources ? 1 : 0
  security_group_id = aws_security_group.careflow_pods[0].id
  cidr_ipv4         = module.network[0].vpc_cidr_block
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "DNS inside the VPC"
}

resource "aws_vpc_security_group_egress_rule" "careflow_dns_tcp" {
  count             = var.enable_cloud_resources ? 1 : 0
  security_group_id = aws_security_group.careflow_pods[0].id
  cidr_ipv4         = module.network[0].vpc_cidr_block
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "DNS fallback inside the VPC"
}

module "database" {
  count  = var.enable_cloud_resources ? 1 : 0
  source = "../../modules/database"

  name                       = "${var.project_name}-primary"
  vpc_id                     = module.network[0].vpc_id
  subnet_group_name          = module.network[0].database_subnet_group_name
  allowed_security_group_ids = [aws_security_group.careflow_pods[0].id]
  multi_az                   = var.database_multi_az
  deletion_protection        = var.database_deletion_protection
  skip_final_snapshot        = var.database_skip_final_snapshot
  backup_retention_period    = var.database_backup_retention_days

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "careflow_database" {
  count                        = var.enable_cloud_resources ? 1 : 0
  security_group_id            = aws_security_group.careflow_pods[0].id
  referenced_security_group_id = module.database[0].security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL to the CareFlow RDS security group only"
}

module "platform_identity" {
  count  = var.enable_cloud_resources ? 1 : 0
  source = "../../modules/platform_identity"

  name                = "${var.project_name}-primary"
  oidc_provider_arn   = module.eks[0].oidc_provider_arn
  oidc_provider       = module.eks[0].oidc_provider
  database_secret_arn = module.database[0].master_user_secret_arn
  tags                = local.common_tags
}

module "delivery" {
  count  = var.enable_cloud_resources ? 1 : 0
  source = "../../modules/delivery"

  name                    = "${var.project_name}/careflow-api"
  repository_force_delete = var.ecr_force_delete
  tags                    = local.common_tags
}
