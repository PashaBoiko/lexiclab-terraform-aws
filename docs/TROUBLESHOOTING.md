# Troubleshooting Guide

Common issues and solutions for Lexiclab AWS infrastructure.

## Table of Contents

- [ECS Tasks Not Starting](#ecs-tasks-not-starting)
- [ALB Returning 503 Errors](#alb-returning-503-errors)
- [MongoDB Connection Failures](#mongodb-connection-failures)
- [High Costs](#high-costs)
- [Performance Issues](#performance-issues)
- [Secrets and Authentication](#secrets-and-authentication)

---

## ECS Tasks Not Starting

### Symptom
ECS services show desired count but running count is 0.

### Diagnosis

```bash
# Check service events
aws ecs describe-services \
  --cluster lexiclab-prod \
  --services api \
  --query 'services[0].events[0:5]' \
  --output table

# Check task failures
aws ecs list-tasks \
  --cluster lexiclab-prod \
  --service-name api \
  --desired-status STOPPED

# Get stopped task details
aws ecs describe-tasks \
  --cluster lexiclab-prod \
  --tasks <task-id> \
  --query 'tasks[0].{StoppedReason:stoppedReason,Containers:containers[*].[name,reason]}'
```

### Common Causes & Solutions

#### 1. IAM Permission Issues

**Error**: "CannotPullContainerError: Unable to pull secrets"

**Solution**:
```bash
# Check task execution role has Secrets Manager permissions
aws iam get-role-policy \
  --role-name lexiclab-prod-ecs-task-execution-role \
  --policy-name lexiclab-prod-ecs-secrets-policy

# Verify secrets exist
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `lexiclab`)].Name'
```

#### 2. Invalid Docker Image

**Error**: "CannotPullContainerError: image not found"

**Solution**:
```bash
# Check if images exist in ECR
aws ecr describe-images \
  --repository-name lexiclab-prod-api \
  --query 'imageDetails[*].imageTags' \
  --output table

# If empty, build and push images
./scripts/build-and-push.sh
```

#### 3. Insufficient Resources

**Error**: "No container instances found in cluster"

**Solution**: Fargate doesn't require container instances. Check if:
- VPC has available IP addresses
- Subnets are correct (should be private subnets)
- Security groups allow outbound traffic

```bash
# Check subnet IP availability
aws ec2 describe-subnets \
  --subnet-ids $(terraform output -json private_subnet_ids | jq -r '.[]') \
  --query 'Subnets[*].[SubnetId,AvailableIpAddressCount]' \
  --output table
```

#### 4. Container Health Check Failing

**Error**: "Essential container exited"

**Solution**:
```bash
# Check CloudWatch logs for application errors
aws logs tail /ecs/lexiclab-prod-api --since 10m

# Common issues:
# - Missing environment variables
# - Database connection failure
# - Port mismatch (should be 3000)
```

---

## ALB Returning 503 Errors

### Symptom
`curl http://<alb-dns>` returns 503 Service Unavailable

### Diagnosis

```bash
# Check target health
ALB_ARN=$(terraform output -raw alb_arn)
TG_ARNS=$(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query 'TargetGroups[*].TargetGroupArn' --output text)

for TG in $TG_ARNS; do
  echo "Target Group: $TG"
  aws elbv2 describe-target-health --target-group-arn $TG
done
```

### Common Causes & Solutions

#### 1. No Healthy Targets

**Status**: All targets show "unhealthy" or "initial"

**Solution**:
```bash
# Check why targets are unhealthy
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

# Common reasons:
# - "Target.FailedHealthChecks": Container not responding on health check path
# - "Target.NotRegistered": ECS service not running
# - "Target.InvalidState": Security group blocking traffic
```

**Fix health check path**:
- API: Must respond to `GET /api` with 200
- UI: Must respond to `GET /` with 200

#### 2. Security Group Blocking Traffic

**Solution**:
```bash
# Verify security group rules
API_SG=$(terraform output -json | jq -r '.ecs_api_security_group_id.value')
ALB_SG=$(terraform output -json | jq -r '.alb_security_group_id.value')

# API must allow traffic from ALB on port 3000
aws ec2 describe-security-groups --group-ids $API_SG \
  --query 'SecurityGroups[0].IpPermissions'
```

**Fix**: Ensure ingress rule allows ALB security group → ECS on port 3000

#### 3. ECS Tasks Not Running

**Solution**: See [ECS Tasks Not Starting](#ecs-tasks-not-starting)

---

## MongoDB Connection Failures

### Symptom
API logs show: "MongoNetworkError: connection timed out" or "MongooseServerSelectionError"

### Diagnosis

```bash
# Check API logs
aws logs tail /ecs/lexiclab-prod-api --since 5m | grep -i mongo

# Verify NAT Gateway IPs
terraform output nat_gateway_ips
```

### Solutions

#### 1. NAT Gateway IPs Not Whitelisted

**Most Common Cause**

**Solution**:
1. Get NAT Gateway IPs: `terraform output nat_gateway_ips`
2. Go to MongoDB Atlas → Network Access
3. Add each IP to the IP Access List
4. Wait 1-2 minutes for changes to propagate
5. Restart ECS tasks: `./scripts/update-task.sh`

#### 2. Invalid Connection String

**Solution**:
```bash
# Check if secret is correctly formatted
aws secretsmanager get-secret-value \
  --secret-id lexiclab/prod/mongodb-url \
  --query SecretString \
  --output text

# Format should be:
# mongodb+srv://username:password@cluster.mongodb.net/database?retryWrites=true&w=majority
```

#### 3. MongoDB Atlas Cluster Paused

**Solution**:
- Go to MongoDB Atlas Console
- Check if cluster is active (not paused)
- Resume cluster if paused

#### 4. Network Connectivity

**Solution**:
```bash
# Test from within VPC (launch temporary EC2 instance in private subnet)
# Or use VPC Reachability Analyzer

# Check NAT Gateway is routing correctly
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Project,Values=lexiclab" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table
```

---

## High Costs

### Symptom
AWS bill higher than expected

### Diagnosis

```bash
# Check most expensive services
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Check NAT Gateway data transfer (often the highest cost)
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

### Cost Optimization Solutions

#### 1. Reduce NAT Gateway Costs (~$110/month → ~$35/month)

**For Development**:
```hcl
# In main.tf, set:
single_nat_gateway = true  # Use 1 instead of 3
```

**Savings**: ~$65/month

#### 2. Use Fargate Spot (~$54/month → ~$16/month)

```hcl
# In ECS service configuration
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 100
}
```

**Savings**: ~70% on compute costs
**Risk**: Tasks may be interrupted (rare, acceptable for dev)

#### 3. Scale Down During Off-Hours

```bash
# Reduce task count at night (automate with Lambda)
aws ecs update-service \
  --cluster lexiclab-prod \
  --service api \
  --desired-count 1

# Scale back up in morning
aws ecs update-service \
  --cluster lexiclab-prod \
  --service api \
  --desired-count 2
```

#### 4. Reduce CloudWatch Log Retention

```hcl
# In modules/monitoring/main.tf
retention_in_days = 1  # Instead of 7
```

**Savings**: ~$4/month per 10GB logs

---

## Performance Issues

### Symptom
Slow response times or high CPU/memory usage

### Diagnosis

```bash
# Check ECS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=lexiclab-prod Name=ServiceName,Value=api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check ALB response times
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Solutions

#### 1. Increase CPU/Memory

```hcl
# In main.tf, increase resources for API
cpu    = 1024  # Instead of 512
memory = 2048  # Instead of 1024
```

**Note**: Valid CPU/memory combinations in Fargate:
- 256 CPU: 512-2048 MB
- 512 CPU: 1024-4096 MB
- 1024 CPU: 2048-8192 MB

#### 2. Increase Task Count

```hcl
desired_count = 4  # Instead of 2
max_capacity  = 20 # Instead of 10
```

#### 3. Optimize Auto Scaling

```hcl
# Lower target utilization for faster scaling
cpu_target_value    = 60  # Instead of 70
memory_target_value = 70  # Instead of 80
```

---

## Secrets and Authentication

### Symptom
Authentication errors or "secret not found"

### Diagnosis

```bash
# List all secrets
aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name, `lexiclab`)].Name'

# Get secret value (check if it's correct)
aws secretsmanager get-secret-value \
  --secret-id lexiclab/prod/mongodb-url \
  --query SecretString \
  --output text
```

### Solutions

#### 1. Secret Not Found

```bash
# Create missing secret
aws secretsmanager create-secret \
  --name lexiclab/prod/mongodb-url \
  --secret-string "mongodb+srv://..."

# Or use the script
./scripts/create-secrets.sh
```

#### 2. ECS Can't Access Secret

```bash
# Verify task execution role has permission
aws iam get-role-policy \
  --role-name lexiclab-prod-ecs-task-execution-role \
  --policy-name lexiclab-prod-ecs-secrets-policy

# Should allow secretsmanager:GetSecretValue
```

#### 3. JWT Authentication Failing

```bash
# Regenerate JWT secret
NEW_JWT=$(openssl rand -base64 32)

# Update secret
aws secretsmanager update-secret \
  --secret-id lexiclab/prod/jwt-secret \
  --secret-string "$NEW_JWT"

# Restart tasks to pick up new secret
./scripts/update-task.sh
```

---

## Getting Help

### Check Logs First

```bash
# API application logs
aws logs tail /ecs/lexiclab-prod-api --follow --filter-pattern "ERROR"

# UI application logs
aws logs tail /ecs/lexiclab-prod-ui --follow
```

### Use AWS X-Ray (if enabled)

```bash
# View traces
aws xray get-service-graph \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

### Check AWS Service Health

Visit [AWS Service Health Dashboard](https://status.aws.amazon.com/) for regional outages.

### Contact Support

For persistent issues:
1. Collect logs: `aws logs filter-log-events --log-group-name /ecs/lexiclab-prod-api --start-time 1hour`
2. Note error messages and timestamps
3. Check Terraform state: `terraform show`
4. Review CloudWatch metrics
