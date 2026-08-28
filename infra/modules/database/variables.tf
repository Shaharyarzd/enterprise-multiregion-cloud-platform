variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_group_name" {
  type = string
}

variable "allowed_security_group_ids" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type        = string
  default     = "17"
  description = "PostgreSQL major version; minor upgrades remain automatic."
}

variable "parameter_group_family" {
  type    = string
  default = "postgres17"
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 14

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 1 and 35 days. Profile-level policy determines the appropriate value."
  }
}

variable "kms_key_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional customer-managed KMS key ARN for RDS storage encryption."
}

variable "tags" {
  type    = map(string)
  default = {}
}
