# Monitoring Module

This module creates CloudWatch log groups and alarms for monitoring the infrastructure.

## Resources Created

### CloudWatch Log Groups
- `/ecs/lexiclab-prod-api` - API container logs
- `/ecs/lexiclab-prod-ui` - UI container logs
- Retention: 7 days (configurable)

### CloudWatch Alarms
- **API CPU High**: Triggers when CPU > 80% for 10 minutes
- **API Memory High**: Triggers when memory > 80% for 10 minutes
- **API Tasks Zero**: Triggers when no tasks are running
- **UI CPU High**: Triggers when CPU > 80% for 10 minutes
- **UI Memory High**: Triggers when memory > 80% for 10 minutes
- **UI Tasks Zero**: Triggers when no tasks are running
- **ALB 5xx Errors**: Triggers when 5xx error count > 10 in 2 minutes

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name     = "lexiclab"
  environment      = "prod"
  cluster_name     = module.ecs_cluster.cluster_name
  alb_arn_suffix   = split(":", module.alb.alb_arn)[5]

  log_retention_days = 7
  enable_alarms      = true

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Viewing Logs

### AWS CLI
```bash
# Tail API logs
aws logs tail /ecs/lexiclab-prod-api --follow

# Tail UI logs
aws logs tail /ecs/lexiclab-prod-ui --follow

# Filter logs by error
aws logs filter-log-events \
  --log-group-name /ecs/lexiclab-prod-api \
  --filter-pattern "ERROR"
```

### AWS Console
Navigate to CloudWatch → Log Groups → Select log group

## Alarm Actions

To add SNS notifications when alarms trigger:

```hcl
resource "aws_sns_topic" "alerts" {
  name = "lexiclab-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}

# Add to alarm
alarm_actions = [aws_sns_topic.alerts.arn]
```

## Cost Optimization

Log retention affects storage costs:
- 7 days: ~$0.50/month per 1GB
- 30 days: ~$2.00/month per 1GB
- 90 days: ~$6.00/month per 1GB

Set `log_retention_days` based on your compliance requirements.
