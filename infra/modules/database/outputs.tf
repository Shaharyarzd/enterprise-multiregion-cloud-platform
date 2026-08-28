output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "master_user_secret_arn" {
  value = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}

output "security_group_id" {
  value = aws_security_group.database.id
}
