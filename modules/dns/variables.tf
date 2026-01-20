variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., prod, dev, staging)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., lexiclab.com)"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name (optional - if not provided, A records won't be created)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB Route53 zone ID (optional - required if alb_dns_name is provided)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
