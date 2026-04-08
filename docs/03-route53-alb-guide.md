# Route 53 & ALB — Complete Teaching Guide

This guide provides everything you need to explain Route 53 and Application Load Balancer in depth with hands-on labs.

---

## Part 1: What is Route 53? (Simple Explanation)

Route 53 is the **Internet Phonebook**. When someone types `streamflix.com` in their browser, their computer has no idea where that is. Route 53 looks up the name and returns the IP address.

**Why is it called "Route 53"?** DNS uses port 53. "Route" refers to routing traffic. Simple.

**Key facts:**
- **100% availability SLA** — the only AWS service with this guarantee
- Supports both public and private DNS
- Can route traffic intelligently (by latency, location, weight, health)
- Charged at $0.50/hosted zone/month + $0.40 per million queries

---

## Part 2: Hosted Zones Explained

A **Hosted Zone** is a container for DNS records for a single domain.

### Public Hosted Zone
- Resolves names on the **public internet**
- Created automatically when you buy a domain in Route 53
- If you bought the domain elsewhere (GoDaddy, Namecheap), create a hosted zone manually and copy the NS records to your registrar

### Private Hosted Zone
- Resolves names **inside a VPC only**
- Example: `database.internal.streamflix.com` → `10.0.3.50`
- Attach it to one or more VPCs
- Never visible from the internet

> [!IMPORTANT]
> When you create a hosted zone, Route 53 auto-creates **2 records**: NS (Name Server) and SOA (Start of Authority). Never delete these.

---

## Part 3: Record Types — Complete Reference

### IP → DNS Mapping (A / AAAA Records)

| Record | Maps To | Example | Use Case |
|--------|---------|---------|----------|
| **A** | IPv4 address | `streamflix.com` → `54.230.10.42` | EC2 Elastic IP, on-prem server |
| **AAAA** | IPv6 address | `streamflix.com` → `2600:1f18::1` | Modern dual-stack infrastructure |

**When to use:** You have a known, static IP address (e.g., Elastic IP on an EC2 instance).

### DNS → DNS Mapping (CNAME Records)

| Record | Maps To | Example | Limitation |
|--------|---------|---------|------------|
| **CNAME** | Another domain name | `www.streamflix.com` → `streamflix.com` | ❌ Cannot be used at zone apex |

> [!CAUTION]
> **CNAME at the root domain is ILLEGAL in DNS.** You cannot create: `streamflix.com` → CNAME → `something.cloudfront.net`. Use ALIAS instead!

**CNAME restrictions:**
1. Cannot exist at zone apex (root domain like `example.com`)
2. Replaces ALL other records at that name
3. Requires an extra DNS lookup (costs more, slower)

### DNS → AWS Resource (ALIAS Records) ⭐

ALIAS is **AWS's superpower**. It works like a CNAME but:

| Feature | CNAME | ALIAS |
|---------|-------|-------|
| Works at zone apex | ❌ No | ✅ Yes |
| Query charges | $0.40/M | **Free** |
| Extra DNS hop | Yes (slower) | No (resolved server-side) |
| Health check aware | No | Yes |
| Only for AWS targets | No (any DNS) | Yes (AWS resources only) |

**ALIAS targets:**
- CloudFront distributions
- Application Load Balancers (ALB)
- Network Load Balancers (NLB)
- S3 website endpoints
- Elastic Beanstalk environments
- API Gateway custom domains
- Another Route 53 record in the same hosted zone

### Other Record Types

| Record | Purpose | Example |
|--------|---------|---------|
| **MX** | Route email to mail servers | `streamflix.com` → MX 10 → `mail.google.com` |
| **TXT** | Domain verification, SPF, DKIM | `v=spf1 include:_spf.google.com ~all` |
| **NS** | Delegate zone to name servers | Auto-created. Points to 4 AWS nameservers |
| **SOA** | Zone metadata | Auto-created. Admin email, serial number |
| **CAA** | Which CAs can issue SSL certs | `0 issue "amazon.com"` |
| **SRV** | Service locator (host + port) | `_sip._tcp.example.com → 10 5 5060 sip.example.com` |
| **PTR** | Reverse DNS (IP → name) | `42.10.230.54.in-addr.arpa → streamflix.com` |

---

## Part 4: Routing Policies — How Route 53 Decides

### 1. Simple Routing
- **What:** One record, one or more values. Random if multiple.
- **Use case:** Single server, basic website.
- **No health check awareness.**

### 2. Weighted Routing
- **What:** Split traffic by weight (e.g., 70% to v2, 30% to v1).
- **Use case:** Canary releases, A/B testing, blue-green deployment.
- **Formula:** `weight_of_record / total_weight_of_all_records`
- Setting weight to 0 = stops sending traffic to that record.

### 3. Latency-Based Routing
- **What:** Route to the AWS region with lowest latency to the user.
- **Use case:** Global multi-region deployments (like Netflix).
- **How it works:** AWS maintains a latency database. When a user in India queries, Route 53 knows `ap-south-1` has 12ms latency vs `us-east-1` at 210ms.

### 4. Failover Routing
- **What:** Active-passive. Primary + standby.
- **Use case:** Disaster recovery.
- **How:** Route 53 health check monitors primary. If it fails 3 times consecutively, traffic goes to secondary automatically.

### 5. Geolocation Routing
- **What:** Route based on the user's physical country/continent.
- **Use case:** Compliance (GDPR), content licensing, language.
- **Not about latency!** This is about WHERE the user IS, not which server is fastest.

### 6. Geoproximity Routing (Traffic Flow only)
- **What:** Route based on geographic distance, with a configurable bias.
- **Bias:** Expand (+) or shrink (-) a region's "catchment area".
- **Requires:** Route 53 Traffic Flow (visual policy editor).

### 7. Multivalue Answer Routing
- **What:** Returns up to 8 healthy records. Client picks randomly.
- **Use case:** Simple DNS-level load balancing.
- **Has health checks** — only returns healthy IPs.

### 8. IP-Based Routing
- **What:** Route based on client IP address ranges (CIDR).
- **Use case:** Optimize for specific ISPs or corporate networks.

---

## Part 5: Application Load Balancer (ALB) + Route 53

### Why ALB?

| Feature | ALB | NLB | CLB (Classic) |
|---------|-----|-----|---------------|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP) | 4+7 (Legacy) |
| Path-based routing | ✅ | ❌ | ❌ |
| Host-based routing | ✅ | ❌ | ❌ |
| Lambda targets | ✅ | ❌ | ❌ |
| WebSocket | ✅ | ✅ | ❌ |
| Static IP | ❌ (use NLB) | ✅ | ❌ |

### ALB Key Concept: It has a DNS name, NOT an IP!

When you create an ALB, AWS gives you:
```
my-alb-1234567890.us-east-1.elb.amazonaws.com
```

This resolves to **multiple, dynamic IPs** across availability zones. That's why:
- ❌ You **cannot** use an A record pointing to a static ALB IP (it changes!)
- ✅ You **must** use a Route 53 **ALIAS** record to point your domain to the ALB

### Route 53 → ALB Mapping

```
api.streamflix.com  →  ALIAS (A)  →  my-alb-1234.us-east-1.elb.amazonaws.com
                                          ↓
                                    Target Group: /api/*
                                    ┌─────────────┐
                                    │ EC2-A  ✅    │
                                    │ EC2-B  ✅    │
                                    │ EC2-C  ❌    │ ← unhealthy, no traffic
                                    └─────────────┘
```

---

## Part 6: Hands-On Lab — ALB + Route 53

### Step 1: Deploy the ALB Terraform Stack
```bash
cd terraform/alb
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your domain name
terraform init
terraform apply
```

### Step 2: Verify DNS Resolution
```bash
# Check ALIAS record (should return ALB IPs)
dig api.yourdomain.com A +short

# Check CNAME record (should return ALB DNS name)
dig backend.yourdomain.com CNAME +short

# Verify HTTPS works
curl -v https://api.yourdomain.com/
curl -v https://api.yourdomain.com/health
```

### Step 3: Show Students the Difference
In the AWS Route 53 Console → Hosted Zones → Your domain, show them:
1. The **ALIAS A record** for `api.yourdomain.com` (points to ALB, no TTL visible)
2. The **CNAME record** for `backend.yourdomain.com` (shows TTL = 300, shows ALB DNS string)
3. The **Validation CNAME** for ACM (auto-created for SSL cert)

> [!TIP]
> Ask students: "Why can't we use CNAME for `api.yourdomain.com`?" Answer: Because CNAME cannot coexist with other record types, but an A record (ALIAS) can!

### Step 4: Health Check Demo
1. Go to Route 53 → Health Checks
2. Show the `streamflix-alb-health` health check
3. Show the status: **Healthy** (green)
4. Ask: "What happens if I delete the Lambda function?"
5. Delete it → Watch the health check turn **Unhealthy** (red) within 1-2 minutes
6. Redeploy → Watch it recover

---

## Part 7: Common Interview Questions

1. **What's the difference between CNAME and ALIAS?**
   - CNAME maps DNS→DNS, costs money, can't be at apex. ALIAS maps DNS→AWS resource, free, works at apex.

2. **Can you use a CNAME at the zone apex?**
   - No. DNS RFC prohibits it. Use ALIAS instead.

3. **How does Route 53 failover work?**
   - Health checks monitor primary. After 3 failures (configurable), traffic auto-routes to secondary.

4. **Why do you need ALIAS for an ALB instead of A record?**
   - ALB has a DNS name with dynamic IPs. A records need static IPs. ALIAS resolves the DNS name automatically.

5. **What's the difference between Latency and Geolocation routing?**
   - Latency = which region is nearest network-wise. Geolocation = which country/continent the user is physically in.
