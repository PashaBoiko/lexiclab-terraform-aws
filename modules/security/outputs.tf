output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_api_security_group_id" {
  description = "ECS API security group ID"
  value       = aws_security_group.ecs_api.id
}

output "ecs_ui_security_group_id" {
  description = "ECS UI security group ID"
  value       = aws_security_group.ecs_ui.id
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_api_arn" {
  description = "ECS task role ARN for API"
  value       = aws_iam_role.ecs_task_api.arn
}

output "ecs_task_role_ui_arn" {
  description = "ECS task role ARN for UI"
  value       = aws_iam_role.ecs_task_ui.arn
}
