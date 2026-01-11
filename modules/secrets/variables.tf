variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., prod, dev, staging)"
  type        = string
}

variable "mongodb_url_value" {
  description = "MongoDB Atlas connection URL"
  type        = string
  sensitive   = true
}

variable "jwt_secret_value" {
  description = "JWT authentication secret"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID (for S3, SES, Bedrock)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key (for S3, SES, Bedrock)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
