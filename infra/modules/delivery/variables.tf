variable "name" {
  type = string
}

variable "repository_force_delete" {
  type        = bool
  default     = false
  description = "Allow an explicitly ephemeral demo repository to be removed with images during teardown. Keep false for persistent environments."
}

variable "tags" {
  type    = map(string)
  default = {}
}
