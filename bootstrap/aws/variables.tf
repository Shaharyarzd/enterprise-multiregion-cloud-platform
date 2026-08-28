variable "account_id" {
  type        = string
  description = "The 12-digit ID of the personal AWS sandbox account."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region used by the CareFlow demo and its state bucket."
}

variable "bootstrap_user_name" {
  type        = string
  default     = "careflow-portfolio-admin"
  description = "Existing read-only IAM user allowed to assume the deployment role with MFA."

  validation {
    condition     = var.bootstrap_user_name == "careflow-portfolio-admin"
    error_message = "This audited bootstrap is restricted to careflow-portfolio-admin."
  }
}

variable "project_name" {
  type        = string
  default     = "careflow-portfolio"
  description = "Project tag and resource-name prefix."
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state."

  validation {
    condition = (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name)) &&
      var.state_bucket_name == "careflow-tfstate-${var.account_id}-${var.aws_region}"
    )
    error_message = "state_bucket_name must be careflow-tfstate-ACCOUNT_ID-REGION for this sandbox."
  }
}

variable "github_repository" {
  type        = string
  default     = null
  nullable    = true
  description = "Exact GitHub owner/repository. Keep null until the real repository is confirmed (OWNER INPUT REQUIRED)."

  validation {
    condition = var.github_repository == null || (
      can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository)) &&
      !startswith(var.github_repository, "REPLACE_ME/") &&
      !startswith(var.github_repository, "OWNER_INPUT_REQUIRED/")
    )
    error_message = "github_repository must be null or the exact real owner/repository, never a placeholder."
  }
}

variable "github_environment" {
  type        = string
  default     = "portfolio-publish"
  description = "Protected GitHub environment allowed to request the ECR publisher role."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_environment))
    error_message = "github_environment may contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "github_repository_owner_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Immutable numeric GitHub owner ID used in the repository OIDC subject."

  validation {
    condition     = var.github_repository_owner_id == null || can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must be null or the exact numeric GitHub owner ID."
  }
}

variable "github_repository_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Immutable numeric GitHub repository ID used in the repository OIDC subject."

  validation {
    condition     = var.github_repository_id == null || can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be null or the exact numeric GitHub repository ID."
  }
}
