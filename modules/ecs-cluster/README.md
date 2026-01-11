# ECS Cluster Module

This module creates an ECS cluster configured for Fargate deployments.

## Resources Created

- ECS Cluster with Container Insights enabled
- Fargate capacity providers (FARGATE and FARGATE_SPOT)

## Usage

```hcl
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name = "lexiclab"
  environment  = "prod"

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Features

- **Container Insights**: Enabled for monitoring CPU, memory, network metrics
- **Fargate**: Serverless container deployment
- **Fargate Spot**: Optional cost-optimized capacity (70% discount)
