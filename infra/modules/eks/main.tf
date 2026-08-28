module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = var.name
  region             = var.region
  kubernetes_version = var.kubernetes_version

  endpoint_private_access      = true
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  iam_role_name                            = "${var.name}-cluster"
  iam_role_use_name_prefix                 = false
  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  access_entries = var.cluster_admin_principal_arn == null ? {} : {
    platform_administrator = {
      principal_arn = var.cluster_admin_principal_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 30
  enable_irsa                            = true

  addons = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        env = {
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
      })
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  node_security_group_enable_recommended_rules = false
  node_security_group_additional_rules = {
    ingress_nodes_ephemeral = {
      description = "Node-to-node and pod traffic"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
    ingress_cluster_metrics_webhook = {
      description                   = "Cluster API to metrics-server webhook"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_platform_webhooks = {
      description                   = "Cluster API to platform admission webhooks"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_vpc = {
      description = "Node and pod traffic inside the VPC"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = [var.vpc_cidr_block]
    }
    egress_https = {
      description = "TLS egress for AWS APIs, registries and approved internet dependencies"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_dns_tcp = {
      description = "DNS over TCP inside the VPC"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      cidr_blocks = [var.vpc_cidr_block]
    }
    egress_dns_udp = {
      description = "DNS over UDP inside the VPC"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      cidr_blocks = [var.vpc_cidr_block]
    }
    egress_time_sync = {
      description = "Amazon Time Sync Service"
      protocol    = "udp"
      from_port   = 123
      to_port     = 123
      type        = "egress"
      cidr_blocks = ["169.254.169.123/32"]
    }
  }

  eks_managed_node_groups = {
    application = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted             = true
            volume_size           = 20
            volume_type           = "gp3"
          }
        }
      }

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      capacity_type            = "ON_DEMAND"
      iam_role_name            = "${var.name}-application-node"
      iam_role_use_name_prefix = false

      update_config = {
        max_unavailable_percentage = 33
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_protocol_ipv6          = "disabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "required"
      }

      labels = {
        workload = "general"
      }
    }
  }

  tags = var.tags
}
