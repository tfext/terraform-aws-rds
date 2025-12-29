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

variable "engine_version" {
  type        = string
  nullable    = true
  default     = null
  description = "Database engine version. Default is the latest supported version."
}

variable "engine_family" {
  type        = string
  nullable    = true
  default     = null
  description = "Database engine family. Default is the latest supported family."
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

variable "multi_az" {
  type        = bool
  default     = null
  description = "Force multi-AZ mode on or off (default is on for production, otherwise off)"
}

variable "mysql" {
  type = object({
    groups = map(object({ privileges = list(string) }))
    users  = map(object({ group = string, iam_user = optional(string) }))
  })
  nullable    = true
  default     = null
  description = "MySQL specific configuration"
}

variable "postgres" {
  type = object({
    groups = map(object({
      privileges = object({
        tables    = list(string),
        schemas   = optional(list(string))
        sequences = list(string)
      })
    }))
    users = map(object({ group = string, iam_user = optional(string) }))
  })
  nullable    = true
  default     = null
  description = "Postgresql specific configuration"
}
