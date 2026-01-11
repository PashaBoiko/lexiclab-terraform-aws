# Security Module

This module creates security groups and IAM roles/policies for the infrastructure.

## Resources Created

### Security Groups
- **ALB Security Group**: Allows HTTP (80) and HTTPS (443) from internet
- **ECS API Security Group**: Allows traffic from ALB on port 3000, outbound HTTPS and MongoDB port
- **ECS UI Security Group**: Allows traffic from ALB on port 3000, outbound HTTPS

### IAM Roles
- **ECS Task Execution Role**: Used by ECS to pull images, write logs, and access secrets
- **ECS Task Role (API)**: Grants API tasks access to S3, SES, Bedrock, and Cognito
- **ECS Task Role (UI)**: Grants UI tasks read-only access to Cognito

## Usage

```hcl
module "security" {
  source = "./modules/security"

  project_name          = "lexiclab"
  environment           = "prod"
  vpc_id                = module.networking.vpc_id
  s3_bucket_arn         = "arn:aws:s3:::lexiclab.static"
  cognito_user_pool_arn = "arn:aws:cognito-idp:eu-central-1:ACCOUNT_ID:userpool/eu-central-1_fAck0yBkw"

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Security Features

1. **Least Privilege**: Each role has only the permissions it needs
2. **Network Isolation**: ECS tasks in private subnets, only accessible via ALB
3. **Secrets Management**: Task execution role can access Secrets Manager
4. **AWS Service Access**: Task roles grant fine-grained access to S3, SES, Bedrock, Cognito

## Outputs

- Security group IDs for ALB and ECS services
- IAM role ARNs for task execution and task roles
