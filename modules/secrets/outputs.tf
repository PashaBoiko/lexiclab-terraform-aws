output "mongodb_url_secret_arn" {
  description = "MongoDB URL secret ARN"
  value       = aws_secretsmanager_secret.mongodb_url.arn
}

output "jwt_secret_arn" {
  description = "JWT secret ARN"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "aws_credentials_secret_arn" {
  description = "AWS credentials secret ARN (for S3, SES, Bedrock)"
  value       = aws_secretsmanager_secret.aws_credentials.arn
}
