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
