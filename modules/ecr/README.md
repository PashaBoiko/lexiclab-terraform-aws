# ECR Module

This module creates Amazon ECR repositories for storing Docker images.

## Resources Created

- ECR repository for API: `${project_name}-${environment}-api` (e.g., `lexiclab-prod-api`)
- ECR repository for UI: `${project_name}-${environment}-ui` (e.g., `lexiclab-prod-ui`)
- Lifecycle policies to keep last 10 images (auto-cleanup old images)
- Image scanning enabled on push

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"

  project_name = "lexiclab"
  environment  = "prod"

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Pushing Images

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.eu-central-1.amazonaws.com

# Build and push API image
cd ../lexiclab-nest-api
docker build -t <api_repository_url>:latest .
docker push <api_repository_url>:latest

# Build and push UI image
cd ../lexiclab-ui-react
docker build -t <ui_repository_url>:latest .
docker push <ui_repository_url>:latest
```

## Outputs

- `api_repository_url` - Full URL for pushing API images
- `ui_repository_url` - Full URL for pushing UI images
