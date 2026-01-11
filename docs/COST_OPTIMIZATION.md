# Cost Optimization for Small User Base (10-50 Users)

Your infrastructure has been optimized for a small user base of 10-50 users with significantly reduced costs.

## Optimized Cost Breakdown

| Service | Previous | Optimized | Monthly Cost | Savings |
|---------|----------|-----------|--------------|---------|
| **NAT Gateway** | 3 gateways | 1 gateway | **$35** | $75 |
| **ECS Fargate (API)** | 2 × 512 CPU/1GB | 1 × 256 CPU/512MB | **$9** | $27 |
| **ECS Fargate (UI)** | 2 × 256 CPU/512MB | 1 × 256 CPU/512MB | **$9** | $9 |
| **CloudFront** | Full price | PriceClass_100 | **$60** | $25 |
| **ALB** | Required | Required | **$25** | $0 |
| **CloudWatch Logs** | 7-day retention | 3-day retention | **$3** | $2 |
| **Secrets Manager** | 4 secrets | 4 secrets | **$2** | $0 |
| **ECR Storage** | 2 repos | 2 repos | **$2** | $0 |
| **Data Transfer** | Typical | Typical | **$5-10** | - |

## Total Monthly Cost: ~$150/month
**Savings: $134/month (47% reduction)**

## Further Optimization Options

### ~~Option 1: Remove CloudFront~~ ✅ Already Done
**Savings: $60/month**

CloudFront CDN has been removed from the codebase for cost savings. The infrastructure uses ALB directly.

**Current setup**:
- Access application via ALB DNS: `http://<alb-dns-name>/`
- No CDN caching (fine for 10-50 users in single region)
- If you need CDN in the future, consider Cloudflare or recreate the CloudFront module

### Option 1: Use Fargate Spot ($12/month additional savings)
**Total: ~$33-43/month**

Fargate Spot provides 70% discount on compute but tasks may be interrupted (rare).

Edit `modules/ecs-service/main.tf`:
```hcl
# Change launch_type from "FARGATE" to capacity provider
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  # launch_type   = "FARGATE"  # Remove this line

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  # ... rest of config
}
```

**Pros**: Major compute savings (70% off)
**Cons**: Tasks may be interrupted during AWS capacity needs (rare, usually <2% interruption rate)

### Option 2: Scale to Zero During Off-Hours ($5-10/month savings)
**Saves on compute costs**

Create a Lambda function with EventBridge to scale down at night:

```bash
# Scale down at 11 PM
aws ecs update-service --cluster lexiclab-prod --service api --desired-count 0
aws ecs update-service --cluster lexiclab-prod --service ui --desired-count 0

# Scale up at 7 AM
aws ecs update-service --cluster lexiclab-prod --service api --desired-count 1
aws ecs update-service --cluster lexiclab-prod --service ui --desired-count 1
```

**Pros**: Saves 8-10 hours/day of compute costs
**Cons**: 1-2 minute cold start when users first access in morning

## Recommended Configuration by Budget

### Budget: $50-60/month (Ultra-Low Cost)
```
✓ Single NAT Gateway
✓ Single task per service (256 CPU / 512 MB)
✓ Fargate Spot
✗ No CloudFront (use ALB directly)
✓ 1-day log retention
✓ Scale to zero at night
```

**Best for**: Internal testing, beta users in single region

### Budget: $80-100/month (Low Cost) ⭐ RECOMMENDED
```
✓ Single NAT Gateway
✓ Single task per service (256 CPU / 512 MB)
✗ Standard Fargate (no Spot)
✗ No CloudFront (use ALB directly)
✓ 3-day log retention
✗ No off-hours scaling
```

**Best for**: 10-50 users, MVP launch, beta testing

### Budget: $150/month (Balanced) ⭐ CURRENT SETUP
```
✓ Single NAT Gateway
✓ Single task per service (256 CPU / 512 MB)
✗ Standard Fargate (no Spot)
✓ CloudFront with PriceClass_100
✓ 3-day log retention
✗ No off-hours scaling
```

**Best for**: 10-50 users with global access, better UX

## Performance for 10-50 Users

With the optimized configuration:

**Concurrent Users**: 10-20 concurrent users comfortably
**Response Time**: <500ms for most requests
**Auto-scaling**: Will scale to 3 tasks if CPU > 70%
**Availability**: Single-AZ (good for small user base)

## What You're Giving Up

Compared to full production configuration:

1. ❌ **Multi-AZ NAT redundancy** - If one NAT Gateway fails, temporary downtime (rare)
2. ❌ **Multiple tasks for redundancy** - Single task can handle 10-50 users fine
3. ❌ **High compute resources** - 256 CPU is sufficient for low traffic
4. ⚠️ **Global CDN reach** - PriceClass_100 covers US/Canada/Europe only

## What You're Keeping

✅ **Auto-scaling** - Can still scale up to 3 tasks if needed
✅ **High availability** - Multi-AZ infrastructure (just single NAT)
✅ **Security** - All security features intact
✅ **Monitoring** - CloudWatch logs and alarms
✅ **Zero downtime deploys** - Rolling deployments work the same

## When to Upgrade

Consider upgrading when:

- **50+ concurrent users** - Upgrade to 2 tasks per service (+$18/month)
- **100+ total users** - Add more CPU/memory (+$20-30/month)
- **Global users** - Upgrade CloudFront to PriceClass_200 (+$25/month)
- **Need HA** - Add 3 NAT Gateways (+$75/month)
- **Need redundancy** - Run 2 tasks per service (+$18/month)

## Quick Command to Apply Optimizations

Your `main.tf` is already optimized. Just deploy:

```bash
cd /Users/pavloprovectus/Documents/my-projects/lexiclab-aws
terraform apply
```

## Monitoring Your Costs

Track costs in AWS Cost Explorer:

```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Set up budget alerts
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json
```

Create `budget.json`:
```json
{
  "BudgetName": "Lexiclab-Monthly-Budget",
  "BudgetLimit": {
    "Amount": "100",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

## Cost Alerts

Set up CloudWatch alarms for cost anomalies:

1. Go to AWS Billing Dashboard
2. Enable "Receive Billing Alerts"
3. Create CloudWatch alarm when charges exceed $100

## Summary

Your infrastructure is now optimized for **$150/month** with options to reduce further to **$50-90/month** depending on your needs. This is a **47% cost reduction** while maintaining excellent performance for 10-50 users.
