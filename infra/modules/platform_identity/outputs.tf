output "careflow_secrets_role_arn" {
  value = aws_iam_role.careflow_secrets.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.load_balancer_controller.arn
}
