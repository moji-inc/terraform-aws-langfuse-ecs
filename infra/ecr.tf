# =============================================================================
# ECR Repositories
# =============================================================================

resource "aws_ecr_repository" "web" {
  name                 = "${var.service_name}/web"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.service_name}-web-ecr"
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "${var.service_name}/worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.service_name}-worker-ecr"
  }
}

resource "aws_ecr_repository" "clickhouse" {
  name                 = "${var.service_name}/clickhouse"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.service_name}-clickhouse-ecr"
  }
}

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
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

resource "aws_ecr_lifecycle_policy" "clickhouse" {
  repository = aws_ecr_repository.clickhouse.name
  policy     = local.ecr_lifecycle_policy
}
