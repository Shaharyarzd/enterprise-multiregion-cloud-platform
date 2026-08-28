variable "name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
