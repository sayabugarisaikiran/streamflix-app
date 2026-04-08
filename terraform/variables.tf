variable "domain_name" {
  description = "Your registered Route 53 domain name (e.g., mydomain.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.domain_name))
    error_message = "Domain name must be a valid domain like 'mydomain.com'."
  }
}

variable "subdomain_prefix" {
  description = "Subdomain prefix (e.g., 'streamflix' creates streamflix.mydomain.com)"
  type        = string
  default     = "streamflix"
}

variable "aws_region" {
  description = "AWS Region — MUST be us-east-1 for CloudFront ACM certificates"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "CloudFront requires ACM certificates in us-east-1. Do not change this."
  }
}
