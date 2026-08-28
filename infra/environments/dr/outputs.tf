output "enabled" {
  value = var.enable_dr
}

output "cluster_name" {
  value = var.enable_dr ? module.eks[0].cluster_name : null
}

output "vpc_id" {
  value = var.enable_dr ? module.network[0].vpc_id : null
}
