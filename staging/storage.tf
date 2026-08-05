resource "aws_s3_bucket" "staging" {
  bucket_prefix = "${var.service_name}-"
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "expire-staging-data"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_elasticache_subnet_group" "staging" {
  name       = "${var.service_name}-cache"
  subnet_ids = local.private_subnet_ids
}

resource "aws_elasticache_replication_group" "staging" {
  replication_group_id = "${var.service_name}-redis"
  description          = "Low-cost staging-only Valkey cache"

  engine         = "valkey"
  engine_version = "8.0"
  node_type      = "cache.t4g.micro"
  port           = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  apply_immediately          = true
  snapshot_retention_limit   = 0

  subnet_group_name  = aws_elasticache_subnet_group.staging.name
  security_group_ids = [aws_security_group.redis.id]
}

resource "aws_ecr_repository" "web" {
  name                 = "${var.service_name}/web"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "${var.service_name}/worker"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the five newest staging images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "web" {
  repository = aws_ecr_repository.web.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.service_name}/web"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.service_name}/worker"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "init" {
  name              = "/ecs/${var.service_name}/init"
  retention_in_days = 7
}
