locals {
  project_name = "lexiclab"
  environment  = "prod"
  region       = "eu-central-1"
  domain_name  = "lexiclab.com"

  common_tags = {
    Project     = "lexiclab"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# Networking
module "networking" {
  source = "./modules/networking"

  project_name       = local.project_name
  environment        = local.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  enable_nat_gateway = false # No NAT Gateway - ECS tasks in public subnets (saves $35/month)

  tags = local.common_tags
}

# DNS and SSL Certificate (must be created before ALB for HTTPS)
module "dns" {
  source = "./modules/dns"

  project_name = local.project_name
  environment  = local.environment
  domain_name  = local.domain_name

  tags = local.common_tags
}

# Cognito User Pool
module "cognito" {
  source = "./modules/cognito"

  project_name    = local.project_name
  environment     = local.environment
  application_url = "https://${local.domain_name}"

  deletion_protection = true

  # Google OAuth (optional)
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  tags = local.common_tags
}

# Security (security groups and IAM roles - no Cognito dependency to avoid cycle)
module "security" {
  source = "./modules/security"

  project_name  = local.project_name
  environment   = local.environment
  vpc_id        = module.networking.vpc_id
  s3_bucket_arn = "arn:aws:s3:::lexiclab.static"

  tags = local.common_tags
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"

  project_name = local.project_name
  environment  = local.environment

  tags = local.common_tags
}

# ECS Cluster
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name = local.project_name
  environment  = local.environment

  tags = local.common_tags
}

# Secrets
module "secrets" {
  source = "./modules/secrets"

  project_name = local.project_name
  environment  = local.environment

  mongodb_url_value = var.mongodb_url
  jwt_secret_value  = var.jwt_secret

  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key

  tags = local.common_tags
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name       = local.project_name
  environment        = local.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]

  enable_https    = true
  certificate_arn = module.dns.certificate_arn
  api_domain      = "api.${local.domain_name}"

  tags = local.common_tags
}

# Route53 A records pointing domain to ALB
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${local.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "main" {
  name         = local.domain_name
  private_zone = false
}

# Monitoring
module "monitoring" {
  source = "./modules/monitoring"

  project_name   = local.project_name
  environment    = local.environment
  cluster_name   = module.ecs_cluster.cluster_name
  alb_arn_suffix = split(":", module.alb.alb_arn)[5]

  log_retention_days = 3  # Reduced retention for cost savings
  enable_alarms      = true

  tags = local.common_tags
}

# ECS Service - API
module "ecs_service_api" {
  source = "./modules/ecs-service"

  project_name = local.project_name
  environment  = local.environment
  service_name = "api"
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  container_image = "${module.ecr.api_repository_url}:latest"
  container_port  = 3000

  cpu           = 256  # Reduced for small user base
  memory        = 512  # Reduced for small user base
  desired_count = 1    # Single task for 10-50 users
  min_capacity  = 1    # Can scale down to 1
  max_capacity  = 3    # Max 3 tasks if needed

  subnet_ids         = module.networking.public_subnet_ids  # Public subnets (no NAT Gateway)
  security_group_ids = [module.security.ecs_api_security_group_id]
  target_group_arn   = module.alb.api_target_group_arn
  assign_public_ip   = true  # Required without NAT Gateway

  execution_role_arn = module.security.ecs_task_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_api_arn

  environment_variables = [
    { name = "PORT", value = "3000" },
    { name = "NODE_ENV", value = "production" },
    { name = "AWS_REGION", value = local.region },
    { name = "S3_STATIC_BUCKET_NAME", value = "lexiclab.static" },
    { name = "S3_CDN_PATH", value = "https://s3.${local.region}.amazonaws.com/lexiclab.static/" },
    { name = "RESTRICTED_AUTH", value = "true" },
    { name = "COGNITO_URL", value = module.cognito.cognito_url },
    { name = "COGNITO_CLIENT_ID", value = module.cognito.client_id },
    { name = "COGNITO_USER_POOL_ID", value = module.cognito.user_pool_id },
    { name = "COGNITO_SCOPE", value = "email+openid+phone" },
    { name = "COGNITO_LOGIN_REDIRECT_URL", value = "https://${local.domain_name}/api/auth/sign-in" },
    { name = "GOGNITO_LOGIN_SUCCESS_URL", value = "https://${local.domain_name}/" }
  ]

  secrets = [
    { name = "MONGODB_URL", valueFrom = module.secrets.mongodb_url_secret_arn },
    { name = "JWT_AUTH_SECRET", valueFrom = module.secrets.jwt_secret_arn },
    { name = "AWS_ACCESS_KEY_ID", valueFrom = "${module.secrets.aws_credentials_secret_arn}:access_key_id::" },
    { name = "AWS_SECRET_ACCESS_KEY", valueFrom = "${module.secrets.aws_credentials_secret_arn}:secret_access_key::" }
  ]

  tags = local.common_tags

  depends_on = [module.alb]
}

# ECS Service - UI
module "ecs_service_ui" {
  source = "./modules/ecs-service"

  project_name = local.project_name
  environment  = local.environment
  service_name = "ui"
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  container_image = "${module.ecr.ui_repository_url}:latest"
  container_port  = 3000

  cpu           = 256
  memory        = 512
  desired_count = 1    # Single task for 10-50 users
  min_capacity  = 1    # Can scale down to 1
  max_capacity  = 3    # Max 3 tasks if needed

  subnet_ids         = module.networking.public_subnet_ids  # Public subnets (no NAT Gateway)
  security_group_ids = [module.security.ecs_ui_security_group_id]
  target_group_arn   = module.alb.ui_target_group_arn
  assign_public_ip   = true  # Required without NAT Gateway

  execution_role_arn = module.security.ecs_task_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_ui_arn

  environment_variables = [
    { name = "NODE_ENV", value = "production" },
    { name = "SERVER_API_URL", value = "https://${local.domain_name}/api" },
    { name = "AWS_REGION", value = local.region },
    { name = "COGNITO_URL", value = module.cognito.cognito_url },
    { name = "COGNITO_CLIENT_ID", value = module.cognito.client_id },
    { name = "COGNITO_USER_POOL_ID", value = module.cognito.user_pool_id },
    { name = "COGNITO_SCOPE", value = "email+openid+phone" },
    { name = "COGNITO_LOGIN_REDIRECT_URL", value = "https://${local.domain_name}/api/auth/sign-in" },
    { name = "COGNITO_LOGOUT_REDIRECT_URL", value = "https://${local.domain_name}/api/auth/sign-out" },
    { name = "GOGNITO_LOGIN_SUCCESS_URL", value = "https://${local.domain_name}/" }
  ]

  secrets = []

  tags = local.common_tags

  depends_on = [module.alb]
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# Cognito IAM policies (created after Cognito to avoid circular dependency)
resource "aws_iam_role_policy" "ecs_task_api_cognito" {
  name = "${local.project_name}-${local.environment}-ecs-api-cognito-policy"
  role = module.security.ecs_task_role_api_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminListGroupsForUser",
          "cognito-idp:GetUser"
        ]
        Resource = module.cognito.user_pool_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_ui_cognito" {
  name = "${local.project_name}-${local.environment}-ecs-ui-cognito-policy"
  role = module.security.ecs_task_role_ui_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:GetUser"
        ]
        Resource = module.cognito.user_pool_arn
      }
    ]
  })
}
