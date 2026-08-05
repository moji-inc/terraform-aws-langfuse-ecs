# =============================================================================
# GitHub Actions OIDC 認証
# =============================================================================

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.service_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:production"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.service_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR ログイン
      {
        Sid      = "EcrAuthentication"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # ECR イメージプッシュ（web / worker / clickhouse）
      {
        Sid    = "ProductionEcrRepositories"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.web.arn,
          aws_ecr_repository.worker.arn,
          aws_ecr_repository.clickhouse.arn,
        ]
      },
      # ECS タスク定義の登録
      {
        Sid    = "TaskDefinitionManagement"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource",
        ]
        Resource = "*"
      },
      # 本番 ECS サービスのデプロイ
      {
        Sid    = "ProductionServiceDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.langfuse.cluster_name}/${module.langfuse.web_service_name}",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.langfuse.cluster_name}/${module.langfuse.worker_service_name}",
        ]
      },
      # ECS ロールの PassRole（タスク定義登録時に execution_role と task_role の両方が必要）
      {
        Sid    = "PassProductionTaskRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn,
        ]
      }
    ]
  })
}

# =============================================================================
# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.service_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.service_name}-secrets-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          [
            aws_secretsmanager_secret.database_url.arn,
            aws_secretsmanager_secret.nextauth_secret.arn,
            aws_secretsmanager_secret.salt.arn,
            aws_secretsmanager_secret.encryption_key.arn,
            aws_secretsmanager_secret.clickhouse_password.arn,
            aws_secretsmanager_secret.slack_client_id.arn,
            aws_secretsmanager_secret.slack_client_secret.arn,
            aws_secretsmanager_secret.slack_state_secret.arn
          ],
          var.enable_ses && local.ses_smtp_secret_arn != null && local.ses_smtp_secret_arn != "" ? [
            local.ses_smtp_secret_arn
          ] : []
        )
      }
    ]
  })
}

# ECS Task Role (for application access to AWS services)
resource "aws_iam_role" "ecs_task" {
  name = "${var.service_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
