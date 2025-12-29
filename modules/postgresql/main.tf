data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  psql = join(" ", [
    "/bin/psql",
    "-h", var.database.address,
    "-p", var.database.port,
    "-U", var.database.username,
    "-d", var.database.db_name,
    "-c"
  ])

  psql_env = {
    PGPASSWORD = nonsensitive(var.database.password)
  }

  drop_role_sql = <<-SQL
  DROP ROLE IF EXISTS %[1]s;
  SQL

  create_role_sql = <<-SQL
  CREATE ROLE %[1]s;
  SQL

  drop_user_sql = local.drop_role_sql

  create_user_sql = <<-SQL
  ${local.drop_user_sql}
  CREATE ROLE %[1]s LOGIN;
  SQL

  # SQL to create a role and grant it to the root user.
  # Adding root allows it to call DROP OWNED BY during role deletion.
  # DO NOT grant user roles to root as this would implicitly make it an IAM user
  # and break password authentication.
  create_group_sql = <<-SQL
  ${local.drop_group_sql}
  ${local.create_role_sql}
  GRANT %[1]s TO ${var.database.username};
  SQL

  drop_group_sql = <<-SQL
  ${local.revoke_all_sql}
  ${local.drop_role_sql}
  SQL

  add_group_sql = <<-SQL
  GRANT %[2]s TO %[1]s;
  SQL

  remove_group_sql = <<-SQL
  REVOKE %[2]s FROM %[1]s;
  SQL

  revoke_all_sql = <<-SQL
  DO $$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '%[1]s') THEN
      DROP OWNED BY %[1]s CASCADE;
    END IF;
  END
  $$;
  SQL

  grant_privileges_sql = {
    tables    = <<-SQL
    GRANT %[2]s ON ALL TABLES IN SCHEMA public TO %[1]s;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT %[2]s ON TABLES TO %[1]s;
    SQL
    sequences = <<-SQL
    GRANT %[2]s ON ALL SEQUENCES IN SCHEMA public TO %[1]s;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT %[2]s ON SEQUENCES TO %[1]s;
    SQL
    schemas   = <<-SQL
    GRANT %[2]s ON SCHEMA public TO %[1]s;
    SQL
  }

  default_privileges_sql = <<-SQL
  GRANT CONNECT,TEMP ON DATABASE %[2]s TO %[1]s;
  SQL
}

//*********************************************************
// CREATE GROUPS
//*********************************************************

moved {
  from = null_resource.group
  to = terraform_data.group
}

resource "terraform_data" "group" {
  for_each = var.groups

  input = {
    db_name     = var.database.db_name
    name        = each.key
    interpreter = local.psql
    env = local.psql_env
    password    = var.database.password
    create_sql  = local.create_group_sql
    destroy_sql = local.drop_group_sql
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = format(self.input.create_sql, self.input.name)
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = format(self.input.destroy_sql, self.input.name)
  }
}

//*********************************************************
// GROUP PERMISSIONS
//*********************************************************

moved {
  from = null_resource.group_privileges
  to = terraform_data.group_privileges
}

resource "terraform_data" "group_privileges" {
  for_each = var.groups

  input = {
    db_name     = var.database.db_name
    name        = each.key
    interpreter = local.psql
    env = local.psql_env
    password    = var.database.password
    create_sql = join("", concat(
      [
        format(local.revoke_all_sql, each.key),
        format(local.default_privileges_sql, each.key, var.database.db_name)
      ],
      [
        for priv_type, privs in each.value.privileges :
        format(local.grant_privileges_sql[priv_type], each.key, join(",", privs))
      ]
    ))
    destroy_sql = local.revoke_all_sql
  }

  triggers_replace = {
    privileges = each.value.privileges
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = self.input.create_sql
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = format(self.input.destroy_sql, self.input.name)
  }

  depends_on = [terraform_data.group]
  lifecycle {
    replace_triggered_by = [terraform_data.group]
  }
}

//*********************************************************
// CREATE USERS
//*********************************************************

resource "terraform_data" "user" {
  for_each = var.users

  input = {
    name        = each.key
    interpreter = local.psql
    env         = local.psql_env
    password    = var.database.password
    create_sql  = format(local.create_user_sql, each.key)
    destroy_sql = format(local.drop_user_sql, each.key)
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command     = self.input.create_sql
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command     = self.input.destroy_sql
  }

  depends_on = [terraform_data.group_privileges]
}

moved {
  from = null_resource.user
  to   = terraform_data.user
}

//*********************************************************
// USER GROUPS
//*********************************************************

moved {
  from = null_resource.user_group
  to = terraform_data.user_group
}

resource "terraform_data" "user_group" {
  for_each = merge(
    { for name, u in var.users : "${name}-${u.group}" => { user = name, group = u.group } },
    { for name, u in var.users : "${name}-iam" => { user = name, group = "rds_iam" } }
  )

  input = {
    db_name     = var.database.db_name
    name        = each.value.user
    group       = each.value.group
    interpreter = local.psql
    env = local.psql_env
    password    = var.database.password
    create_sql  = local.add_group_sql
    destroy_sql = local.remove_group_sql
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = format(self.input.create_sql, self.input.name, self.input.group)
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.input.interpreter)
    environment = self.input.env
    command = format(self.input.destroy_sql, self.input.name, self.input.group)
  }

  depends_on = [terraform_data.user]
  lifecycle {
    replace_triggered_by = [terraform_data.user, terraform_data.group]
  }
}

//*********************************************************
// IAM USER POLICIES
//*********************************************************

data "aws_iam_policy_document" "user_rds" {
  for_each = var.users
  statement {
    sid       = "rdsiam"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${var.database.id}/${each.key}"]
  }
}

resource "aws_iam_user_policy" "user_rds" {
  for_each = var.users
  name     = "${var.database.identifier}-db"
  user     = coalesce(each.value.iam_user, each.key)
  policy   = data.aws_iam_policy_document.user_rds[each.key].json
}
