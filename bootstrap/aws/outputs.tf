output "deployment_role_arn" {
  value       = aws_iam_role.deployment.arn
  description = "Configure the careflow-deployment AWS CLI profile to assume this role."
}

output "platform_admin_role_arn" {
  value       = aws_iam_role.platform_admin.arn
  description = "Pass this ARN to cluster_admin_principal_arn in the primary Terraform root."
}

output "state_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "Use this bucket with the primary state key and native S3 lockfile."
}

output "primary_state_key" {
  value = local.primary_state_key
}

output "github_oidc_provider_arn" {
  value       = var.github_repository == null ? null : aws_iam_openid_connect_provider.github[0].arn
  description = "Null until the exact GitHub owner/repository is provided."
}

output "github_publisher_role_arn" {
  value       = var.github_repository == null ? null : aws_iam_role.github_publish[0].arn
  description = "Set this as the protected GitHub environment AWS_PUBLISH_ROLE_ARN variable."
}

