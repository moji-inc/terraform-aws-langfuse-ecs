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
