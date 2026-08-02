variable "aws_region" {
  description = "AWS region for the staging deployment."
  type        = string
  default     = "ap-northeast-1"
}

variable "service_name" {
  description = "Resource prefix for staging-only resources."
  type        = string
  default     = "langfuse-stg"
}

variable "production_service_name" {
  description = "Resource prefix of the production stack whose shared services are reused."
  type        = string
  default     = "langfuse"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy the staging services."
  type        = string
  default     = "moji-inc/ai-eval"
}

variable "domain_name" {
  description = "Public staging domain."
  type        = string
  default     = "stg.ai-eval.jp"
}

variable "route53_zone_name" {
  description = "Existing public Route53 hosted zone."
  type        = string
  default     = "ai-eval.jp."
}

variable "database_name" {
  description = "Logically isolated PostgreSQL database created inside the production RDS instance."
  type        = string
  default     = "langfuse_stg"
}

variable "database_user" {
  description = "PostgreSQL role owning the staging database."
  type        = string
  default     = "langfuse_stg"
}

variable "clickhouse_database" {
  description = "Logically isolated ClickHouse database."
  type        = string
  default     = "langfuse_stg"
}

variable "clickhouse_user" {
  description = "ClickHouse user restricted to the staging database."
  type        = string
  default     = "langfuse_stg"
}

variable "redis_key_prefix" {
  description = "Prefix for staging queues and cache keys in the dedicated Valkey node."
  type        = string
  default     = "staging"
}

variable "web_cpu" {
  description = "Fargate CPU units for the low-traffic staging web task."
  type        = number
  default     = 512
}

variable "web_memory" {
  description = "Fargate memory in MiB for the staging web task."
  type        = number
  default     = 1024
}

variable "worker_cpu" {
  description = "Fargate CPU units for the low-traffic staging worker task."
  type        = number
  default     = 512
}

variable "worker_memory" {
  description = "Fargate memory in MiB for the staging worker task."
  type        = number
  default     = 1024
}

variable "initial_desired_count" {
  description = "Keep services stopped until shared databases have been initialized."
  type        = number
  default     = 0
}

variable "allow_legacy_production_clickhouse_secret" {
  description = "Temporarily allow legacy staging task definitions to read the production ClickHouse admin secret during a two-phase migration."
  type        = bool
  default     = false
}
