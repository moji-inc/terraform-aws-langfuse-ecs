resource "random_password" "database" {
  length  = 40
  special = false
}

resource "random_password" "nextauth" {
  length  = 64
  special = false
}

resource "random_password" "salt" {
  length  = 40
  special = false
}

resource "random_id" "encryption_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "app" {
  name        = "${var.service_name}/app"
  description = "Staging-only Langfuse database and application secrets."
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${var.database_user}:${random_password.database.result}@${data.aws_db_instance.production.address}:${data.aws_db_instance.production.port}/${var.database_name}"

    DATABASE_PASSWORD = random_password.database.result
    NEXTAUTH_SECRET   = random_password.nextauth.result
    SALT              = random_password.salt.result
    ENCRYPTION_KEY    = random_id.encryption_key.hex
  })
}
