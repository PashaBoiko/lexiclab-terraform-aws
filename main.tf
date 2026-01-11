locals {
  project_name = "lexiclab"
  environment  = "prod"
  region       = "eu-central-1"

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

# Cognito User Pool (must be created before security module)
module "cognito" {
  source = "./modules/cognito"

  project_name    = local.project_name
  environment     = local.environment
  application_url = "http://${module.alb.alb_dns_name}"

  deletion_protection = true

  # Google OAuth (optional)
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  tags = local.common_tags

  depends_on = [module.alb]
}

# Security
module "security" {
  source = "./modules/security"

  project_name          = local.project_name
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  s3_bucket_arn         = "arn:aws:s3:::lexiclab.static"
  cognito_user_pool_arn = module.cognito.user_pool_arn

  tags = local.common_tags

  depends_on = [module.cognito]
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

  certificate_arn = var.acm_certificate_arn

  tags = local.common_tags
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
    { name = "COGNITO_LOGIN_REDIRECT_URL", value = "http://${module.alb.alb_dns_name}/api/auth/sign-in" },
    { name = "GOGNITO_LOGIN_SUCCESS_URL", value = "http://${module.alb.alb_dns_name}/" }
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
    { name = "SERVER_API_URL", value = "http://${module.alb.alb_dns_name}/api" },
    { name = "AWS_REGION", value = local.region },
    { name = "COGNITO_URL", value = module.cognito.cognito_url },
    { name = "COGNITO_CLIENT_ID", value = module.cognito.client_id },
    { name = "COGNITO_USER_POOL_ID", value = module.cognito.user_pool_id },
    { name = "COGNITO_SCOPE", value = "email+openid+phone" },
    { name = "COGNITO_LOGIN_REDIRECT_URL", value = "http://${module.alb.alb_dns_name}/api/auth/sign-in" },
    { name = "COGNITO_LOGOUT_REDIRECT_URL", value = "http://${module.alb.alb_dns_name}/api/auth/sign-out" },
    { name = "GOGNITO_LOGIN_SUCCESS_URL", value = "http://${module.alb.alb_dns_name}/" }
  ]

  secrets = []

  tags = local.common_tags

  depends_on = [module.alb]
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
