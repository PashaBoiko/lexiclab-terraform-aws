# Deployment Guide

This guide provides detailed deployment instructions for the Lexiclab AWS infrastructure.

## Pre-Deployment Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] Docker installed
- [ ] MongoDB Atlas cluster created
- [ ] AWS credentials with appropriate permissions
- [ ] Domain name (optional, for custom domain)
- [ ] ACM certificates requested (optional, for HTTPS)

## Step-by-Step Deployment

### Step 1: Prepare Configuration

1. **Clone the infrastructure repository**:
   ```bash
   cd /Users/pavloprovectus/Documents/my-projects/lexiclab-aws
   ```

2. **Create terraform.tfvars**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Fill in required values**:
   ```hcl
   # MongoDB Atlas (create cluster first at cloud.mongodb.com)
   mongodb_url = "mongodb+srv://username:password@cluster.mongodb.net/lexiclab"

   # Generate JWT secret
   # openssl rand -base64 32
   jwt_secret = "generated-secret-here"

   # AWS credentials for SES and S3
   ses_access_key_id     = "AKIA..."
   ses_secret_access_key = "..."
   s3_access_key_id      = "AKIA..."
   s3_secret_access_key  = "..."

   # Optional: ACM certificates for HTTPS
   acm_certificate_arn = ""
   ```

### Step 2: Initialize Terraform Backend

The Terraform state needs to be stored in S3 with DynamoDB locking.

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket lexiclab-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning for state history
aws s3api put-bucket-versioning \
  --bucket lexiclab-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket lexiclab-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name lexiclab-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply infrastructure
terraform apply
```

Review the plan carefully. Type `yes` to confirm deployment.

**Deployment time**: 10-15 minutes (NAT Gateways take the longest)

### Step 4: Configure MongoDB Atlas

After infrastructure deployment, you must whitelist the NAT Gateway IPs in MongoDB Atlas:

```bash
# Get the NAT Gateway IPs
terraform output nat_gateway_ips

# Output example:
# [
#   "3.123.45.67",
#   "18.195.89.12",
#   "52.57.234.56"
# ]
```

**Add IPs to MongoDB Atlas**:
1. Go to [MongoDB Atlas Console](https://cloud.mongodb.com)
2. Select your project and cluster
3. Navigate to **Network Access** → **IP Access List**
4. Click **Add IP Address**
5. Add each NAT Gateway IP individually
6. Click **Confirm**

**Important**: Without this step, your API containers cannot connect to MongoDB!

### Step 5: Build and Push Docker Images

The ECS services need Docker images in ECR before they can start.

```bash
# Run the build and push script
./scripts/build-and-push.sh
```

This script will:
1. Authenticate Docker to ECR
2. Build the NestJS API image from `../lexiclab-nest-api/`
3. Build the React UI image from `../lexiclab-ui-react/`
4. Tag images with `latest` and git commit hash
5. Push images to ECR

**Build time**: 5-10 minutes (depending on Docker cache)

### Step 6: Verify Deployment

#### Check ECS Services

```bash
# Get cluster and service names
CLUSTER=$(terraform output -raw ecs_cluster_name)
API_SERVICE=$(terraform output -raw api_service_name)
UI_SERVICE=$(terraform output -raw ui_service_name)

# Check service status
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $API_SERVICE $UI_SERVICE \
  --query 'services[*].[serviceName,runningCount,desiredCount,deployments[0].status]' \
  --output table
```

Expected output:
```
-----------------------------------
|       DescribeServices          |
+------+---+---+------------------+
| api  | 2 | 2 | PRIMARY          |
| ui   | 2 | 2 | PRIMARY          |
+------+---+---+------------------+
```

#### Check ALB Target Health

```bash
# Get target group ARNs
API_TG=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.alb") | .resources[] | select(.name=="api") | .values.arn')

# Check target health
aws elbv2 describe-target-health --target-group-arn $API_TG
```

Expected: All targets should show `State: healthy`

#### Test Application

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw application_url)

# Test API
curl $ALB_URL/api

# Test UI
curl -I $ALB_URL/
```

Expected: HTTP 200 responses

#### View Logs

```bash
# Stream API logs
aws logs tail /ecs/lexiclab-prod-api --follow

# Stream UI logs in another terminal
aws logs tail /ecs/lexiclab-prod-ui --follow
```

## Post-Deployment Configuration

### Optional: Configure Custom Domain

If you have a custom domain (e.g., `lexiclab.com`):

1. **Request ACM Certificate**:
   ```bash
   # For ALB (in eu-central-1)
   aws acm request-certificate \
     --domain-name lexiclab.com \
     --subject-alternative-names '*.lexiclab.com' \
     --validation-method DNS \
     --region eu-central-1
   ```

2. **Validate certificate** via DNS (add CNAME records)

3. **Update terraform.tfvars**:
   ```hcl
   acm_certificate_arn = "arn:aws:acm:eu-central-1:..."
   ```

4. **Apply changes**:
   ```bash
   terraform apply
   ```

5. **Create Route 53 records** (if using Route 53):
   ```bash
   # Create hosted zone
   aws route53 create-hosted-zone --name lexiclab.com --caller-reference $(date +%s)

   # Add ALB alias record (requires manual configuration or additional Terraform)
   ```

### Optional: Enable CloudWatch Alarms Notifications

1. **Create SNS topic**:
   ```bash
   aws sns create-topic --name lexiclab-alerts
   ```

2. **Subscribe to email**:
   ```bash
   aws sns subscribe \
     --topic-arn arn:aws:sns:eu-central-1:ACCOUNT_ID:lexiclab-alerts \
     --protocol email \
     --notification-endpoint your-email@example.com
   ```

3. **Confirm subscription** (check your email)

4. **Update alarms** to send to SNS topic (requires Terraform modification)

## Updating the Deployment

### Application Code Changes

When you modify the NestJS API or React UI code:

```bash
# 1. Build and push new images
./scripts/build-and-push.sh

# 2. Force ECS to deploy new images
./scripts/update-task.sh

# 3. Monitor deployment
aws ecs describe-services --cluster lexiclab-prod --services api ui
```

### Infrastructure Changes

When you modify Terraform code:

```bash
# 1. Plan changes
terraform plan

# 2. Apply changes
terraform apply

# Note: Some changes may require redeploying containers
```

### Updating Secrets

To update secrets without changing Terraform:

```bash
# Update via AWS CLI
aws secretsmanager update-secret \
  --secret-id lexiclab/prod/mongodb-url \
  --secret-string "new-connection-string"

# Force ECS to restart tasks (to pick up new secrets)
./scripts/update-task.sh
```

## Rollback Procedures

### Rollback Docker Images

If a new image causes issues:

```bash
# 1. List recent images
aws ecr describe-images \
  --repository-name lexiclab-prod-api \
  --query 'sort_by(imageDetails,&imagePushedAt)[-5:]' \
  --output table

# 2. Note the imageDigest or imageTag of the previous good version

# 3. Update ECS service to use specific tag
aws ecs update-service \
  --cluster lexiclab-prod \
  --service api \
  --task-definition lexiclab-prod-api:PREVIOUS_REVISION

# Or rebuild and push the previous git commit
cd ../lexiclab-nest-api
git checkout PREVIOUS_COMMIT
# Then run build-and-push.sh
```

### Rollback Infrastructure

```bash
# Use Terraform state history
terraform state pull > current-state.json

# Rollback to previous state
terraform apply -target=module.specific_module
```

## Monitoring Deployment Health

### CloudWatch Dashboards

Create a custom dashboard to monitor all services:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name Lexiclab \
  --dashboard-body file://cloudwatch-dashboard.json
```

### Key Metrics to Monitor

- **ECS Service**: RunningTaskCount, CPUUtilization, MemoryUtilization
- **ALB**: TargetResponseTime, HTTPCode_Target_5XX_Count, RequestCount

## Backup and Disaster Recovery

### State Backup

Terraform state is automatically versioned in S3. To restore:

```bash
# List versions
aws s3api list-object-versions --bucket lexiclab-terraform-state

# Download specific version
aws s3api get-object \
  --bucket lexiclab-terraform-state \
  --key prod/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.backup
```

### Database Backup

MongoDB Atlas handles automatic backups. Configure in Atlas Console:
- Continuous backups (point-in-time recovery)
- Snapshot schedules
- Backup retention

### Disaster Recovery Plan

1. **Region Failure**: Redeploy in different region (requires new Terraform workspace)
2. **Data Loss**: Restore from MongoDB Atlas backup
3. **Infrastructure Corruption**: Restore Terraform state from S3 version history

## Next Steps

- Configure CloudWatch alerting via SNS
- Set up CI/CD pipeline (GitHub Actions, GitLab CI)
- Implement blue-green deployments
- Add WAF rules to ALB (optional)
- Configure custom domain and HTTPS
- Set up automated backups
