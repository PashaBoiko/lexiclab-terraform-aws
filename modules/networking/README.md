# Networking Module

This module creates a VPC with public and private subnets across multiple availability zones, along with NAT gateways for private subnet internet access.

## Resources Created

- VPC with DNS support enabled
- Internet Gateway
- Public subnets (one per AZ) - for ALB
- Private subnets (one per AZ) - for ECS tasks
- Elastic IPs for NAT Gateways
- NAT Gateways (one per AZ, or single for cost optimization)
- Route tables and associations

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  project_name       = "lexiclab"
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  single_nat_gateway = false  # true for dev, false for prod

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Outputs

- `vpc_id` - VPC ID
- `public_subnet_ids` - List of public subnet IDs (for ALB)
- `private_subnet_ids` - List of private subnet IDs (for ECS tasks)
- `nat_gateway_ips` - **CRITICAL**: Add these IPs to MongoDB Atlas IP whitelist

## IP Address Allocation

- VPC: 10.0.0.0/16
- Public subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- Private subnets: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24

## Cost Optimization

Set `single_nat_gateway = true` for development environments to reduce costs. This routes all private subnet traffic through a single NAT Gateway instead of one per AZ.

**Cost difference**: ~$65/month savings (1 NAT vs 3 NATs)
