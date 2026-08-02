data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.service_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "task_execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.app.arn,
      data.aws_secretsmanager_secret.production_clickhouse_password.arn,
    ]
  }
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name   = "${var.service_name}-secrets-access"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_secrets.json
}

resource "aws_iam_role" "task" {
  name               = "${var.service_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

data "aws_iam_policy_document" "task_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.staging.arn,
      "${aws_s3_bucket.staging.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name   = "${var.service_name}-s3-access"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_s3.json
}

resource "aws_iam_role" "init_execution" {
  name               = "${var.service_name}-init-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "init_execution" {
  role       = aws_iam_role.init_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "init_execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.app.arn,
      data.aws_secretsmanager_secret.production_database_url.arn,
      data.aws_secretsmanager_secret.production_clickhouse_password.arn,
    ]
  }
}

resource "aws_iam_role_policy" "init_execution_secrets" {
  name   = "${var.service_name}-init-secrets-access"
  role   = aws_iam_role.init_execution.id
  policy = data.aws_iam_policy_document.init_execution_secrets.json
}

resource "aws_iam_role" "init_task" {
  name               = "${var.service_name}-init-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:staging"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.service_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      aws_ecr_repository.web.arn,
      aws_ecr_repository.worker.arn,
    ]
  }

  statement {
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = ["*"]
  }

  statement {
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.task_execution.arn,
      aws_iam_role.task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.service_name}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
