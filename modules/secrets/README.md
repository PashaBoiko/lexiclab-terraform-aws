# Secrets Module

This module creates AWS Secrets Manager secrets for storing sensitive configuration.

## Resources Created

- MongoDB URL secret
- JWT authentication secret
- AWS credentials secret (JSON with access_key_id and secret_access_key for S3, SES, and Bedrock)

## Usage

```hcl
module "secrets" {
  source = "./modules/secrets"

  project_name = "lexiclab"
  environment  = "prod"

  mongodb_url_value = var.mongodb_url
  jwt_secret_value  = var.jwt_secret

  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Referencing Secrets in ECS

### Single Value Secrets
```hcl
secrets = [
  {
    name      = "MONGODB_URL"
    valueFrom = module.secrets.mongodb_url_secret_arn
  },
  {
    name      = "JWT_AUTH_SECRET"
    valueFrom = module.secrets.jwt_secret_arn
  }
]
```

### JSON Secrets (specific keys)
```hcl
secrets = [
  {
    name      = "AWS_ACCESS_KEY_ID"
    valueFrom = "${module.secrets.aws_credentials_secret_arn}:access_key_id::"
  },
  {
    name      = "AWS_SECRET_ACCESS_KEY"
    valueFrom = "${module.secrets.aws_credentials_secret_arn}:secret_access_key::"
  }
]
```

## Updating Secrets

Secrets can be updated via:

1. **Terraform**: Update variables and apply
2. **AWS Console**: Navigate to Secrets Manager and update values
3. **AWS CLI**:
   ```bash
   aws secretsmanager update-secret --secret-id lexiclab/prod/mongodb-url --secret-string "new-value"
   ```

After updating secrets, force a new ECS deployment to pick up changes:
```bash
aws ecs update-service --cluster lexiclab-prod --service api --force-new-deployment
```

## Cost

AWS Secrets Manager costs $0.40 per secret per month. This module creates 3 secrets = $1.20/month.
