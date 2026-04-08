# 🎬 StreamFlix — AWS Cloud Training Lab

A production-grade demo application for teaching AWS cloud services hands-on. Students deploy a Netflix-style app and learn **S3, CloudFront, WAF, Route 53, ACM, ALB, API Gateway, and Lambda** through real infrastructure.

![AWS Services](https://img.shields.io/badge/AWS-S3%20%7C%20CloudFront%20%7C%20WAF%20%7C%20Route53%20%7C%20ACM%20%7C%20ALB%20%7C%20API%20GW%20%7C%20Lambda-FF9900?style=for-the-badge&logo=amazonaws)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform)

---

## 📋 What's Inside

| Component | Description |
|-----------|-------------|
| **Frontend App** (`app/`) | Dark-themed Netflix-style UI with interactive AWS demos |
| **Static Hosting** (`terraform/main.tf`) | S3 + CloudFront + WAF + ACM + Route 53 + API GW + Lambda |
| **ALB Module** (`terraform/alb/`) | Application Load Balancer with Lambda target group |
| **EC2 Lab** (`terraform/ec2/`) | EC2 + ALB + Route 53 hands-on (load balancing, DNS mapping) |
| **Teaching Guides** (`docs/`) | 5 detailed guides: teaching plan, manual labs, Route 53, ALB, walkthrough |

### App Features
- 🔍 **Interactive DNS Simulator** — 10 `dig`-style scenarios showing how DNS resolution works
- 🗂️ **Route 53 Deep Dive** — Visual cards for all record types (A, AAAA, CNAME, ALIAS, MX, TXT, NS, SOA, CAA, SRV)
- 🚦 **8 Routing Policies** — Rich tiles with How It Works, Real-World Examples, AWS Console Config
- ⚖️ **ALB Architecture** — Visual flow diagrams, health checks, path-based routing
- 🛡️ **WAF Attack Simulator** — SQL injection, XSS, rate limiting demos
- ⚡ **Live API Demo** — Hit a real API Gateway → Lambda endpoint
- 🖥️ **EC2 Instance Banner** — Shows Instance ID + AZ when running on EC2 (for load balancing demos)

---

## 🏗️ Architecture

```
┌──────┐    ┌───────────┐    ┌─────┐    ┌───────────┐    ┌──────────┐    ┌────────┐
│ User │───►│ Route 53  │───►│ WAF │───►│CloudFront │───►│    S3    │    │ Lambda │
│      │    │(DNS ALIAS)│    │     │    │   (CDN)   │    │ (Static) │    │(Backend│
└──────┘    └───────────┘    └─────┘    └───────────┘    └──────────┘    └────────┘
                                              │                              ▲
                                              │         ┌─────────────┐      │
                                              └────────►│ API Gateway │──────┘
                                                        │  (HTTP API) │
                                                        └─────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with admin permissions
- **AWS CLI** configured (`aws configure`)
- **Terraform** >= 1.5.0 installed
- **Domain name** registered in Route 53 (for DNS/ACM labs)
- **EC2 Key Pair** created (for EC2 lab only)

### Option A: Open Locally (No AWS needed)

Just open the app in a browser to explore the UI and interactive tools:

```bash
git clone https://github.com/sayabugarisaikiran/streamflix-app.git
cd streamflix-app
open app/index.html      # macOS
# or: xdg-open app/index.html   # Linux
# or: start app/index.html       # Windows
```

> The DNS Simulator, Routing Policy cards, and WAF demo all work locally — no AWS required.

---

## ☁️ Deployment Guide

### Lab 1: Full Stack — S3 + CloudFront + WAF + ACM + Route 53 + API Gateway + Lambda

This deploys the static site on S3, serves it through CloudFront CDN with WAF protection, secures it with an ACM SSL certificate, and maps it to your custom domain via Route 53. A Lambda backend is exposed through API Gateway.

#### Step 1: Configure

```bash
cd terraform

# Create your config
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
domain_name      = "yourdomain.com"     # Your Route 53 registered domain
subdomain_prefix = "streamflix"          # Creates streamflix.yourdomain.com
aws_region       = "us-east-1"          # MUST be us-east-1 (CloudFront + ACM requirement)
```

#### Step 2: Deploy

```bash
terraform init
terraform plan        # Review what will be created
terraform apply       # Type 'yes' to confirm
```

> ⏱ **Takes ~5-10 minutes.** ACM certificate validation and CloudFront distribution creation are the slowest steps.

#### Step 3: Connect the API

After `terraform apply` completes, grab the API Gateway URL from the output:

```bash
# Get the API URL
terraform output api_gateway_url
# → https://abc123.execute-api.us-east-1.amazonaws.com/prod/hello
```

Update `app/app.js` line 9 with this URL:
```javascript
const API_GATEWAY_URL = 'https://abc123.execute-api.us-east-1.amazonaws.com/prod/hello';
```

Re-upload and invalidate cache:
```bash
# Upload updated JS
aws s3 cp ../app/app.js s3://$(terraform output -raw s3_bucket_name)/

# Clear CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

#### Step 4: Verify

```bash
# Visit your site
open https://streamflix.yourdomain.com

# Test the API
curl https://streamflix.yourdomain.com  # Should return the HTML page
curl $(terraform output -raw api_gateway_url)  # Should return JSON
```

#### What Gets Created

| AWS Service | Resource | Purpose |
|-------------|----------|---------|
| **Route 53** | Hosted Zone lookup + ALIAS record | Maps `streamflix.yourdomain.com` → CloudFront |
| **ACM** | SSL Certificate + DNS validation | HTTPS encryption (auto-validated via Route 53) |
| **S3** | Private bucket + OAC policy | Stores HTML, CSS, JS (no public access) |
| **CloudFront** | Distribution + Cache Policy | Global CDN, edge caching, HTTPS redirect |
| **WAF** | Web ACL (4 rules) | Rate limiting, OWASP rules, SQLi, bad inputs |
| **Lambda** | Python 3.12 function | Backend API (`/hello` endpoint) |
| **API Gateway** | HTTP API v2 + CORS | RESTful endpoint with Lambda integration |

#### Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

---

### Lab 2: EC2 + ALB + Route 53 (Load Balancing & DNS Mapping)

This is the hands-on lab where students see real load balancing and DNS mapping in action. Two EC2 instances run the StreamFlix app, fronted by an ALB. Students observe the instance ID changing in the green banner as the ALB distributes traffic.

#### What Students Learn

1. **A Record** — Map an IP address to a domain name (`server1.yourdomain.com → 54.230.10.42`)
2. **ALIAS Record** — Map a domain to an ALB (`app.yourdomain.com → ALB`)
3. **CNAME Record** — Map a domain to another domain (`www.yourdomain.com → app.yourdomain.com`)
4. **Load Balancing** — Refresh the page and watch the Instance ID change
5. **Health Checks** — Stop one instance, watch ALB failover to the other

#### Step 1: Configure

```bash
cd terraform/ec2

# Create your config
cat > terraform.tfvars <<EOF
key_pair_name = "your-key-pair-name"    # EC2 Key Pair (create in AWS Console first)
domain_name   = "yourdomain.com"        # Leave "" to skip DNS
aws_region    = "us-east-1"
EOF
```

#### Step 2: Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

> ⏱ **Takes ~3-5 minutes.**

#### Step 3: Deploy the App to EC2 Instances

```bash
# Get instance IPs
IP1=$(terraform output -raw ec2_instance_1_public_ip)
IP2=$(terraform output -raw ec2_instance_2_public_ip)

# Deploy app files to both instances
chmod +x deploy_to_ec2.sh
./deploy_to_ec2.sh ~/.ssh/your-key.pem $IP1 $IP2
```

#### Step 4: Demo to Students

```bash
# 1. Visit Instance 1 directly — note the Instance ID in the green banner
open http://$IP1

# 2. Visit Instance 2 directly — DIFFERENT Instance ID!
open http://$IP2

# 3. Visit via ALB — refresh multiple times, watch Instance ID alternate!
ALB=$(terraform output -raw alb_dns_name)
open http://$ALB

# 4. Prove it with curl:
for i in {1..6}; do
  echo "Request $i: $(curl -s http://$ALB/metadata.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"instance_id\"]} in {d[\"availability_zone\"]}')")"
done
# Output:
#   Request 1: i-abc123 in us-east-1a
#   Request 2: i-def456 in us-east-1b
#   Request 3: i-abc123 in us-east-1a
#   ...
```

#### Step 5: DNS Mapping (if domain configured)

```bash
# Verify DNS records
dig server1.yourdomain.com A +short     # → EC2 IP (A Record)
dig app.yourdomain.com A +short          # → ALB IPs (ALIAS)
dig www.yourdomain.com CNAME +short      # → app.yourdomain.com (CNAME)

# Visit via domain
open http://server1.yourdomain.com    # Always hits Instance 1
open http://app.yourdomain.com         # Load balanced (Instance ID changes)
open http://www.yourdomain.com         # Same as app (CNAME → ALIAS → ALB)
```

#### Step 6: Health Check Demo

1. Go to **EC2 Console** → Stop Instance 2
2. Go to **Target Groups** → Watch status: `healthy → draining → unhealthy`
3. **All traffic now goes to Instance 1!**
4. Start Instance 2 again → watch it become `healthy`

#### What Gets Created

| AWS Service | Resource | Purpose |
|-------------|----------|---------|
| **VPC** | 10.0.0.0/16 + 2 public subnets | Network isolation |
| **EC2** | 2x t2.micro (Amazon Linux 2023) | Web servers running nginx |
| **ALB** | Internet-facing + HTTP listener | Distributes traffic across instances |
| **Target Group** | HTTP:80 + `/health` check | Monitors instance health |
| **Security Groups** | EC2 SG + ALB SG | Port 80/443 from internet, port 22 for SSH |
| **Route 53** | A + ALIAS + CNAME records | DNS mapping demos (if domain provided) |

#### Cleanup

```bash
cd terraform/ec2
terraform destroy -auto-approve
```

---

### Lab 3: ALB with Lambda (Serverless)

An alternative ALB setup using Lambda as the target instead of EC2.

```bash
cd terraform/alb

# Edit main.tf — set your domain_name and hosted_zone_id
terraform init
terraform apply
```

---

## 📁 Project Structure

```
streamflix-app/
├── README.md
├── .gitignore
│
├── app/                          # Frontend Application
│   ├── index.html                # Main page — all sections
│   ├── styles.css                # Dark theme + all component styles
│   ├── app.js                    # DNS simulator, API demo, EC2 banner
│   └── error.html                # Custom 404/403 error page
│
├── docs/                         # Teaching Guides & Lab Manuals
│   ├── 01-aws-teaching-plan.md   # 2-day workshop plan, teaching scripts, analogies
│   ├── 02-manual-lab-guide.md    # Step-by-step AWS Console lab (S3+CF+WAF+ACM+R53+APIGW+Lambda)
│   ├── 03-route53-alb-guide.md   # Route 53 deep dive + ALB comparison + interview Qs
│   ├── 04-ec2-alb-lab-guide.md   # EC2 + ALB + Route 53 load balancing lab
│   └── WALKTHROUGH.md            # Dev changelog — what was built and why
│
└── terraform/                    # Infrastructure as Code
    ├── main.tf                   # Lab 1: S3 + CloudFront + WAF + ACM + Route53 + API GW + Lambda
    ├── variables.tf              # Input variables
    ├── outputs.tf                # Post-deployment info
    ├── terraform.tfvars.example  # Template config
    │
    ├── lambda/
    │   └── handler.py            # API Gateway Lambda backend
    │
    ├── alb/
    │   ├── main.tf               # Lab 3: ALB + Lambda target + Route 53
    │   └── alb_lambda.py         # ALB-compatible Lambda handler
    │
    └── ec2/
        ├── main.tf               # Lab 2: VPC + EC2 + ALB + Route 53
        ├── user_data.sh          # EC2 bootstrap (nginx + metadata)
        └── deploy_to_ec2.sh      # SCP app files to instances
```

---

## 📖 Teaching Guides (in `docs/`)

| # | Guide | What's Inside |
|---|-------|---------------|
| 01 | [AWS Teaching Plan](docs/01-aws-teaching-plan.md) | Complete 2-day workshop plan with teaching scripts, real-world analogies, WAF attack demos, interview questions, resume project ideas |
| 02 | [Manual Console Lab](docs/02-manual-lab-guide.md) | Step-by-step AWS Console walkthrough: S3 → ACM → CloudFront (OAC) → WAF → Route 53 → API Gateway → Lambda — no Terraform needed |
| 03 | [Route 53 & ALB Guide](docs/03-route53-alb-guide.md) | Deep dive on all DNS record types, CNAME vs ALIAS comparison table, all 8 routing policies explained, ALB vs NLB vs CLB comparison |
| 04 | [EC2 + ALB Lab](docs/04-ec2-alb-lab-guide.md) | Hands-on lab: Launch EC2, create AMI, deploy second instance, create ALB, map Route 53 A/ALIAS/CNAME records, demonstrate load balancing + health check failover |
| — | [Walkthrough](docs/WALKTHROUGH.md) | Development changelog: what was rewritten, all infrastructure modules, final file structure |

---

## 💰 Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| S3 | ~$0.01/month | Tiny static files |
| CloudFront | ~$0/month | Free tier: 1TB transfer |
| WAF | ~$6/month | $5 Web ACL + $1/rule |
| ACM | **Free** | SSL certs are free in AWS |
| Route 53 | $0.50/month | Per hosted zone |
| API Gateway | ~$0/month | Free tier: 1M requests |
| Lambda | ~$0/month | Free tier: 1M requests |
| ALB | ~$16/month | $0.0225/hour + LCU |
| EC2 (t2.micro x2) | ~$0-16/month | Free tier eligible |

> ⚠️ **Total: ~$6/month (static site only) or ~$22/month (with EC2 + ALB).** Destroy resources after each lab session to avoid charges!

---

## 🧹 Full Cleanup

Run these in order to destroy everything:

```bash
# Destroy EC2 Lab
cd terraform/ec2
terraform destroy -auto-approve

# Destroy ALB Lambda Lab
cd ../alb
terraform destroy -auto-approve

# Destroy Main Stack (S3 + CloudFront + WAF + ACM)
cd ..
terraform destroy -auto-approve
```

**Manual cleanup checklist:**
- [ ] Route 53 records deleted
- [ ] CloudFront distribution disabled and deleted
- [ ] S3 bucket emptied and deleted
- [ ] WAF Web ACL deleted
- [ ] ACM Certificate deleted
- [ ] ALB + Target Groups deleted
- [ ] EC2 instances terminated
- [ ] AMIs and snapshots deleted
- [ ] VPC and security groups deleted

---

## 📚 AWS Services Covered

| Service | What Students Learn |
|---------|-------------------|
| **S3** | Static hosting, bucket policies, OAC, versioning |
| **CloudFront** | CDN, edge locations, cache policies, OAC vs OAI |
| **WAF** | Rate limiting, OWASP rules, SQL injection protection |
| **Route 53** | A/AAAA/CNAME/ALIAS records, 8 routing policies, hosted zones |
| **ACM** | SSL certificates, DNS validation, TLS 1.2/1.3 |
| **ALB** | Load balancing, target groups, health checks, listeners |
| **API Gateway** | HTTP API, Lambda integration, CORS, stages |
| **Lambda** | Serverless compute, Python runtime, IAM roles |
| **EC2** | Instances, AMIs, key pairs, user data, security groups |
| **VPC** | Subnets, internet gateway, route tables, availability zones |

---

## 🎓 For Trainers

This lab is designed for a **2-day AWS training workshop:**

**Day 1: Static Hosting + Security**
- S3 bucket creation and file upload
- CloudFront distribution setup
- ACM certificate with DNS validation
- WAF rules and attack simulation
- Route 53 DNS basics (A Record)

**Day 2: Compute + Load Balancing**
- EC2 instance launch and SSH
- AMI creation and multi-AZ deployment
- ALB with health checks
- Route 53 deep dive (ALIAS, CNAME, routing policies)
- DNS Simulator walkthrough

---

## 📄 License

This project is for educational purposes. Use it freely for training and workshops.
