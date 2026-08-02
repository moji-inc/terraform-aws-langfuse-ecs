resource "aws_security_group" "web" {
  name        = "${var.service_name}-web"
  description = "Staging web tasks with restricted data-service egress"
  vpc_id      = data.aws_vpc.production.id
}

resource "aws_security_group" "worker" {
  name        = "${var.service_name}-worker"
  description = "Staging worker tasks with restricted data-service egress"
  vpc_id      = data.aws_vpc.production.id
}

resource "aws_security_group" "redis" {
  name        = "${var.service_name}-redis"
  description = "Staging-only Valkey serverless cache"
  vpc_id      = data.aws_vpc.production.id
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = data.aws_security_group.alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "HTTPS listener traffic from the shared ALB"
}

resource "aws_vpc_security_group_ingress_rule" "worker_from_web" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 3030
  to_port                      = 3030
  ip_protocol                  = "tcp"
  description                  = "Worker health checks from staging web"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_staging" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = data.aws_security_group.rds.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from staging ${each.key}"
}

resource "aws_vpc_security_group_ingress_rule" "clickhouse_http_from_staging" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = data.aws_security_group.clickhouse.id
  referenced_security_group_id = each.value
  from_port                    = 8123
  to_port                      = 8123
  ip_protocol                  = "tcp"
  description                  = "ClickHouse HTTP from staging ${each.key}"
}

resource "aws_vpc_security_group_ingress_rule" "clickhouse_native_from_staging" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = data.aws_security_group.clickhouse.id
  referenced_security_group_id = each.value
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
  description                  = "ClickHouse native protocol from staging ${each.key}"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_staging" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = each.value
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Valkey TLS from staging ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS for AWS endpoints and external APIs"
}

resource "aws_vpc_security_group_egress_rule" "app_http" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP for metadata and explicitly configured APIs"
}

resource "aws_vpc_security_group_egress_rule" "app_to_rds" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = each.value
  referenced_security_group_id = data.aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Staging PostgreSQL"
}

resource "aws_vpc_security_group_egress_rule" "app_to_clickhouse_http" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = each.value
  referenced_security_group_id = data.aws_security_group.clickhouse.id
  from_port                    = 8123
  to_port                      = 8123
  ip_protocol                  = "tcp"
  description                  = "Staging ClickHouse HTTP"
}

resource "aws_vpc_security_group_egress_rule" "app_to_clickhouse_native" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = each.value
  referenced_security_group_id = data.aws_security_group.clickhouse.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
  description                  = "Staging ClickHouse native protocol"
}

resource "aws_vpc_security_group_egress_rule" "app_to_redis" {
  for_each = {
    web    = aws_security_group.web.id
    worker = aws_security_group.worker.id
  }

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.redis.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Staging-only Valkey"
}

resource "aws_vpc_security_group_egress_rule" "web_to_worker" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.worker.id
  from_port                    = 3030
  to_port                      = 3030
  ip_protocol                  = "tcp"
  description                  = "Worker health checks"
}

resource "aws_acm_certificate" "staging" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.staging.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.production.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "staging" {
  certificate_arn         = aws_acm_certificate.staging.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_lb_listener_certificate" "staging" {
  listener_arn    = data.aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate_validation.staging.certificate_arn
}

resource "aws_lb_target_group" "web" {
  name        = "${var.service_name}-web-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.production.id
  target_type = "ip"

  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/public/health"
    protocol            = "HTTP"
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

resource "aws_lb_listener_rule" "http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = 100

  action {
    type = "redirect"

    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

resource "aws_route53_record" "staging" {
  zone_id = data.aws_route53_zone.production.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.production.dns_name
    zone_id                = data.aws_lb.production.zone_id
    evaluate_target_health = true
  }
}
