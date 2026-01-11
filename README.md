# Lexiclab AWS Infrastructure

Terraform infrastructure for deploying Lexiclab applications (NestJS API and TanStack Start React UI) to AWS ECS Fargate with Application Load Balancer and comprehensive monitoring.

## Architecture

```
Internet → Application Load Balancer
            ├─→ /api/* → NestJS API (ECS Fargate) → MongoDB Atlas
            └─→ /*     → React SSR UI (ECS Fargate)
```

### Key Components

- **VPC**: Multi-AZ networking with public/private subnets
- **ECS Fargate**: Serverless container deployment for both applications
- **ALB**: Path-based routing (`/api/*` → backend, `/*` → frontend)
- **ECR**: Docker image registry
- **Cognito**: User authentication and OAuth 2.0 (automatically configured)
- **Secrets Manager**: Secure storage for sensitive configuration
- **CloudWatch**: Centralized logging and monitoring with alarms

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Docker](https://www.docker.com/) for building and pushing images
- MongoDB Atlas account with a cluster created
- AWS account with appropriate IAM permissions

## Quick Start

### 1. Clone and Configure

```bash
cd /Users/pavloprovectus/Documents/my-projects/lexiclab-aws

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### 2. Initialize Terraform State Backend

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket lexiclab-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket lexiclab-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name lexiclab-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply
```

### 4. Configure MongoDB Atlas

**IMPORTANT**: Since this configuration doesn't use NAT Gateway (for cost savings), your MongoDB Atlas must allow connections from anywhere:

1. Go to [MongoDB Atlas Console](https://cloud.mongodb.com)
2. Navigate to **Network Access**
3. Click **"Add IP Address"**
4. Select **"Allow Access from Anywhere"** (0.0.0.0/0)
5. Click **"Confirm"**

Your database is still secure - protected by username/password and TLS encryption.

See `docs/MONGODB_ATLAS_SETUP.md` for detailed MongoDB setup instructions.

### 5. AWS Cognito User Pool (Automatic)

**Good news**: Cognito is automatically created by Terraform with production-ready configuration!

After deployment, get your Cognito details:
```bash
terraform output cognito_user_pool_id
terraform output cognito_client_id
terraform output cognito_url
```

**Create your first user** (via AWS Console or CLI):
```bash
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username your-email@example.com \
  --user-attributes Name=email,Value=your-email@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!"
```

See `docs/COGNITO_SETUP.md` for complete Cognito documentation.

### 6. Build and Push Docker Images

```bash
# Build and push both applications to ECR
./scripts/build-and-push.sh
```

### 7. Access Your Application

```bash
# Get application URL
terraform output application_url

# Visit http://<alb-dns-name>/
```

**Note**: You'll need to login with the Cognito user you created in step 5.

## Project Structure

```
lexiclab-aws/
├── main.tf                    # Root module orchestration
├── variables.tf               # Input variables
├── outputs.tf                 # Infrastructure outputs
├── providers.tf               # AWS provider configuration
├── backend.tf                 # S3 backend for state
├── versions.tf                # Terraform version constraints
├── modules/                   # Reusable Terraform modules
│   ├── networking/            # VPC, subnets, routes
│   ├── security/              # Security groups, IAM roles
│   ├── cognito/               # Cognito User Pool (authentication)
│   ├── ecs-cluster/           # ECS cluster
│   ├── ecs-service/           # Reusable ECS service module
│   ├── alb/                   # Application Load Balancer
│   ├── ecr/                   # ECR repositories
│   ├── secrets/               # Secrets Manager
│   └── monitoring/            # CloudWatch logs and alarms
└── scripts/                   # Deployment automation
    ├── build-and-push.sh      # Build Docker images and push to ECR
    ├── update-task.sh         # Force ECS service redeployment
    └── create-secrets.sh      # Initialize secrets in AWS
```

## Configuration

### Required Variables (in terraform.tfvars)

```hcl
# MongoDB Atlas connection string
mongodb_url = "mongodb+srv://user:pass@cluster.mongodb.net/lexiclab?retryWrites=true"

# JWT secret (generate with: openssl rand -base64 32)
jwt_secret = "your-generated-secret"

# AWS credentials (used for S3, SES, Bedrock)
aws_access_key_id     = "AKIAIOSFODNN7EXAMPLE"
aws_secret_access_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Note**: AWS Cognito is automatically created by Terraform - no manual configuration needed!

### Optional Variables

```hcl
# ACM certificate for HTTPS (optional)
acm_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/..."
```

## Deployment Workflow

### Initial Deployment

1. Deploy infrastructure with Terraform
2. Configure MongoDB Atlas IP whitelist
3. Build and push Docker images
4. ECS automatically pulls images and starts tasks

### Updating Applications

```bash
# Make code changes in ../lexiclab-nest-api or ../lexiclab-ui-react

# Build and push new images
./scripts/build-and-push.sh

# Force ECS to pull new images
./scripts/update-task.sh

# Monitor deployment
aws ecs describe-services --cluster lexiclab-prod --services api ui
```

## Monitoring

### View Logs

```bash
# Tail API logs
aws logs tail /ecs/lexiclab-prod-api --follow

# Tail UI logs
aws logs tail /ecs/lexiclab-prod-ui --follow

# Filter for errors
aws logs filter-log-events \
  --log-group-name /ecs/lexiclab-prod-api \
  --filter-pattern "ERROR"
```

### Check Service Health

```bash
# ECS service status
aws ecs describe-services --cluster lexiclab-prod --services api ui

# ALB target health
terraform output alb_dns_name
# Visit http://<alb-dns>/api and http://<alb-dns>/

# CloudWatch alarms
aws cloudwatch describe-alarms --alarm-name-prefix lexiclab-prod
```

## Cost Estimation

**Current Configuration: Ultra-Low Cost for 10-50 Users (~$45-55/month)** 🎉

| Service | Cost |
|---------|------|
| ALB | $25 |
| ECS Fargate (API) | $9 |
| ECS Fargate (UI) | $9 |
| CloudWatch Logs | $3 |
| Data Transfer | $5-10 |
| Secrets Manager | $1.20 |
| ECR Storage | $2 |
| **Total** | **~$44-54/month** |

**Savings: $230/month (84% reduction from original $284)**

### What's Removed for Cost Savings

- ❌ **NAT Gateway** (saves $35/month)
  - ECS tasks use public IPs
  - MongoDB Atlas configured with `0.0.0.0/0` access
  - See `docs/MONGODB_ATLAS_SETUP.md`

- ❌ **CloudFront CDN** (saves $60/month)
  - Access via ALB directly: `http://<alb-dns-name>`
  - Fine for 10-50 users in single region

### Optional Cost Reductions

1. **Use Fargate Spot** (saves $12/month) → **~$33-43/month**
   - 70% discount on compute
   - Rare task interruptions (<2%)

2. **Scale to zero at night** (saves $5-10/month) → **~$30-40/month**
   - Automate with Lambda/EventBridge
   - 1-2 minute cold start in morning

**Absolute minimum: ~$30-40/month** (Spot + Off-hours scaling)

See `docs/COST_OPTIMIZATION.md` for more options.

## Troubleshooting

### Tasks Not Starting

Check IAM role permissions:
```bash
aws ecs describe-services --cluster lexiclab-prod --services api
# Look for "events" section for error messages
```

Common causes:
- Secrets Manager permissions missing
- Invalid Docker image
- Insufficient CPU/memory for task

### ALB Returns 503

Check target health:
```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

Common causes:
- ECS tasks not healthy
- Security group blocking traffic
- Health check path returning non-200

### MongoDB Connection Failed

Since we don't use NAT Gateway, MongoDB Atlas must allow `0.0.0.0/0` access. See `docs/MONGODB_ATLAS_SETUP.md` for details.

## Security Best Practices

1. **Secrets Management**: Never commit `terraform.tfvars` or `.tfstate` files
2. **IAM Roles**: Use least privilege access for ECS task roles
3. **Network Isolation**: ECS tasks run in private subnets
4. **HTTPS**: Use ACM certificates for production (set `acm_certificate_arn`)
5. **Security Groups**: Restrict access to only necessary ports
6. **Monitoring**: Enable CloudWatch alarms and review logs regularly

## Cleanup

To destroy all resources:

```bash
# Warning: This will delete all infrastructure!
terraform destroy
```

Note: You'll need to manually delete:
- S3 state bucket (if no longer needed)
- DynamoDB state lock table
- ECR images (if repositories are not empty)

## Support

For issues or questions:
1. Check module README files in `modules/*/README.md`
2. Review CloudWatch logs for application errors
3. Check AWS Console for service-specific issues

## License

This infrastructure code is part of the Lexiclab project.
