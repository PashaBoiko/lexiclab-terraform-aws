# Application Load Balancer Module

This module creates an Application Load Balancer with path-based routing for API and UI services.

## Resources Created

- Application Load Balancer (internet-facing)
- Target groups for API and UI (both on port 3000)
- HTTP listener (port 80)
- HTTPS listener (port 443, optional with ACM certificate)
- Listener rules for path-based routing

## Routing Logic

- `/api/*` → API Target Group (NestJS backend)
- `/*` (default) → UI Target Group (React SSR frontend)

## Usage

```hcl
module "alb" {
  source = "./modules/alb"

  project_name       = "lexiclab"
  environment        = "prod"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]

  # Optional: Enable HTTPS
  certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/..."

  tags = {
    Project     = "lexiclab"
    Environment = "prod"
  }
}
```

## Health Checks

- **API**: `GET /api` - expects 200-299 response
- **UI**: `GET /` - expects 200-299 response
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy threshold**: 2 consecutive successes
- **Unhealthy threshold**: 3 consecutive failures

## SSL/TLS

To enable HTTPS, provide an ACM certificate ARN via the `certificate_arn` variable. The certificate must be in the same region as the ALB (eu-central-1).
