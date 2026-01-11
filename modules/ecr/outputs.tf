output "api_repository_url" {
  description = "ECR repository URL for API"
  value       = aws_ecr_repository.api.repository_url
}

output "ui_repository_url" {
  description = "ECR repository URL for UI"
  value       = aws_ecr_repository.ui.repository_url
}

output "api_repository_arn" {
  description = "ECR repository ARN for API"
  value       = aws_ecr_repository.api.arn
}

output "ui_repository_arn" {
  description = "ECR repository ARN for UI"
  value       = aws_ecr_repository.ui.arn
}

output "api_repository_name" {
  description = "ECR repository name for API"
  value       = aws_ecr_repository.api.name
}

output "ui_repository_name" {
  description = "ECR repository name for UI"
  value       = aws_ecr_repository.ui.name
}
