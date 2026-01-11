# ECS Service Module

This is a reusable module for deploying containerized applications on ECS Fargate with autoscaling and load balancer integration.

## Resources Created

- ECS Task Definition
- ECS Service with Fargate launch type
- CloudWatch Log Group
- Application Auto Scaling target and policies (CPU and memory-based)

## Features

- **Fargate Deployment**: Serverless container execution
- **Auto Scaling**: Scales based on CPU (70%) and memory (80%) utilization
- **Health Checks**: Configurable container health checks
- **Circuit Breaker**: Automatic rollback on failed deployments
- **Secrets Management**: Supports AWS Secrets Manager and SSM Parameter Store
- **Logging**: CloudWatch Logs with 7-day retention

## Usage

```hcl
module "ecs_service_api" {
  source = "./modules/ecs-service"

  project_name   = "lexiclab"
  environment    = "prod"
  service_name   = "api"
  cluster_id     = module.ecs_cluster.cluster_id
  cluster_name   = module.ecs_cluster.cluster_name

  container_image = "${module.ecr.api_repository_url}:latest"
  container_port  = 3000

  cpu            = 512
  memory         = 1024
  desired_count  = 2
  min_capacity   = 2
  max_capacity   = 10

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security.ecs_api_security_group_id]
  target_group_arn   = module.alb.api_target_group_arn

  execution_role_arn = module.security.ecs_task_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_api_arn

  environment_variables = [
    { name = "NODE_ENV", value = "production" },
    { name = "PORT", value = "3000" }
  ]

  secrets = [
    { name = "MONGODB_URL", valueFrom = module.secrets.mongodb_url_secret_arn }
  ]

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## CPU and Memory Combinations

Valid Fargate CPU/Memory combinations:
- CPU 256: Memory 512, 1024, 2048
- CPU 512: Memory 1024-4096 (1GB increments)
- CPU 1024: Memory 2048-8192 (1GB increments)
- CPU 2048: Memory 4096-16384 (1GB increments)
- CPU 4096: Memory 8192-30720 (1GB increments)
