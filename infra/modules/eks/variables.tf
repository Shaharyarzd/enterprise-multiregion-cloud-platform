variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR used to constrain node-to-node and private service egress."
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "endpoint_public_access" {
  type    = bool
  default = false

  validation {
    condition     = !var.endpoint_public_access || length(var.endpoint_public_access_cidrs) > 0
    error_message = "Public EKS API access requires at least one trusted CIDR."
  }
}

variable "endpoint_public_access_cidrs" {
  type    = list(string)
  default = []

  validation {
    condition     = !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0") && !contains(var.endpoint_public_access_cidrs, "::/0")
    error_message = "The EKS API must not be exposed to the entire internet."
  }
}

variable "cluster_admin_principal_arn" {
  type     = string
  default  = null
  nullable = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
