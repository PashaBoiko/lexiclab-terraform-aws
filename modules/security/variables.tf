variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., prod, dev, staging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for API access"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
