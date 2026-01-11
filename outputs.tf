output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name - USE THIS AS YOUR APPLICATION URL"
  value       = module.alb.alb_dns_name
}

output "application_url" {
  description = "Application URL (ALB DNS)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ecr_api_repository_url" {
  description = "ECR repository URL for API"
  value       = module.ecr.api_repository_url
}

output "ecr_ui_repository_url" {
  description = "ECR repository URL for UI"
  value       = module.ecr.ui_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "api_service_name" {
  description = "API ECS service name"
  value       = module.ecs_service_api.service_name
}

output "ui_service_name" {
  description = "UI ECS service name"
  value       = module.ecs_service_ui.service_name
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito Client ID"
  value       = module.cognito.client_id
}

output "cognito_url" {
  description = "Cognito hosted UI URL"
  value       = module.cognito.cognito_url
}

output "cognito_domain" {
  description = "Cognito domain name"
  value       = module.cognito.domain
}
