output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_url" {
  description = "Cognito hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "callback_urls" {
  description = "Configured OAuth callback URLs"
  value       = aws_cognito_user_pool_client.main.callback_urls
}

output "logout_urls" {
  description = "Configured OAuth logout URLs"
  value       = aws_cognito_user_pool_client.main.logout_urls
}

# Data source for region
data "aws_region" "current" {}
