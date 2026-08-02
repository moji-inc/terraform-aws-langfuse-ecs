data "aws_vpc" "production" {
  filter {
    name   = "tag:Name"
    values = ["${var.production_service_name}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.production.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.production_service_name}-private-*"]
  }
}

data "aws_security_group" "alb" {
  name   = "${var.production_service_name}-alb"
  vpc_id = data.aws_vpc.production.id
}

data "aws_security_group" "rds" {
  name   = "${var.production_service_name}-rds"
  vpc_id = data.aws_vpc.production.id
}

data "aws_security_group" "clickhouse" {
  name   = "${var.production_service_name}-clickhouse"
  vpc_id = data.aws_vpc.production.id
}

data "aws_lb" "production" {
  name = "${var.production_service_name}-alb"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.production.arn
  port              = 443
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.production.arn
  port              = 80
}

data "aws_route53_zone" "production" {
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_db_instance" "production" {
  db_instance_identifier = "${var.production_service_name}-postgres"
}

data "aws_secretsmanager_secret" "production_database_url" {
  name = "${var.production_service_name}/database-url"
}

data "aws_secretsmanager_secret" "production_clickhouse_password" {
  name = "${var.production_service_name}/clickhouse-password"
}

data "aws_ecr_repository" "production_web" {
  name = "${var.production_service_name}/web"
}

data "aws_ecr_repository" "production_worker" {
  name = "${var.production_service_name}/worker"
}

data "aws_ecr_repository" "production_clickhouse" {
  name = "${var.production_service_name}/clickhouse"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
