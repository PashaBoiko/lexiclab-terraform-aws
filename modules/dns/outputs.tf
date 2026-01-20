output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "domain_name" {
  description = "Root domain name"
  value       = var.domain_name
}

output "api_domain" {
  description = "API domain name"
  value       = "api.${var.domain_name}"
}

output "app_url" {
  description = "Application URL (HTTPS)"
  value       = "https://${var.domain_name}"
}

output "api_url" {
  description = "API URL (HTTPS)"
  value       = "https://api.${var.domain_name}"
}
