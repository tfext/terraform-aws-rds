terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

module "base" {
  source = "github.com/tfext/terraform-aws-base"
}

module "tagging" {
  source = "github.com/tfext/terraform-utilities-tagging"
}

module "vpc" {
  source = "github.com/tfext/terraform-aws-vpc-data"
}

locals {
  # Add other engines if needed
  supported_engines = {
    postgres = {
      name    = "postgres"
      version = "18"
      family  = "postgres18"
      port    = 5432

      parameters = {
        log_min_duration_statement      = { value = "10" }
        log_statement                   = { value = "none" }
        max_connections                 = { value = "1000", immediate = false }
        "auto_explain.log_min_duration" = { value = "200" }
        log_disconnections              = { value = "1" }
        log_checkpoints                 = { value = "0" }
      }
    }
    mariadb = {
      name    = "mariadb"
      version = "11.8"
      family  = "mariadb11.8"
      port    = 3306
      style   = "mysql"

      parameters = {
        log_slow_query      = { value = "1" }
        log_slow_query_time = { value = "2" }
        log_slow_verbosity  = { value = "explain" }
      }
    }
    mysql = {
      name    = "mysql"
      version = "8.4"
      family  = "mysql8.4"
      port    = 3306
      style   = "mysql"

      parameters = {
        log_slow_query      = { value = "1" }
        log_slow_query_time = { value = "2" }
        log_slow_verbosity  = { value = "explain" }
      }
    }
  }

  engine = local.supported_engines[var.engine]
  engine_version = coalesce(var.engine_version, local.engine.version)
  engine_family = coalesce(var.engine_family, format("%[1]%[2]", local.engine.name, local.engine_version))
}
