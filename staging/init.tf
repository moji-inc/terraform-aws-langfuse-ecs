resource "aws_ecs_task_definition" "postgres_init" {
  family                   = "${var.service_name}-postgres-init"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.init_execution.arn
  task_role_arn            = aws_iam_role.init_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "postgres-init"
    image     = "public.ecr.aws/docker/library/postgres:17-alpine"
    essential = true

    entryPoint = ["/bin/sh", "-ec"]
    command = [<<-SCRIPT
      psql "$ADMIN_DATABASE_URL" --set=ON_ERROR_STOP=1 --set=staging_password="$STAGING_DATABASE_PASSWORD" <<'SQL'
      SELECT format('CREATE ROLE ${var.database_user} LOGIN PASSWORD %L', :'staging_password')
      WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${var.database_user}')
      \gexec
      SELECT format('ALTER ROLE ${var.database_user} WITH LOGIN PASSWORD %L', :'staging_password')
      \gexec
      SELECT 'CREATE DATABASE ${var.database_name} OWNER ${var.database_user}'
      WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${var.database_name}')
      \gexec
      SQL
    SCRIPT
    ]

    secrets = [
      {
        name      = "ADMIN_DATABASE_URL"
        valueFrom = data.aws_secretsmanager_secret.production_database_url.arn
      },
      {
        name      = "STAGING_DATABASE_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.app.arn}:DATABASE_PASSWORD::"
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.init.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "postgres"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "clickhouse_init" {
  family                   = "${var.service_name}-clickhouse-init"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.init_execution.arn
  task_role_arn            = aws_iam_role.init_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "clickhouse-init"
    image     = "${data.aws_ecr_repository.production_clickhouse.repository_url}:latest"
    essential = true

    entryPoint = ["/bin/sh", "-ec"]
    command = [<<-SCRIPT
      clickhouse-client \
        --host clickhouse.${var.production_service_name}.local \
        --user default \
        --password "$ADMIN_CLICKHOUSE_PASSWORD" \
        --multiquery <<SQL
      CREATE DATABASE IF NOT EXISTS ${var.clickhouse_database};
      CREATE USER IF NOT EXISTS ${var.clickhouse_user} IDENTIFIED WITH sha256_password BY '$STAGING_CLICKHOUSE_PASSWORD';
      ALTER USER ${var.clickhouse_user} IDENTIFIED WITH sha256_password BY '$STAGING_CLICKHOUSE_PASSWORD';
      GRANT ALL ON ${var.clickhouse_database}.* TO ${var.clickhouse_user};
      SQL

      clickhouse-client \
        --host clickhouse.${var.production_service_name}.local \
        --user ${var.clickhouse_user} \
        --password "$STAGING_CLICKHOUSE_PASSWORD" \
        --database ${var.clickhouse_database} \
        --query "SELECT 1"
    SCRIPT
    ]

    secrets = [
      {
        name      = "ADMIN_CLICKHOUSE_PASSWORD"
        valueFrom = data.aws_secretsmanager_secret.production_clickhouse_password.arn
      },
      {
        name      = "STAGING_CLICKHOUSE_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.app.arn}:CLICKHOUSE_PASSWORD::"
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.init.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "clickhouse"
      }
    }
  }])
}
