# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# Target Group for API
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment}-api-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-api-tg"
    }
  )
}

# Target Group for UI
resource "aws_lb_target_group" "ui" {
  name        = "${var.project_name}-${var.environment}-ui-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/welcome"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ui-tg"
    }
  )
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  tags = var.tags
}

# HTTPS Listener (optional, requires ACM certificate)
resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  tags = var.tags
}

# Listener Rule for API by host (HTTP) - api.lexiclab.com
resource "aws_lb_listener_rule" "api_host_http" {
  count = var.api_domain != "" ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = [var.api_domain]
    }
  }

  tags = var.tags
}

# Listener Rule for API by host (HTTPS) - api.lexiclab.com
resource "aws_lb_listener_rule" "api_host_https" {
  count = var.enable_https && var.api_domain != "" ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = [var.api_domain]
    }
  }

  tags = var.tags
}
