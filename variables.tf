variable "mongodb_url" {
  description = "MongoDB Atlas connection URL"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT authentication secret"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID (used for S3, SES, Bedrock)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key (used for S3, SES, Bedrock)"
  type        = string
  sensitive   = true
}

# Note: Cognito configuration is now managed by the cognito module
# No manual configuration needed - it will be automatically created and configured

variable "google_client_id" {
  description = "Google OAuth Client ID for Cognito (optional)"
  type        = string
  default     = ""
  sensitive   = false
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret for Cognito (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS (optional)"
  type        = string
  default     = ""
}
