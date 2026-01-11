# Secrets Manager - MongoDB URL
resource "aws_secretsmanager_secret" "mongodb_url" {
  name        = "${var.project_name}/${var.environment}/mongodb-url"
  description = "MongoDB Atlas connection URL"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-mongodb-url"
    }
  )
}

resource "aws_secretsmanager_secret_version" "mongodb_url" {
  secret_id     = aws_secretsmanager_secret.mongodb_url.id
  secret_string = var.mongodb_url_value
}

# Secrets Manager - JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "${var.project_name}/${var.environment}/jwt-secret"
  description = "JWT authentication secret"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-jwt-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret_value
}

# Secrets Manager - AWS Credentials (used for S3, SES, Bedrock)
resource "aws_secretsmanager_secret" "aws_credentials" {
  name        = "${var.project_name}/${var.environment}/aws-credentials"
  description = "AWS credentials for S3, SES, and Bedrock services"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aws-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = aws_secretsmanager_secret.aws_credentials.id
  secret_string = jsonencode({
    access_key_id     = var.aws_access_key_id
    secret_access_key = var.aws_secret_access_key
  })
}
