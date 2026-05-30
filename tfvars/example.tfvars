# tfvars template.
# Copy this file to tfvars/prod.tfvars and edit values before applying.
# The real tfvars/prod.tfvars file is ignored by git.

# AWS Configuration
aws_region   = "ap-northeast-1"
service_name = "langfuse"

# Resource Tags (for easy identification)
user = "your-name"

# GitHub Actions OIDC 認証（必須）
github_repo = "moji-inc/ai-eval"

# コンテナイメージ（省略可能）
# 省略した場合は ECR の :latest タグを使用（GitHub Actions が ai-eval/ からビルドしてプッシュ）
# 特定バージョンに固定したい場合のみコメントを外して設定する
# 本番でTerraform applyする場合は、意図しないECS再デプロイを避けるため現在稼働中のタグに固定することを推奨
# langfuse_web_image    = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/langfuse/web:abc123"
# langfuse_worker_image = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/langfuse/worker:abc123"
# clickhouse_image      = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/langfuse/clickhouse:24"

# Network Configuration
# Current deployment shape: auto-create VPC.
vpc_cidr = "10.0.0.0/16"

# Optional NAT Gateway for private subnet outbound internet access.
# Required when Langfuse Worker needs to call external LLM APIs.
# Only applies when this module creates the VPC.
# enable_nat_gateway = true

# To use an existing VPC instead, uncomment and set values below.
# vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
# public_subnet_ids  = ["subnet-xxxxxxxxxxxxxxxxx"]
# private_subnet_ids = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]

# Access Control
# Restrict this to office/VPN CIDRs if the ALB should not be public.
allowed_cidrs = ["203.0.113.0/24"]

# RDS Configuration
db_instance_class = "db.t4g.micro"
db_name           = "langfuse"
db_multi_az       = false

# ElastiCache Configuration
cache_node_type = "cache.t4g.micro"

# ECS CPU Architecture for Fargate tasks
# - This repo currently builds/pushes Langfuse images as `linux/amd64` only.
ecs_cpu_architecture = "X86_64"

# ECS - Web Configuration
web_cpu    = 1024 # 1 vCPU
web_memory = 2048 # 2 GB

# ECS - Worker Configuration
worker_desired_count = 1
worker_cpu           = 1024 # 1 vCPU
worker_memory        = 2048 # 2 GB

# ECS - ClickHouse Configuration
clickhouse_cpu    = 2048 # 2 vCPU
clickhouse_memory = 4096 # 4 GB

# Langfuse Configuration
# NEXTAUTH_URL is required for authentication to work properly.
# nextauth_url = "https://langfuse.example.com"

# ALB Configuration (enabled by default)
# - Without certificate_arn: HTTPS with self-signed certificate (browser warning)
# - With certificate_arn: HTTPS with ACM certificate
enable_alb = true
# certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Custom Domain
# custom_domain   = "langfuse.example.com"
# route53_zone_id = "ZXXXXXXXXXXXX"

# SES / Email Invitations
# Keep ses_email_from_address as a bare email address. The app sets the display
# name separately, so recipients see `ai-eval <noreply@ai-eval.jp>`.
# enable_ses              = true
# ses_domain_name         = "ai-eval.jp"
# ses_route53_zone_id     = "ZXXXXXXXXXXXX"
# ses_email_from_address  = "noreply@ai-eval.jp"
# ses_mail_from_subdomain = "mail"
# ses_create_dmarc_record = true
#
# Existing production SMTP credentials can stay in Secrets Manager without
# Terraform managing the secret value. Set this true only when you want
# Terraform to create/rotate the SES SMTP access key and secret value.
# manage_ses_smtp_credentials = false
#
# manage_ses_smtp_credentials=false の場合は、既存のSecret ARNを指定する
# smtp_connection_url_secret_arn = "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:langfuse/smtp-connection-url-xxxxxx"
