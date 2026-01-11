output "api_log_group_name" {
  description = "API CloudWatch log group name"
  value       = aws_cloudwatch_log_group.api.name
}

output "api_log_group_arn" {
  description = "API CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.api.arn
}

output "ui_log_group_name" {
  description = "UI CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ui.name
}

output "ui_log_group_arn" {
  description = "UI CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.ui.arn
}

output "alarm_arns" {
  description = "List of CloudWatch alarm ARNs"
  value = var.enable_alarms ? concat(
    [aws_cloudwatch_metric_alarm.api_cpu_high[0].arn],
    [aws_cloudwatch_metric_alarm.api_memory_high[0].arn],
    [aws_cloudwatch_metric_alarm.api_task_count_zero[0].arn],
    [aws_cloudwatch_metric_alarm.ui_cpu_high[0].arn],
    [aws_cloudwatch_metric_alarm.ui_memory_high[0].arn],
    [aws_cloudwatch_metric_alarm.ui_task_count_zero[0].arn],
    [aws_cloudwatch_metric_alarm.alb_5xx_errors[0].arn]
  ) : []
}
