locals {
  related_name = "${var.name}-db"
}

resource "random_password" "root_password" {
  count  = var.manage_master_password ? 0 : 1
  length = 15
}

moved {
  from = random_password.root_password
  to   = random_password.root_password[0]
}

resource "aws_db_parameter_group" "parameters" {
  # A date suffix gives each group a unique name, so a replacement (a new family on a major version
  # upgrade) can be created before the old group, which the database is still using, is deleted
  name        = "${var.name}-${formatdate("YYYYMMDDhhmm", plantimestamp())}"
  family      = local.engine_family
  description = "Managed by terraform"

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.key
      value        = parameter.value.value
      apply_method = coalesce(try(parameter.value.immediate, null), true) ? "immediate" : "pending-reboot"
    }
  }

  lifecycle {
    create_before_destroy = true
    # Deliberately ignored: RDS can't change either in place, so a change replaces the group, and
    # deleting a group the database uses fails. The name's date suffix changes on every plan, and
    # descriptions once held the Terragrunt cache path, which differs between machines and CI. A
    # replacement for any other reason still takes the current name and description
    ignore_changes = [name, description]
  }
}

resource "aws_db_subnet_group" "db" {
  name        = var.name
  description = "Managed by terraform"
  subnet_ids  = var.public ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = local.related_name
  vpc_id      = module.vpc.id
  description = "Managed by terraform"

  tags = {
    Name = local.related_name
  }

  lifecycle {
    # Deliberately ignored: a description change replaces the security group, which the database
    # is attached to. Descriptions once held the Terragrunt cache path, which differs between
    # machines and CI
    ignore_changes        = [description]
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allowed" {
  for_each                 = toset(var.allowed_security_groups)
  security_group_id        = aws_security_group.db.id
  to_port                  = local.engine.port
  from_port                = local.engine.port
  protocol                 = "TCP"
  type                     = "ingress"
  source_security_group_id = each.value
  description              = "Managed by terraform"
}

resource "aws_security_group_rule" "public" {
  count             = var.public ? 1 : 0
  security_group_id = aws_security_group.db.id
  to_port           = local.engine.port
  from_port         = local.engine.port
  protocol          = "TCP"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public access (Managed by terraform)"
}

resource "aws_security_group_rule" "outbound" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Managed by terraform"
}

resource "aws_db_instance" "database" {
  identifier                          = var.name
  allocated_storage                   = var.storage_size
  storage_type                        = var.storage_type
  storage_encrypted                   = var.kms_key_id != null
  kms_key_id                          = var.kms_key_id
  instance_class                      = var.instance_type
  engine                              = local.engine.name
  engine_version                      = local.engine_version
  db_name                             = coalesce(var.db_name, var.name)
  port                                = local.engine.port
  username                            = "root"
  password                            = var.manage_master_password ? null : one(random_password.root_password[*].result)
  manage_master_user_password         = var.manage_master_password ? true : null
  parameter_group_name                = aws_db_parameter_group.parameters.name
  skip_final_snapshot                 = !var.final_snapshot
  final_snapshot_identifier           = var.final_snapshot ? "${var.name}-final" : null
  deletion_protection                 = var.deletion_protection
  vpc_security_group_ids              = [aws_security_group.db.id]
  db_subnet_group_name                = aws_db_subnet_group.db.name
  multi_az                            = coalesce(var.multi_az, module.tagging.production)
  apply_immediately                   = !module.tagging.production
  maintenance_window                  = "Thu:07:40-Thu:08:10"
  backup_window                       = "10:57-11:27"
  backup_retention_period             = coalesce(var.backup_retention_days, module.tagging.production ? 7 : 2)
  allow_major_version_upgrade         = false
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = var.iam
  publicly_accessible                 = var.public
  enabled_cloudwatch_logs_exports     = var.log_exports

  lifecycle {
    ignore_changes = [db_name, snapshot_identifier, engine_version]
  }

  depends_on = [
    aws_security_group_rule.allowed,
    aws_security_group_rule.outbound
  ]
}

module "mysql_users" {
  count    = try(local.engine.style, local.engine.name) == "mysql" ? 1 : 0
  source   = "./modules/mysql"
  aws      = module.base
  database = aws_db_instance.database
  groups   = var.groups
  users    = var.users
}
