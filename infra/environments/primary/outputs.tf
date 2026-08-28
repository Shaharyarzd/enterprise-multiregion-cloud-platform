output "cloud_resources_enabled" {
  value = var.enable_cloud_resources
}

output "deployment_profile" {
  value = var.deployment_profile
}

output "cluster_name" {
  value = var.enable_cloud_resources ? module.eks[0].cluster_name : null
}

output "database_endpoint" {
  value     = var.enable_cloud_resources ? module.database[0].endpoint : null
  sensitive = true
}

output "database_master_secret_arn" {
  value     = var.enable_cloud_resources ? module.database[0].master_user_secret_arn : null
  sensitive = true
}

output "vpc_id" {
  value = var.enable_cloud_resources ? module.network[0].vpc_id : null
}

output "careflow_workload_security_group_id" {
  value = var.enable_cloud_resources ? aws_security_group.careflow_pods[0].id : null
}

output "careflow_secrets_role_arn" {
  value = var.enable_cloud_resources ? module.platform_identity[0].careflow_secrets_role_arn : null
}

output "load_balancer_controller_role_arn" {
  value = var.enable_cloud_resources ? module.platform_identity[0].load_balancer_controller_role_arn : null
}

output "ecr_repository_url" {
  value = var.enable_cloud_resources ? module.delivery[0].repository_url : null
}

output "github_publisher_role_arn" {
  value = var.enable_cloud_resources ? var.github_publisher_role_arn : null
}
