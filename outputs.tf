output "id" {
  value = aws_db_instance.database.id
}

output "resource_id" {
  value = aws_db_instance.database.resource_id
}

output "name" {
  value       = aws_db_instance.database.db_name
  description = "Database name"
}

output "host" {
  value = aws_db_instance.database.address
}

output "port" {
  value       = aws_db_instance.database.port
  description = "Database port"
}

output "root" {
  value = {
    user     = aws_db_instance.database.username
    password = one(random_password.root_password[*].result)
  }
  sensitive   = true
  description = "Root user name and password. The password is null when manage_master_password is true."
}

output "master_user_secret_arn" {
  value       = try(aws_db_instance.database.master_user_secret[0].secret_arn, null)
  description = "ARN of the Secrets Manager secret holding the root password, when manage_master_password is true"
}

output "security_group" {
  value = {
    id  = aws_security_group.db.id
    arn = aws_security_group.db.arn
  }
}
