locals {
  mysql = join(" ", [
    "/bin/mysql",
    "-h", var.database.address,
    "-P", var.database.port,
    "-u", var.database.username,
    "--password=${nonsensitive(var.database.password)}",
    var.database.db_name,
    "-e"
  ])
}

resource "null_resource" "user" {
  for_each = var.users

  triggers = {
    name        = each.key
    interpreter = local.mysql
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.triggers.interpreter)
    command     = <<-SQL
    CREATE USER IF NOT EXISTS ${self.triggers.name} IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
    ALTER USER '${self.triggers.name}'@'%' REQUIRE SSL;
    SQL
  }
  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.triggers.interpreter)
    command     = "DROP USER IF EXISTS ${self.triggers.name}"
  }
}

resource "null_resource" "user_role" {
  for_each = var.users

  triggers = {
    db_name     = var.database.db_name
    name        = each.key
    interpreter = local.mysql
    privileges  = join(",", sort(var.groups[each.value.group].privileges))
  }

  provisioner "local-exec" {
    interpreter = split(" ", self.triggers.interpreter)
    command     = <<-SQL
    REVOKE ALL PRIVILEGES, GRANT OPTION FROM ${self.triggers.name};
    GRANT ${self.triggers.privileges} ON ${self.triggers.db_name}.* TO ${self.triggers.name};
    SQL
  }
  provisioner "local-exec" {
    when        = destroy
    interpreter = split(" ", self.triggers.interpreter)
    command     = "REVOKE ALL ON ${self.triggers.db_name}.* FROM TO ${self.triggers.name}"
  }

  depends_on = [null_resource.user]
}

data "aws_iam_policy_document" "user_rds" {
  for_each = var.users
  statement {
    sid       = "rdsiam"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.aws.region}:${var.aws.account}:dbuser:${var.database.id}/${each.key}"]
  }
}

resource "aws_iam_user_policy" "user_rds" {
  for_each = var.users
  name     = "${var.database.identifier}-db"
  user     = coalesce(each.value.iam_user, each.key)
  policy   = data.aws_iam_policy_document.user_rds[each.key].json
}
