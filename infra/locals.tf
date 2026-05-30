# =============================================================================
# Local Values
# =============================================================================

locals {
  # VPC configuration
  # Use provided VPC/subnets or created ones
  vpc_id             = var.vpc_id != null ? var.vpc_id : aws_vpc.main[0].id
  public_subnet_ids  = var.public_subnet_ids != null ? var.public_subnet_ids : aws_subnet.public[*].id
  private_subnet_ids = var.private_subnet_ids != null ? var.private_subnet_ids : aws_subnet.private[*].id

  # Determine if we need to create VPC resources
  create_vpc = var.vpc_id == null

  # Availability zones (use first 2 AZs in the region)
  # Exclude AZs that don't support ARM64 Fargate (e.g., use1-az3 in us-east-1).
  # When `ecs_cpu_architecture` is X86_64, no AZs are excluded.
  all_azs                  = data.aws_availability_zones.available.names
  az_ids                   = data.aws_availability_zones.available.zone_ids
  exclude_az_ids_effective = var.ecs_cpu_architecture == "ARM64" ? var.exclude_az_ids : []
  filtered_azs = [
    for i, az in local.all_azs : az
    if !contains(local.exclude_az_ids_effective, local.az_ids[i])
  ]
  azs = slice(local.filtered_azs, 0, min(2, length(local.filtered_azs)))
}

# =============================================================================
# Container Image URL の解決
# =============================================================================
# 変数で明示指定があればそちらを優先、なければ ECR の :latest タグを使用。
# :latest は GitHub Actions が ai-eval/ からビルドしてプッシュする。
locals {
  resolved_web_image        = coalesce(var.langfuse_web_image, "${aws_ecr_repository.web.repository_url}:latest")
  resolved_worker_image     = coalesce(var.langfuse_worker_image, "${aws_ecr_repository.worker.repository_url}:latest")
  resolved_clickhouse_image = coalesce(var.clickhouse_image, "${aws_ecr_repository.clickhouse.repository_url}:latest")
}

# =============================================================================
# SES / SMTP 設定
# =============================================================================
# SES is optional. If `ses_domain_name` or `ses_route53_zone_id` are omitted,
# reuse the application custom domain settings.
locals {
  ses_domain_name       = trimspace(var.ses_domain_name) != "" ? trimspace(var.ses_domain_name) : trimspace(var.custom_domain)
  ses_route53_zone_id   = trimspace(var.ses_route53_zone_id) != "" ? trimspace(var.ses_route53_zone_id) : trimspace(var.route53_zone_id)
  ses_email_from        = trimspace(var.ses_email_from_address) != "" ? trimspace(var.ses_email_from_address) : "noreply@${local.ses_domain_name}"
  ses_mail_from_domain  = trimspace(var.ses_mail_from_subdomain) != "" ? "${trimspace(var.ses_mail_from_subdomain)}.${local.ses_domain_name}" : null
  ses_smtp_host         = "email-smtp.${var.aws_region}.amazonaws.com"
  ses_smtp_port         = 587
  ses_smtp_endpoint_url = var.enable_ses && var.manage_ses_smtp_credentials ? "smtp://${aws_iam_access_key.ses_smtp[0].id}:${urlencode(aws_iam_access_key.ses_smtp[0].ses_smtp_password_v4)}@${local.ses_smtp_host}:${local.ses_smtp_port}" : null
  ses_smtp_secret_arn   = var.enable_ses ? (var.manage_ses_smtp_credentials ? aws_secretsmanager_secret.smtp_connection_url[0].arn : trimspace(var.smtp_connection_url_secret_arn)) : null
}
