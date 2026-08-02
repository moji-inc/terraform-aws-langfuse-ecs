resource "aws_ecs_cluster" "staging" {
  name = var.service_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.service_name}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.web_cpu
  memory                   = var.web_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "langfuse-web"
    image     = "${data.aws_ecr_repository.production_web.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]

    environment = concat(local.common_environment, [{
      name  = "NEXTAUTH_URL"
      value = "https://${var.domain_name}"
    }])

    secrets = local.common_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "web"
      }
    }
  }])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.service_name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "langfuse-worker"
    image     = "${data.aws_ecr_repository.production_worker.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3030
      hostPort      = 3030
      protocol      = "tcp"
    }]

    environment = local.common_environment
    secrets     = local.common_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "web" {
  name            = "${var.service_name}-web"
  cluster         = aws_ecs_cluster.staging.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.initial_desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [data.aws_security_group.web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "langfuse-web"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "worker" {
  name            = "${var.service_name}-worker"
  cluster         = aws_ecs_cluster.staging.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.initial_desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [data.aws_security_group.worker.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
