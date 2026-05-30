variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "service_name" {
  description = "Resource naming prefix and service tag"
  type        = string
  default     = "langfuse"
}

variable "user" {
  description = "User tag for resource identification"
  type        = string
}

# VPC Configuration
# If vpc_id is null, a new VPC will be created automatically
variable "vpc_id" {
  description = "Existing VPC ID. If null, a new VPC will be created."
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "Public Subnet IDs for Langfuse Web. Required if vpc_id is provided."
  type        = list(string)
  default     = null
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs for Worker/ClickHouse/RDS/ElastiCache. Required if vpc_id is provided."
  type        = list(string)
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for new VPC (used only when vpc_id is null)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Add a NAT Gateway so private subnets can reach the internet (e.g., for LLM-as-a-Judge calling external OpenAI/Anthropic APIs). Only applies when this module creates the VPC."
  type        = bool
  default     = false
}

variable "exclude_az_ids" {
  description = "AZ IDs to exclude (used only when ecs_cpu_architecture is ARM64)"
  type        = list(string)
  default     = ["use1-az3"]
}

variable "ecs_cpu_architecture" {
  description = "ECS Fargate task CPU architecture for runtime_platform.cpu_architecture (X86_64 or ARM64)."
  type        = string
  default     = "X86_64"

  # Note: This repo currently builds/pushes Langfuse images as a single `linux/amd64` image.
  # If you set `ARM64`, you must also update the build/push logic to generate ARM64 images.
}

variable "allowed_cidrs" {
  description = "Allowed CIDR list for external access"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to access ALB (for internal AWS services tracing)"
  type        = list(string)
  default     = []
}

# RDS
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "langfuse"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# ElastiCache
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

# ECS - Web
variable "web_cpu" {
  description = "Web task CPU (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "web_memory" {
  description = "Web task memory in MB"
  type        = number
  default     = 2048
}

# ECS - Worker
variable "worker_desired_count" {
  description = "Langfuse Worker task count"
  type        = number
  default     = 1
}

variable "worker_cpu" {
  description = "Worker task CPU (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "worker_memory" {
  description = "Worker task memory in MB"
  type        = number
  default     = 2048
}

# ECS - ClickHouse
variable "clickhouse_cpu" {
  description = "ClickHouse task CPU (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "clickhouse_memory" {
  description = "ClickHouse task memory in MB"
  type        = number
  default     = 4096
}

# Container Images (ECR)
# 省略可能。省略した場合は infra/ecr.tf で作成した ECR リポジトリの :latest タグを使用。
# 初回は GitHub Actions の workflow_dispatch で ai-eval/ からビルドしてプッシュすること。
# 上書きしたい場合のみ明示的に指定する。
variable "langfuse_web_image" {
  description = "Langfuse Web コンテナイメージ (ECR URL)。null の場合は ECR の :latest を使用。"
  type        = string
  default     = null
  nullable    = true
}

variable "langfuse_worker_image" {
  description = "Langfuse Worker コンテナイメージ (ECR URL)。null の場合は ECR の :latest を使用。"
  type        = string
  default     = null
  nullable    = true
}

variable "clickhouse_image" {
  description = "ClickHouse コンテナイメージ (ECR URL)。null の場合は ECR の :latest を使用。"
  type        = string
  default     = null
  nullable    = true
}

# GitHub Actions OIDC 認証設定
variable "github_repo" {
  description = "GitHub リポジトリ名（例: org/repo）。GitHub Actions OIDC 認証に使用。"
  type        = string
}

variable "nextauth_url" {
  description = "Langfuse Web public URL (e.g., https://langfuse.example.com)"
  type        = string
  default     = ""
}

# ALB Configuration
variable "enable_alb" {
  description = "Enable ALB (recommended for production)"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. If empty, a self-signed certificate is used."
  type        = string
  default     = ""
}

# Custom Domain Configuration (optional)
variable "custom_domain" {
  description = "Custom domain for Langfuse (e.g., langfuse.example.com). Requires Route53 hosted zone."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for custom domain. Required when custom_domain is set."
  type        = string
  default     = ""
}

# Slack integration (multi-tenant). Values come from the Slack App's Basic
# Information page after creating the App from the manifest. Pass at apply
# time via `TF_VAR_slack_client_id=...` / `TF_VAR_slack_client_secret=...` so
# the values never land in tfvars files. The state secret is generated locally
# (see secrets.tf); Slack has no equivalent input for it.
variable "slack_client_id" {
  description = "Slack App Client ID (from https://api.slack.com/apps → Basic Information)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_client_secret" {
  description = "Slack App Client Secret (from https://api.slack.com/apps → Basic Information)."
  type        = string
  sensitive   = true
  default     = ""
}

# SES / Email Invitation Configuration
variable "enable_ses" {
  description = "Enable Amazon SES SMTP for Langfuse email invitations and password reset emails."
  type        = bool
  default     = false
}

variable "ses_domain_name" {
  description = "Domain name to verify in SES. Defaults to custom_domain when empty."
  type        = string
  default     = ""
}

variable "ses_route53_zone_id" {
  description = "Route53 hosted zone ID for SES DNS records. Defaults to route53_zone_id when empty."
  type        = string
  default     = ""
}

variable "ses_email_from_address" {
  description = "Email address used as EMAIL_FROM_ADDRESS. Defaults to noreply@ses_domain_name."
  type        = string
  default     = ""

  validation {
    condition     = var.ses_email_from_address == "" || can(regex("^[^\\s@<>]+@[^\\s@<>]+\\.[^\\s@<>]+$", var.ses_email_from_address))
    error_message = "ses_email_from_address must be a bare email address without a display name."
  }
}

variable "ses_mail_from_subdomain" {
  description = "Subdomain for custom SES MAIL FROM domain. Empty disables custom MAIL FROM."
  type        = string
  default     = "mail"
}

variable "ses_create_spf_record" {
  description = "Whether to create an SPF TXT record for SES at ses_domain_name."
  type        = bool
  default     = false
}

variable "ses_create_dmarc_record" {
  description = "Whether to create a DMARC TXT record at _dmarc.ses_domain_name."
  type        = bool
  default     = false
}

variable "ses_dmarc_policy" {
  description = "DMARC TXT record value when ses_create_dmarc_record is true."
  type        = string
  default     = "v=DMARC1; p=none;"
}

variable "ses_dkim_domain_suffix" {
  description = "DKIM target suffix for SES DKIM records."
  type        = string
  default     = "dkim.amazonses.com"
}

variable "create_ses_smtp_vpc_endpoint" {
  description = "Create an Interface VPC Endpoint for SES SMTP access from private ECS tasks."
  type        = bool
  default     = true
}

variable "ses_smtp_vpc_endpoint_subnet_ids" {
  description = "Subnet IDs for the SES SMTP VPC Endpoint. Defaults to private_subnet_ids."
  type        = list(string)
  default     = null
}

variable "manage_ses_smtp_credentials" {
  description = "Create and manage SES SMTP access key and SMTP_CONNECTION_URL secret value. Leave false to keep an existing manually-created credential value."
  type        = bool
  default     = false
}

variable "smtp_connection_url_secret_arn" {
  description = "Existing Secrets Manager ARN containing SMTP_CONNECTION_URL when manage_ses_smtp_credentials is false."
  type        = string
  default     = ""
}
