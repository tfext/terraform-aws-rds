# terraform-aws-rds

Creates an RDS database instance (PostgreSQL or MariaDB) with its parameter
group, subnet group and security group. For MariaDB it can also provision IAM
database users (`groups`, `users`). PostgreSQL roles are managed by
[`terraform-aws-rds-postgres-role`](https://github.com/tfext/terraform-aws-rds-postgres-role).

```hcl
module "db" {
  source                  = "github.com/tfext/terraform-aws-rds?ref=<tag>"
  name                    = "my-db"
  engine                  = "postgres"
  engine_version          = "18"
  storage_type            = "gp3"
  manage_master_password  = true
  allowed_security_groups = [var.hosts_security_group_id]

  parameters = {
    log_min_duration_statement = { value = "500" }
    shared_preload_libraries   = { value = "pg_stat_statements", immediate = false }
  }
}
```

Parameter group
---------------

A new parameter group is named `<name>-<YYYYMMDDhhmm>`, from the time of the
plan that creates it, and is created before the group it replaces is deleted.
So a change that replaces it, such as a new `engine_family` on a major version
upgrade, works in one apply: the instance moves to the new group, then the old
one goes. The instance needs a reboot to load the new group's static settings.

The group's name and description are ignored after it's created. RDS can't
change either in place, so a change would replace the group. Groups created
before the date suffix keep their names and descriptions. Resource
descriptions are the fixed text `Managed by terraform`; the `managed_by` tag
names the unit.

Inputs
------

### Instance

| Name                     | Type           | Default         | Description                                                                                                                  |
|--------------------------|----------------|-----------------|------------------------------------------------------------------------------------------------------------------------------|
| `name`                   | `string`       | -               | Name of the database instance                                                                                                |
| `db_name`                | `string`       | `null`          | Internal database name. Default is the same as `name`                                                                        |
| `engine`                 | `string`       | -               | Database engine (`mariadb` or `postgres`)                                                                                    |
| `engine_version`         | `string`       | `null`          | Engine version. Default is the engine's pinned version (PostgreSQL `18.6`, MariaDB `10.11`)                                  |
| `engine_family`          | `string`       | `null`          | Parameter group family. Default is derived: for PostgreSQL from the major version of `engine_version` (`18` and `18.1` both give `postgres18`), otherwise the engine's own family |
| `instance_type`          | `string`       | `"db.t3.small"` | Database instance type                                                                                                       |
| `multi_az`               | `bool`         | `null`          | Deploy a standby in a second AZ. Default is on in production, off otherwise                                                  |
| `parameters`             | `map(object)`  | `{}`            | Parameters merged over the engine's default parameters, overriding any of the same name. Each is `{ value = string, immediate = optional(bool) }`; `immediate = false` applies it at the next reboot |

### Storage and backups

| Name                    | Type     | Default | Description                                                                                       |
|-------------------------|----------|---------|---------------------------------------------------------------------------------------------------|
| `storage_size`          | `number` | `30`    | Storage space in GB                                                                               |
| `storage_type`          | `string` | `"gp2"` | Storage type (`gp2`, `gp3`, `io1`, `io2`)                                                         |
| `kms_key_id`            | `string` | `null`  | KMS key ARN. When set, storage is encrypted with this key                                         |
| `backup_retention_days` | `number` | `null`  | Days to keep automated backups. Default is 7 in production, 2 otherwise                           |
| `deletion_protection`   | `bool`   | `false` | Prevent the instance from being deleted                                                           |
| `final_snapshot`        | `bool`   | `false` | Take a final snapshot named `<name>-final` when the instance is deleted                           |
| `log_exports`           | `list(string)` | `[]` | Log types to export to CloudWatch (e.g. `postgresql`, `upgrade`)                                  |

### Access

| Name                      | Type           | Default | Description                                                                                         |
|---------------------------|----------------|---------|-----------------------------------------------------------------------------------------------------|
| `allowed_security_groups` | `list(string)` | `[]`    | Security groups allowed to reach the database port                                                  |
| `public`                  | `bool`         | `false` | Deploy the database in public subnets and allow access from anywhere                                |
| `iam`                     | `bool`         | `true`  | Enable IAM database authentication                                                                  |
| `manage_master_password`  | `bool`         | `false` | Let RDS keep the root password in Secrets Manager (`master_user_secret_arn`) instead of generating one in Terraform |
| `groups`                  | `map(object)`  | `{}`    | MariaDB only. Groups of privileges for `users`: `{ privileges = list(string) }`                     |
| `users`                   | `map(object)`  | `{}`    | MariaDB only. IAM users to provision: `{ group = string, iam_user = optional(string) }`             |

Outputs
-------

| Name                     | Description                                                                                 |
|--------------------------|---------------------------------------------------------------------------------------------|
| `id`                     | Instance ID                                                                                 |
| `resource_id`            | Instance resource ID, used in `rds-db:connect` IAM policies                                 |
| `name`                   | Database name                                                                               |
| `host`                   | Instance host name                                                                          |
| `port`                   | Database port                                                                               |
| `root`                   | Sensitive. `{ user, password }` for the root user. `password` is `null` when `manage_master_password` is `true` |
| `master_user_secret_arn` | ARN of the Secrets Manager secret holding the root password, when `manage_master_password` is `true` |
| `security_group`         | `{ id, arn }` of the instance's security group                                              |
