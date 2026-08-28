variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "project_name" {
  type    = string
  default = "careflow-portfolio"
}

variable "environment" {
  type    = string
  default = "portfolio-dr"
}

variable "enable_dr" {
  type        = bool
  default     = false
  description = "Explicit cost guard: no DR regional resources are created unless true."
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "eks_endpoint_public_access" {
  type        = bool
  default     = false
  description = "Expose the DR EKS API publicly. Keep false unless trusted CIDRs are supplied."

  validation {
    condition     = !var.eks_endpoint_public_access || length(var.allowed_eks_api_cidrs) > 0
    error_message = "Public EKS API access requires at least one trusted CIDR."
  }
}

variable "allowed_eks_api_cidrs" {
  type        = list(string)
  default     = []
  description = "Trusted public CIDRs for the EKS API when public access is enabled."

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
