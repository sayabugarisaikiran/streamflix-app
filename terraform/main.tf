# ================================================================
#  StreamFlix — AWS Infrastructure
#  Terraform Configuration
#
#  This deploys: S3 + CloudFront (OAC) + WAF + ACM + Route53
#                + API Gateway (HTTP) + Lambda
#
#  Usage:
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  full_domain = "${var.subdomain_prefix}.${var.domain_name}"
  app_path    = "${path.module}/../app"
}


# ==============================================================
# 1. ROUTE 53 — DNS Management
# ==============================================================
# Look up the existing hosted zone for the domain
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}


# ==============================================================
# 2. ACM — SSL/TLS Certificate (must be in us-east-1)
# ==============================================================
resource "aws_acm_certificate" "cert" {
  domain_name               = local.full_domain
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "StreamFlix"
  }
}

# Auto-create DNS validation records in Route 53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => dvo
  }

  allow_overwrite = true
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = [each.value.resource_record_value]
  ttl             = 60
}

# Wait for certificate to be validated
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# ==============================================================
# 3. S3 — Static File Storage (Private, zero-trust)
# ==============================================================
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket        = "streamflix-frontend-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Project = "StreamFlix"
  }
}

# Block ALL public access — only CloudFront can read via OAC
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload frontend files to S3
resource "aws_s3_object" "html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${local.app_path}/index.html"
  content_type = "text/html"
  etag         = filemd5("${local.app_path}/index.html")
}

resource "aws_s3_object" "css" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "styles.css"
  source       = "${local.app_path}/styles.css"
  content_type = "text/css"
  etag         = filemd5("${local.app_path}/styles.css")
}

resource "aws_s3_object" "js" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "app.js"
  source       = "${local.app_path}/app.js"
  content_type = "application/javascript"
  etag         = filemd5("${local.app_path}/app.js")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "error.html"
  source       = "${local.app_path}/error.html"
  content_type = "text/html"
  etag         = filemd5("${local.app_path}/error.html")
}


# ==============================================================
# 4. AWS WAF — Web Application Firewall (attached to CloudFront)
# ==============================================================
resource "aws_wafv2_web_acl" "main" {
  name        = "streamflix-waf"
  description = "WAF for StreamFlix: Rate limiting + OWASP Core Rules + SQLi + Known Bad Inputs"
  scope       = "CLOUDFRONT" # Must be CLOUDFRONT scope when attaching to a distribution

  default_action {
    allow {} # Allow by default, block only known threats
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "streamflix-waf-global"
    sampled_requests_enabled   = true
  }

  # Rule 1: Rate Limiting — Block IPs sending > 100 requests in 5 minutes
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed — Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedCommonRuleSet"
    priority = 2

    override_action {
      none {} # Use the rule group's own actions (Block/Count)
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed — Known Bad Inputs (Log4j, etc.)
  rule {
    name     = "AWSManagedKnownBadInputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed — SQL Injection Protection
  rule {
    name     = "AWSManagedSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Project = "StreamFlix"
  }
}


# ==============================================================
# 5. CLOUDFRONT — Global CDN with Origin Access Control
# ==============================================================
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "streamflix-oac"
  description                       = "OAC for StreamFlix S3 bucket (modern replacement for OAI)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache policy (recommended over deprecated forwarded_values)
resource "aws_cloudfront_cache_policy" "default" {
  name        = "streamflix-cache-policy"
  comment     = "Cache static assets aggressively"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip  = true
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "StreamFlix CDN"
  default_root_object = "index.html"
  aliases             = [local.full_domain]
  web_acl_id          = aws_wafv2_web_acl.main.arn
  price_class         = "PriceClass_All" # Use all edge locations

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-StreamFlix"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-StreamFlix"
    cache_policy_id        = aws_cloudfront_cache_policy.default.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Custom error page for 403/404
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = "StreamFlix"
  }
}

# S3 Bucket Policy — Only allow CloudFront via OAC
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Route 53 Alias → CloudFront
resource "aws_route53_record" "app_domain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}


# ==============================================================
# 6. LAMBDA — Serverless Backend
# ==============================================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "streamflix-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project = "StreamFlix"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "api_backend" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "streamflix-backend"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = "production"
      APP_NAME    = "StreamFlix"
    }
  }

  tags = {
    Project = "StreamFlix"
  }
}


# ==============================================================
# 7. API GATEWAY — HTTP API (v2, low-latency)
# ==============================================================
resource "aws_apigatewayv2_api" "http_api" {
  name          = "streamflix-api"
  protocol_type = "HTTP"
  description   = "StreamFlix backend API"

  cors_configuration {
    allow_origins = ["https://${local.full_domain}", "http://localhost:*", "http://127.0.0.1:*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "x-app-platform", "authorization"]
    max_age       = 300
  }

  tags = {
    Project = "StreamFlix"
  }
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/streamflix-api"
  retention_in_days = 7

  tags = {
    Project = "StreamFlix"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_hello" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
