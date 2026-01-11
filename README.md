# Lexiclab AWS Infrastructure

Terraform infrastructure for deploying Lexiclab applications (NestJS API + TanStack Start React UI) to AWS ECS Fargate.

## Architecture

```
Internet → Application Load Balancer
            ├─→ /api/* → NestJS API (ECS Fargate) → MongoDB Atlas
            └─→ /*     → React SSR UI (ECS Fargate)
```

**Components:**
- VPC with public/private subnets (3 AZs)
- ECS Fargate (serverless containers)
- Application Load Balancer (path-based routing)
- Cognito User Pool (authentication + Google Sign-In)
- ECR (Docker image registry)
- Secrets Manager (credentials storage)
- CloudWatch (logs + monitoring)

## Cost: ~$45-55/month

| Service | Cost |
|---------|------|
| ALB | $25 |
| ECS Fargate (API) | $9 |
| ECS Fargate (UI) | $9 |
| CloudWatch Logs | $3 |
| Secrets Manager | $1.20 |
| ECR Storage | $2 |
| Data Transfer | $5-10 |
| **Total** | **~$45-55/month** |

VPC and Cognito are FREE for your use case.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured
- Docker
- MongoDB Atlas account
- AWS account

## Setup

### 1. Clone and Configure

```bash
cd /Users/pavloprovectus/Documents/my-projects/lexiclab-aws
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Required in `terraform.tfvars`:**
```hcl
# MongoDB Atlas
mongodb_url = "mongodb+srv://user:pass@cluster.mongodb.net/lexiclab?retryWrites=true"

# JWT Secret (generate: openssl rand -base64 32)
jwt_secret = "your-jwt-secret"

# AWS Credentials (for S3, SES, Bedrock)
aws_access_key_id     = "AKIA..."
aws_secret_access_key = "..."

# Optional: Google Sign-In
google_client_id     = "123456789-abc.apps.googleusercontent.com"
google_client_secret = "GOCSPX-..."

# Optional: HTTPS
acm_certificate_arn = ""
```

### 2. Initialize Terraform State

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
terraform init
terraform plan
terraform apply
```

**Note:** Terraform will create new ECR repositories:
- `lexiclab-prod-api`
- `lexiclab-prod-ui`

These are separate from your existing `lexiclab-api` and `lexiclab-ui` repositories. You can keep both or migrate images later.

### 4. Configure MongoDB Atlas

**IMPORTANT:** Since we don't use NAT Gateway (cost savings), MongoDB Atlas must allow connections from anywhere:

1. Go to [MongoDB Atlas Console](https://cloud.mongodb.com) → **Network Access**
2. Click **"Add IP Address"** → Select **"Allow Access from Anywhere"** (0.0.0.0/0)
3. Click **"Confirm"**

Your database is still secure (username/password + TLS encryption).

### 5. Setup Google Sign-In (Optional)

#### Get Google OAuth Credentials

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Create project or select existing
3. Configure **OAuth consent screen**:
   - External user type
   - App name: `Lexiclab`
   - Scopes: `email`, `profile`, `openid`
4. Create **OAuth client ID**:
   - Application type: Web application
   - Authorized JavaScript origins: `http://<your-alb-dns>`
   - Authorized redirect URIs: `https://<cognito-domain>.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse`
5. Copy Client ID and Client Secret

#### Get Your Cognito Domain (after first deploy)

```bash
terraform output cognito_domain
# Example: lexiclab-prod-123456789012

# Your redirect URI:
# https://lexiclab-prod-123456789012.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse
```

#### Update Google Redirect URI

Go back to Google Cloud Console and update the redirect URI with your actual Cognito domain.

#### Configure Terraform

Add to `terraform.tfvars`:
```hcl
google_client_id     = "your-client-id.apps.googleusercontent.com"
google_client_secret = "GOCSPX-your-secret"
```

Apply changes:
```bash
terraform apply
```

### 6. Get Cognito Details

```bash
terraform output cognito_user_pool_id
terraform output cognito_client_id
terraform output cognito_url
```

**Create first user** (or use Google Sign-In):
```bash
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username your-email@example.com \
  --user-attributes Name=email,Value=your-email@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!"
```

### 7. Access Application

```bash
terraform output application_url
# Visit: http://<alb-dns>/
```

## Project Structure

```
lexiclab-aws/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Outputs
├── providers.tf               # AWS provider
├── backend.tf                 # S3 backend
├── versions.tf                # Terraform versions
├── terraform.tfvars.example   # Example config
├── modules/
│   ├── networking/            # VPC, subnets, routes
│   ├── security/              # Security groups, IAM roles
│   ├── cognito/               # Cognito User Pool
│   ├── ecs-cluster/           # ECS cluster
│   ├── ecs-service/           # ECS service (reusable)
│   ├── alb/                   # Load balancer
│   ├── ecr/                   # Docker registry
│   ├── secrets/               # Secrets Manager
│   └── monitoring/            # CloudWatch
└── scripts/
    └── update-task.sh         # Force ECS redeploy (optional)
```

## Updating Applications

Make code changes and push to GitHub - GitHub Actions handles the rest:

```bash
# Make code changes in your app repos
cd ../lexiclab-nest-api  # or ../lexiclab-ui-react
# ... make changes ...
git add .
git commit -m "Your changes"
git push

# GitHub Actions will automatically:
# 1. Build Docker images
# 2. Push to ECR
# 3. Deploy to ECS
```

**Optional:** Force immediate ECS redeployment:
```bash
./scripts/update-task.sh
```

**Monitor deployment:**
```bash
aws ecs describe-services --cluster lexiclab-prod --services api ui
```

## Monitoring

**View Logs:**
```bash
# API logs
aws logs tail /ecs/lexiclab-prod-api --follow

# UI logs
aws logs tail /ecs/lexiclab-prod-ui --follow

# Filter errors
aws logs filter-log-events \
  --log-group-name /ecs/lexiclab-prod-api \
  --filter-pattern "ERROR"
```

**Check Service Health:**
```bash
# ECS services
aws ecs describe-services --cluster lexiclab-prod --services api ui

# ALB targets
aws elbv2 describe-target-health --target-group-arn <arn>
```

## Troubleshooting

### ECS Tasks Not Starting

```bash
# Check service events
aws ecs describe-services --cluster lexiclab-prod --services api

# Check task logs
aws logs tail /ecs/lexiclab-prod-api --follow
```

Common causes:
- Secrets Manager permissions missing
- Invalid Docker image
- Insufficient CPU/memory

### ALB Returns 503

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>
```

Common causes:
- ECS tasks not healthy
- Security group blocking traffic
- Health check path returning non-200

### MongoDB Connection Failed

Since we don't use NAT Gateway, verify MongoDB Atlas allows `0.0.0.0/0`:
1. MongoDB Atlas → Network Access
2. Check `0.0.0.0/0` is in the IP whitelist
3. Verify connection string in `terraform.tfvars`

### Google Sign-In Not Working

**Error: redirect_uri_mismatch**
- Verify redirect URI in Google Console matches: `https://<cognito-domain>.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse`
- Get your Cognito domain: `terraform output cognito_domain`

**Google button not showing**
- Verify `google_client_id` is set in `terraform.tfvars`
- Run `terraform apply` to update Cognito
- Check provider exists:
  ```bash
  aws cognito-idp describe-identity-provider \
    --user-pool-id $(terraform output -raw cognito_user_pool_id) \
    --provider-name Google
  ```

## Cost Optimization

Current config is optimized for 10-50 users. Further savings:

**Use Fargate Spot** (saves $12/month):
```hcl
# In modules/ecs-service/main.tf
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 100
}
```

**Scale to zero at night** (saves $5-10/month):
```bash
# Scale down at 11 PM
aws ecs update-service --cluster lexiclab-prod --service api --desired-count 0

# Scale up at 7 AM
aws ecs update-service --cluster lexiclab-prod --service api --desired-count 1
```

**Minimum possible: ~$30-40/month** (Spot + off-hours scaling)

## Security

- Secrets stored in AWS Secrets Manager (never in code)
- IAM roles use least privilege
- VPC with security groups
- MongoDB protected by username/password + TLS
- Cognito with strong password policy
- Google OAuth uses industry-standard flow

## Cleanup

```bash
terraform destroy
```

Manually delete:
- S3 state bucket (if no longer needed)
- DynamoDB lock table
- ECR images (if repos not empty)

## Environment Variables

Automatically configured by Terraform:

**API:**
```bash
PORT=3000
NODE_ENV=production
AWS_REGION=eu-central-1
COGNITO_URL=https://<cognito-domain>.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=<auto-generated>
COGNITO_USER_POOL_ID=eu-central-1_<auto-generated>
# Secrets from Secrets Manager:
MONGODB_URL, JWT_AUTH_SECRET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
```

**UI:**
```bash
NODE_ENV=production
SERVER_API_URL=http://<alb-dns>/api
AWS_REGION=eu-central-1
COGNITO_URL=https://<cognito-domain>.auth.eu-central-1.amazoncognito.com
COGNITO_CLIENT_ID=<auto-generated>
COGNITO_USER_POOL_ID=eu-central-1_<auto-generated>
```

## Support

**Check logs first:**
```bash
aws logs tail /ecs/lexiclab-prod-api --follow
```

**Verify Terraform state:**
```bash
terraform show
```

**Test connectivity:**
```bash
curl $(terraform output -raw application_url)/api
```
