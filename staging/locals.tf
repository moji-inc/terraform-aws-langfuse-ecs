locals {
  private_subnet_ids = sort(data.aws_subnets.private.ids)

  clickhouse_http_url      = "http://clickhouse.${var.production_service_name}.local:8123"
  clickhouse_migration_url = "clickhouse://clickhouse.${var.production_service_name}.local:9000"
  redis_connection_string  = "rediss://${aws_elasticache_replication_group.staging.primary_endpoint_address}:${aws_elasticache_replication_group.staging.port}"

  common_environment = [
    {
      name  = "CLICKHOUSE_URL"
      value = local.clickhouse_http_url
    },
    {
      name  = "CLICKHOUSE_MIGRATION_URL"
      value = local.clickhouse_migration_url
    },
    {
      name  = "CLICKHOUSE_DB"
      value = var.clickhouse_database
    },
    {
      name  = "CLICKHOUSE_USER"
      value = var.clickhouse_user
    },
    {
      name  = "CLICKHOUSE_CLUSTER_ENABLED"
      value = "false"
    },
    {
      name  = "REDIS_CONNECTION_STRING"
      value = local.redis_connection_string
    },
    {
      name  = "REDIS_KEY_PREFIX"
      value = var.redis_key_prefix
    },
    {
      name  = "LANGFUSE_S3_EVENT_UPLOAD_BUCKET"
      value = aws_s3_bucket.staging.id
    },
    {
      name  = "LANGFUSE_S3_EVENT_UPLOAD_REGION"
      value = var.aws_region
    },
    {
      name  = "HOSTNAME"
      value = "0.0.0.0"
    },
  ]

  common_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:DATABASE_URL::"
    },
    {
      name      = "DIRECT_URL"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:DATABASE_URL::"
    },
    {
      name      = "NEXTAUTH_SECRET"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:NEXTAUTH_SECRET::"
    },
    {
      name      = "SALT"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:SALT::"
    },
    {
      name      = "ENCRYPTION_KEY"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:ENCRYPTION_KEY::"
    },
    {
      name      = "CLICKHOUSE_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:CLICKHOUSE_PASSWORD::"
    },
  ]
}
