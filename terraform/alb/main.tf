# ================================================================
#  StreamFlix — ALB + Route 53 DNS Demo
#
#  This is a SEPARATE Terraform config to demonstrate:
#    1. Application Load Balancer (ALB) with target groups
#    2. Route 53 A Record (IP → DNS)
#    3. Route 53 CNAME (DNS → DNS)
#    4. Route 53 ALIAS (DNS → AWS Resource)
#    5. Health checks and failover
#
#  Usage:
#    cd terraform/alb
#    terraform init
#    terraform plan -var="domain_name=yourdomain.com"
#    terraform apply -var="domain_name=yourdomain.com"
# ================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "domain_name" {
  description = "Your Route 53 domain (e.g., mydomain.com)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for ALB deployment"
  type        = string
  default     = "us-east-1"
}

locals {
  api_domain = "api.${var.domain_name}"
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ==========================================
# 1. NETWORKING — VPC, Subnets, SG
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "streamflix-vpc", Project = "StreamFlix" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "streamflix-public-${count.index + 1}", Project = "StreamFlix" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamflix-igw", Project = "StreamFlix" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "streamflix-public-rt", Project = "StreamFlix" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB — Allow HTTP/HTTPS from internet
resource "aws_security_group" "alb_sg" {
  name        = "streamflix-alb-sg"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamflix-alb-sg", Project = "StreamFlix" }
}


# ==========================================
# 2. ACM CERTIFICATE for ALB
# ==========================================
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = local.api_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Project = "StreamFlix" }
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => dvo
  }
  allow_overwrite = true
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = [each.value.resource_record_value]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "alb_cert" {
  certificate_arn         = aws_acm_certificate.alb_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.alb_cert_validation : record.fqdn]
}


# ==========================================
# 3. APPLICATION LOAD BALANCER
# ==========================================
resource "aws_lb" "main" {
  name               = "streamflix-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = { Name = "streamflix-alb", Project = "StreamFlix" }
}

# ── Target Group (Lambda) ──
resource "aws_lb_target_group" "lambda_tg" {
  name        = "streamflix-lambda-tg"
  target_type = "lambda"

  health_check {
    enabled  = true
    path     = "/health"
    matcher  = "200"
    interval = 35
    timeout  = 30
  }

  tags = { Project = "StreamFlix" }
}

# ── Lambda Function (simple health/hello endpoint) ──
resource "aws_iam_role" "lambda_role" {
  name = "streamflix-alb-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Project = "StreamFlix" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "alb_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/alb_lambda.py"
  output_path = "${path.module}/alb_lambda.zip"
}

resource "aws_lambda_function" "alb_backend" {
  filename         = data.archive_file.alb_lambda_zip.output_path
  function_name    = "streamflix-alb-backend"
  role             = aws_iam_role.lambda_role.arn
  handler          = "alb_lambda.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.alb_lambda_zip.output_base64sha256
  timeout          = 10

  tags = { Project = "StreamFlix" }
}

# Allow ALB to invoke Lambda
resource "aws_lambda_permission" "alb_invoke" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_backend.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_tg.arn
}

# Attach Lambda to Target Group
resource "aws_lb_target_group_attachment" "lambda_attachment" {
  target_group_arn = aws_lb_target_group.lambda_tg.arn
  target_id        = aws_lambda_function.alb_backend.arn
  depends_on       = [aws_lambda_permission.alb_invoke]
}

# ── HTTPS Listener (port 443) ──
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb_cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_tg.arn
  }
}

# ── HTTP Listener (port 80) — Redirect to HTTPS ──
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


# ==========================================
# 4. ROUTE 53 — All DNS Mapping Demos
# ==========================================

# ── Demo 1: ALIAS Record → ALB (DNS → AWS Resource) ──
# This is the RECOMMENDED way to map a domain to an ALB.
# ALB has a dynamic DNS name, NOT a static IP. ALIAS resolves it automatically.
resource "aws_route53_record" "alias_to_alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.api_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true # Route 53 checks ALB health!
  }
}

# ── Demo 2: CNAME Record (DNS → DNS) ──
# Shows how a subdomain can point to another DNS name.
# Cannot be used at zone apex! Only for subdomains.
resource "aws_route53_record" "cname_demo" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "backend.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.main.dns_name] # Points to ALB's DNS name
}

# ── Demo 3: A Record (Domain → Static IP) ──
# Shows mapping a domain directly to an IP address.
# We use a dummy/example IP here — in real life, this would be an Elastic IP.
# UNCOMMENT the block below and replace with a real Elastic IP if you want to demo it live:
#
# resource "aws_route53_record" "a_record_demo" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "server.${var.domain_name}"
#   type    = "A"
#   ttl     = 300
#   records = ["YOUR_ELASTIC_IP_HERE"]  # e.g., "54.230.10.42"
# }


# ── Demo 4: Route 53 Health Check ──
# Monitors the ALB and can trigger failover routing
resource "aws_route53_health_check" "alb_health" {
  fqdn              = local.api_domain
  port               = 443
  type               = "HTTPS"
  resource_path      = "/health"
  failure_threshold  = 3
  request_interval   = 30
  measure_latency    = true

  tags = {
    Name    = "streamflix-alb-health"
    Project = "StreamFlix"
  }
}


# ==========================================
# OUTPUTS
# ==========================================
output "alb_dns_name" {
  description = "ALB DNS name (DNS → DNS target for CNAME or ALIAS)"
  value       = aws_lb.main.dns_name
}

output "api_url" {
  description = "The HTTPS URL for the ALB via Route 53 ALIAS"
  value       = "https://${local.api_domain}"
}

output "cname_demo_url" {
  description = "The CNAME demo URL"
  value       = "https://backend.${var.domain_name}"
}

output "dns_mapping_summary" {
  description = "DNS Mapping Summary for students"
  value       = <<-EOT

  ╔═══════════════════════════════════════════════════════════════════╗
  ║          Route 53 DNS Mapping Demonstrations                    ║
  ╠═══════════════════════════════════════════════════════════════════╣
  ║                                                                   ║
  ║  1. ALIAS (A Record → ALB):                                       ║
  ║     ${local.api_domain} → ${aws_lb.main.dns_name}                ║
  ║     (Resolves to ALB IPs automatically. FREE. Works at apex.)     ║
  ║                                                                   ║
  ║  2. CNAME (DNS → DNS):                                            ║
  ║     backend.${var.domain_name} → ${aws_lb.main.dns_name}         ║
  ║     (Points subdomain to ALB DNS. Costs $0.40/M queries.)         ║
  ║                                                                   ║
  ║  Verify with:                                                     ║
  ║     dig ${local.api_domain} A                                     ║
  ║     dig backend.${var.domain_name} CNAME                          ║
  ║                                                                   ║
  ╚═══════════════════════════════════════════════════════════════════╝
  EOT
}
