# =============================================================================
# Amazon SES for transactional email
# =============================================================================

resource "aws_ses_domain_identity" "this" {
  count = var.enable_ses ? 1 : 0

  domain = local.ses_domain_name

  lifecycle {
    precondition {
      condition     = local.ses_domain_name != ""
      error_message = "enable_ses requires ses_domain_name or custom_domain."
    }

    precondition {
      condition     = var.manage_ses_smtp_credentials || trimspace(var.smtp_connection_url_secret_arn) != ""
      error_message = "enable_ses with manage_ses_smtp_credentials=false requires smtp_connection_url_secret_arn."
    }
  }
}

resource "aws_ses_domain_identity_verification" "this" {
  count = var.enable_ses ? 1 : 0

  domain     = aws_ses_domain_identity.this[0].id
  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "this" {
  count = var.enable_ses ? 1 : 0

  domain = aws_ses_domain_identity.this[0].domain
}

resource "aws_route53_record" "ses_verification" {
  count = var.enable_ses ? 1 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = "_amazonses.${local.ses_domain_name}"
  type            = "TXT"
  ttl             = 600
  records         = [aws_ses_domain_identity.this[0].verification_token]

  lifecycle {
    precondition {
      condition     = local.ses_route53_zone_id != ""
      error_message = "enable_ses requires ses_route53_zone_id or route53_zone_id."
    }
  }
}

resource "aws_route53_record" "ses_dkim" {
  count = var.enable_ses ? 3 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = "${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}._domainkey.${local.ses_domain_name}"
  type            = "CNAME"
  ttl             = 600
  records         = ["${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}.${var.ses_dkim_domain_suffix}"]
}

resource "aws_route53_record" "ses_spf" {
  count = var.enable_ses && var.ses_create_spf_record ? 1 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = local.ses_domain_name
  type            = "TXT"
  ttl             = 600
  records         = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "ses_dmarc" {
  count = var.enable_ses && var.ses_create_dmarc_record ? 1 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = "_dmarc.${local.ses_domain_name}"
  type            = "TXT"
  ttl             = 600
  records         = [var.ses_dmarc_policy]
}

resource "aws_ses_domain_mail_from" "this" {
  count = var.enable_ses && local.ses_mail_from_domain != null ? 1 : 0

  domain                 = aws_ses_domain_identity.this[0].domain
  mail_from_domain       = local.ses_mail_from_domain
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count = var.enable_ses && local.ses_mail_from_domain != null ? 1 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = local.ses_mail_from_domain
  type            = "MX"
  ttl             = 600
  records         = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  count = var.enable_ses && local.ses_mail_from_domain != null ? 1 : 0

  allow_overwrite = true
  zone_id         = local.ses_route53_zone_id
  name            = local.ses_mail_from_domain
  type            = "TXT"
  ttl             = 600
  records         = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_iam_user" "ses_smtp" {
  count = var.enable_ses ? 1 : 0

  name = "${var.service_name}-ses-smtp"
  path = "/service/"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "ses_smtp" {
  count = var.enable_ses && var.manage_ses_smtp_credentials ? 1 : 0

  user = aws_iam_user.ses_smtp[0].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy" "ses_smtp_send" {
  count = var.enable_ses ? 1 : 0

  name = "${var.service_name}-ses-smtp-send"
  user = aws_iam_user.ses_smtp[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = aws_ses_domain_identity.this[0].arn
        Condition = {
          StringEquals = {
            "ses:FromAddress" = local.ses_email_from
          }
        }
      }
    ]
  })
}
