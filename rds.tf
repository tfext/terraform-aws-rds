locals {
  related_name = "${var.name}-db"
}

resource "random_password" "root_password" {
  length  = 15
  override_special = "!$#&*_-"
}

resource "aws_db_parameter_group" "parameters" {
  name        = var.name
  family      = local.engine_family
  description = module.tagging.managed_by_description

  dynamic "parameter" {
    for_each = try(local.engine.parameters, {})
    content {
      name         = parameter.key
      value        = parameter.value.value
      apply_method = try(parameter.value.immediate, true) ? "immediate" : "pending-reboot"
    }
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_db_subnet_group" "db" {
  name        = var.name
  description = module.tagging.managed_by_description
  subnet_ids  = var.public ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = local.related_name
  vpc_id      = module.vpc.id
  description = module.tagging.managed_by_description

  tags = {
    Name = local.related_name
  }

  lifecycle {
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
  description              = module.tagging.managed_by_description
}

resource "aws_security_group_rule" "public" {
  count             = var.public ? 1 : 0
  security_group_id = aws_security_group.db.id
  to_port           = local.engine.port
  from_port         = local.engine.port
  protocol          = "TCP"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public access (${module.tagging.managed_by_description})"
}

resource "aws_security_group_rule" "outbound" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = module.tagging.managed_by_description
}

resource "aws_db_instance" "database" {
  identifier                          = var.name
  allocated_storage                   = var.storage_size
  storage_type                        = "gp2"
  instance_class                      = var.instance_type
  engine                              = local.engine.name
  engine_version                      = local.engine_version
  db_name                             = coalesce(var.db_name, var.name)
  port                                = local.engine.port
  username                            = "root"
  password                            = random_password.root_password.result
  parameter_group_name                = aws_db_parameter_group.parameters.name
  skip_final_snapshot                 = true
  vpc_security_group_ids              = [aws_security_group.db.id]
  db_subnet_group_name                = aws_db_subnet_group.db.name
  multi_az                            = coalesce(var.multi_az, module.tagging.production)
  apply_immediately                   = !module.tagging.production
  maintenance_window                  = "Thu:07:40-Thu:08:10"
  backup_window                       = "10:57-11:27"
  backup_retention_period             = module.tagging.production ? 7 : 2
  allow_major_version_upgrade         = false
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = var.iam
  publicly_accessible                 = var.public

  lifecycle {
    ignore_changes = [db_name, snapshot_identifier, engine_version]
  }

  depends_on = [
    aws_db_parameter_group.parameters,
    aws_security_group_rule.allowed,
    aws_security_group_rule.outbound
  ]
}

module "mysql_users" {
  count    = local.manage_users == "mysql" && var.mysql != null ? 1 : 0
  source   = "./modules/mysql"
  aws      = module.base
  database = aws_db_instance.database
  groups   = var.mysql.groups
  users    = var.mysql.users
}

module "postgres_users" {
  count    = local.manage_users == "postgres" && var.postgres != null ? 1 : 0
  source   = "./modules/postgresql"
  database = aws_db_instance.database
  groups   = var.postgres.groups
  users    = var.postgres.users
}
