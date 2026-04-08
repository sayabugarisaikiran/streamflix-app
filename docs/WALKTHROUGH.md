# StreamFlix — Development Walkthrough & Changelog

This document summarizes everything that was built, why, and what changed from the original scaffold.

---

## App Rewrite Summary

The entire frontend was rewritten from a basic HTML page to a production-grade Netflix-style dark UI.

| Issue (Original) | Fix |
|---|---|
| No Google Fonts, no favicon | Added Inter font, inline SVG favicon |
| Only 4 basic cards, no architecture view | Added 8 sections: Hero, Architecture, Services, Route 53 Deep Dive, ALB, API Demo, WAF Demo, EC2 Banner |
| Relied on an external Unsplash URL for background | Replaced with animated particle canvas (works offline in S3) |
| No responsive design or mobile menu | Full responsive CSS with mobile hamburger |
| No animations or micro-interactions | Keyframe animations, scroll-reveal, stat counters |
| Basic alert-style API response | Terminal-style output with latency tracking |
| No WAF demo capability | Added 4 interactive WAF attack simulations |
| No DNS education tools | Interactive DNS Lookup Simulator with 10 scenarios |
| No routing policy explanation | 8 rich routing policy tiles with examples and config |
| No load balancing visibility | EC2 instance metadata banner showing Instance ID + AZ |

---

## Infrastructure Summary

### `terraform/main.tf` — Full Stack (S3 + CloudFront + WAF + ACM + Route53 + API GW + Lambda)
- S3 bucket with zero public access (OAC only)
- CloudFront distribution with custom cache policy
- WAF Web ACL: Rate limiting (100req/5min) + OWASP Common Rules + SQLi + Known Bad Inputs
- ACM certificate with automated DNS validation
- Route 53 ALIAS record → CloudFront
- API Gateway HTTP API (v2) with Lambda proxy integration
- Lambda Python 3.12 backend with `/hello` endpoint

### `terraform/alb/main.tf` — ALB + Lambda
- Application Load Balancer with HTTPS listener (TLS 1.3)
- HTTP → HTTPS redirect
- Lambda target group with `/health` endpoint
- Route 53 ALIAS + CNAME records to ALB
- Health check integration

### `terraform/ec2/main.tf` — EC2 + ALB + Route 53 Lab
- VPC with 2 public subnets in different AZs
- 2x EC2 instances (Amazon Linux 2023, t2.micro)
- ALB with HTTP listener and `/health` health checks
- Route 53 A Record (IP → DNS), ALIAS (DNS → ALB), CNAME (DNS → DNS)
- Instance metadata banner for visual load balancing confirmation

---

## Documentation

| Guide | File | Content |
|-------|------|---------|
| AWS Teaching Plan | `docs/01-aws-teaching-plan.md` | Complete 2-day workshop plan with teaching scripts, analogies, interview questions, WAF attack demos |
| Manual Console Lab | `docs/02-manual-lab-guide.md` | Step-by-step AWS Console instructions: S3 + CloudFront + WAF + ACM + Route 53 + API Gateway + Lambda |
| Route 53 & ALB Guide | `docs/03-route53-alb-guide.md` | Deep dive on all record types, CNAME vs ALIAS, 8 routing policies, ALB comparison table |
| EC2 + ALB Lab Guide | `docs/04-ec2-alb-lab-guide.md` | Hands-on: Launch EC2, create AMI, deploy ALB, map DNS, demonstrate load balancing + health checks |

---

## Final File Structure

```
streamflix-app/
├── README.md                         # Main repo docs with deployment guides
├── .gitignore
├── app/
│   ├── index.html                    # Main page (8 sections)
│   ├── styles.css                    # Full design system (1500+ lines)
│   ├── app.js                        # Particles, DNS simulator, API demo, WAF sim, EC2 banner
│   └── error.html                    # Custom 404 page
├── docs/
│   ├── 01-aws-teaching-plan.md       # Workshop plan + teaching scripts
│   ├── 02-manual-lab-guide.md        # Manual console deployment
│   ├── 03-route53-alb-guide.md       # Route 53 + ALB deep dive
│   └── 04-ec2-alb-lab-guide.md       # EC2 load balancing lab
└── terraform/
    ├── main.tf                       # S3 + CloudFront + WAF + ACM + Route53 + API GW + Lambda
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    ├── lambda/handler.py
    ├── alb/
    │   ├── main.tf                   # ALB + Lambda + Route 53
    │   └── alb_lambda.py
    └── ec2/
        ├── main.tf                   # EC2 + ALB + Route 53
        ├── user_data.sh
        └── deploy_to_ec2.sh
```
