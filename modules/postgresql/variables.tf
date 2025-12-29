variable "database" {
  type = object({
    id         = string
    identifier = string
    address    = string
    port       = number
    username   = string
    db_name    = string
    password   = string
  })
  nullable = false
}

variable "groups" {
  type = map(object({
    privileges = object({
      tables    = list(string),
      schemas   = optional(list(string))
      sequences = list(string)
    })
  }))
  nullable    = false
  description = "Groups to create for managing users"
}

variable "users" {
  type        = map(object({ group = string, iam_user = optional(string) }))
  nullable    = false
  description = "Users to provision (IAM only for now)"
}
