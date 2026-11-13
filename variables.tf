variable "name" {
  type        = string
  description = "Name of the database instance"
}

variable "db_name" {
  type        = string
  default     = null
  description = "Internal database name. Default is the same as the name variable."
}

variable "instance_type" {
  type        = string
  default     = "db.t3.small"
  description = "Database instance type"
}

variable "storage_size" {
  type        = number
  default     = 30
  description = "Storage space in GB"
}

variable "engine" {
  type        = string
  description = "Database engine (mysql, mariadb or postgres)"
  validation {
    condition     = contains(["mysql", "mariadb", "postgres"], var.engine)
    error_message = "Invalid database engine"
  }
}

variable "allowed_security_groups" {
  type        = list(string)
  default     = []
  description = "List of security groups that should be allowed to talk to the DB"
}

variable "iam" {
  type        = bool
  default     = true
  description = "Use IAM for user authentication"
}

variable "public" {
  type        = bool
  default     = false
  description = "Deploy the database in public subnets"
}

variable "groups" {
  type        = map(object({ privileges = list(string) }))
  default     = {}
  nullable    = false
  description = "Groups to create for managing users"
}

variable "users" {
  type        = map(object({ group = string, iam_user = optional(string) }))
  default     = {}
  nullable    = false
  description = "Users to provision (IAM only for now)"
}

variable "engine_version" {
  type        = string
  default     = null
  description = "Engine version. Default is the engine's pinned version (PostgreSQL 18.6)."
}

variable "engine_family" {
  type        = string
  default     = null
  description = "Parameter group family. Default is derived: for PostgreSQL from the major version of engine_version (18 and 18.1 both give postgres18), otherwise the engine's own family."
}

variable "multi_az" {
  type        = bool
  default     = null
  description = "Deploy a standby in a second AZ. Default is on in production, off otherwise."
}

variable "backup_retention_days" {
  type        = number
  default     = null
  description = "Days to keep automated backups. Default is 7 in production, 2 otherwise."
}

variable "storage_type" {
  type        = string
  default     = "gp2"
  description = "Storage type (gp2, gp3, io1, io2)"
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "KMS key ARN. When set, storage is encrypted with this key."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Prevent the instance from being deleted"
}

variable "final_snapshot" {
  type        = bool
  default     = false
  description = "Take a final snapshot named <name>-final when the instance is deleted"
}

variable "parameters" {
  type        = map(object({ value = string, immediate = optional(bool) }))
  default     = {}
  nullable    = false
  description = "Parameters merged over the engine's default parameters. immediate = false applies the parameter at the next reboot."
}

variable "manage_master_password" {
  type        = bool
  default     = false
  description = "Let RDS keep the root password in Secrets Manager instead of generating one in Terraform"
}

variable "log_exports" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Log types to export to CloudWatch (e.g. postgresql, upgrade)"
}
