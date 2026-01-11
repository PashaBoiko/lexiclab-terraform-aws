variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_url" {
  description = "Application URL for OAuth callbacks (e.g., http://alb-dns-name or https://example.com)"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection for Cognito User Pool"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
