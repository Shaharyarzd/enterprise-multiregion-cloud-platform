variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "enable_cloud_resources" {
  type        = bool
  default     = false
  description = "Cost guard. The default apply is a no-op; set true only for a reviewed, time-boxed cloud demo."
}

variable "deployment_profile" {
  type        = string
  default     = "production-target"
  description = "Explicit architecture profile: production-target preserves production requirements; free-plan-demo is a constrained execution profile."

  validation {
    condition     = contains(["production-target", "free-plan-demo"], var.deployment_profile)
    error_message = "deployment_profile must be production-target or free-plan-demo."
  }

  validation {
    condition = !var.enable_cloud_resources || (
      var.deployment_profile == "free-plan-demo" ? (
        length(var.node_instance_types) == 1 &&
        var.node_instance_types[0] == "c7i-flex.large" &&
        var.node_min_size == 2 &&
        var.node_desired_size == 2 &&
        var.database_backup_retention_days == 1 &&
        !var.database_multi_az &&
        var.single_nat_gateway
        ) : (
        length(var.node_instance_types) == 1 &&
        var.node_instance_types[0] == "t3.medium" &&
        var.node_min_size == 2 &&
        var.node_desired_size == 3 &&
        var.database_backup_retention_days >= 7 &&
        var.database_multi_az &&
        !var.single_nat_gateway &&
        var.database_deletion_protection &&
        !var.database_skip_final_snapshot &&
        !var.ecr_force_delete
      )
    )
    error_message = "Enabled profiles must keep their reviewed constraints: free-plan-demo uses two c7i-flex.large workers, one-day Single-AZ RDS and one NAT; production-target uses three desired t3.medium workers, at least seven-day Multi-AZ protected RDS and per-AZ NAT."
  }
}

variable "github_repository" {
  type        = string
  default     = "REPLACE_ME/enterprise-multiregion-cloud-platform"
  description = "GitHub owner/repository trusted to publish images from main."
}

variable "github_oidc_provider_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing account-level GitHub Actions OIDC provider ARN."
}

variable "github_publisher_role_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "Bootstrap-created GitHub OIDC role restricted to the protected publication environment."

  validation {
    condition     = var.github_publisher_role_arn == null || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/careflow-github-ecr-publisher$", var.github_publisher_role_arn))
    error_message = "github_publisher_role_arn must be the careflow-github-ecr-publisher IAM role ARN or null."
  }
}

variable "project_name" {
  type    = string
  default = "careflow-portfolio"
}

variable "environment" {
  type    = string
  default = "portfolio"

  validation {
    condition = var.environment != "production" || (
      !var.single_nat_gateway &&
      var.database_multi_az &&
      var.database_deletion_protection &&
      !var.database_skip_final_snapshot &&
      !var.ecr_force_delete &&
      var.cluster_admin_principal_arn != null
    )
    error_message = "Production requires per-AZ NAT, Multi-AZ RDS, deletion protection, a final snapshot, and an explicit cluster-admin role."
  }
}

variable "ecr_force_delete" {
  type        = bool
  default     = false
  description = "Ephemeral-demo opt-in allowing Terraform to delete a non-empty ECR repository during teardown."
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "eks_endpoint_public_access" {
  type        = bool
  default     = false
  description = "Expose the EKS API publicly. Keep false unless trusted CIDRs are supplied."

  validation {
    condition     = !var.eks_endpoint_public_access || length(var.allowed_eks_api_cidrs) > 0
    error_message = "Public EKS API access requires at least one trusted CIDR."
  }
}

variable "allowed_eks_api_cidrs" {
  type        = list(string)
  description = "Trusted public CIDRs for the EKS API when public access is enabled."
  default     = []

  validation {
    condition     = !contains(var.allowed_eks_api_cidrs, "0.0.0.0/0") && !contains(var.allowed_eks_api_cidrs, "::/0")
    error_message = "The EKS API must not be exposed to the entire internet."
  }
}

variable "cluster_admin_principal_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional IAM role ARN granted EKS cluster-admin access through an explicit access entry."

  validation {
    condition     = var.cluster_admin_principal_arn == null || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.cluster_admin_principal_arn))
    error_message = "cluster_admin_principal_arn must be an IAM role ARN or null."
  }
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "Cost-saving demo mode. Production HA would normally use one NAT gateway per AZ."
}

variable "database_multi_az" {
  type        = bool
  default     = false
  description = "Cost-saving demo default. Set true for production-like AZ resilience."
}

variable "database_deletion_protection" {
  type        = bool
  default     = false
  description = "Cost-saving demo default. Set true for persistent environments."
}

variable "database_skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Cost-saving demo default. Set false for persistent environments."
}

variable "database_backup_retention_days" {
  type        = number
  default     = 7
  description = "Automated RDS backup retention. Production target remains seven days; the Free-plan demo uses the account-constrained one-day value."

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "database_backup_retention_days must be between 1 and 35 days."
  }
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Use only after checking current EKS and workload compatibility."
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}
