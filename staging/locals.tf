locals {
  private_subnet_ids = sort(data.aws_subnets.private.ids)

  clickhouse_http_url      = "http://clickhouse.${var.production_service_name}.local:8123"
  clickhouse_migration_url = "clickhouse://clickhouse.${var.production_service_name}.local:9000"
  redis_connection_string  = "redis://${data.aws_elasticache_cluster.production.cache_nodes[0].address}:6379"

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
      value = "default"
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
      valueFrom = data.aws_secretsmanager_secret.production_clickhouse_password.arn
    },
  ]
}
