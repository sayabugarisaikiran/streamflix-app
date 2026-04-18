# AWS Load Balancers & Auto Scaling Groups — Complete Teaching Script

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~4 hour session with break.

---

# SECTION A: ELASTIC LOAD BALANCING

## Part 1: Why Load Balancing? (10 minutes)

### 🗣️ Opening Hook

*"You built a beautiful app. One server handles it fine. 100 users? No problem. 1,000? Starting to sweat. 10,000? Server crashes. Users see 502 Bad Gateway. Your boss is panicking."*

*"What do you do? Buy a BIGGER server? That's called vertical scaling — and it has a ceiling. The biggest EC2 instance (u-24tb1.metal) costs $218/hour and still can only handle so much."*

*"The real answer: buy MORE servers and SPLIT the traffic between them. That's horizontal scaling. But who splits the traffic? YOU can't sit there manually routing requests. You need a LOAD BALANCER."*

### 🗣️ The Restaurant Analogy

*"Imagine a restaurant with 50 tables. One waiter handles all 50? Disaster. Slow service, dropped orders, angry customers."*

*"Instead, you have a HOST at the entrance. The host checks which waiter has the fewest tables, and seats the next customer there. That host is your load balancer."*

```
Customers arrive
      │
      ▼
┌──────────────┐
│  HOST/HOSTESS │  ← Load Balancer
│  (distributes)│
└──────┬───────┘
       │
  ┌────┼────────┐
  │    │        │
  ▼    ▼        ▼
🧑‍🍳    🧑‍🍳       🧑‍🍳
Waiter Waiter  Waiter  ← EC2 Instances
(8)   (7)     (5)     ← (current tables)
       │
  Next customer → Waiter 3 (fewest tables)
```

---

## Part 2: Types of Load Balancers (15 minutes)

### 🗣️ AWS Has Four Load Balancers

| Type | Abbreviation | OSI Layer | Protocol | Launched |
|------|-------------|-----------|----------|----------|
| **Application Load Balancer** | ALB | Layer 7 | HTTP/HTTPS/gRPC | 2016 |
| **Network Load Balancer** | NLB | Layer 4 | TCP/UDP/TLS | 2017 |
| **Gateway Load Balancer** | GWLB | Layer 3 | IP (GENEVE) | 2020 |
| **Classic Load Balancer** | CLB | Layer 4/7 | TCP/HTTP | 2009 (DEPRECATED) |

*"99% of the time, you'll use ALB or NLB. Classic is deprecated — don't use it for new projects. Gateway is for inline firewalls."*

### 🗣️ ALB vs NLB — The Core Decision

| Feature | ALB (Layer 7) | NLB (Layer 4) |
|---------|--------------|--------------|
| **Understands** | HTTP headers, URLs, cookies, methods | TCP/UDP packets only |
| **Routing** | By URL path, hostname, header, query string | By port only |
| **SSL Termination** | ✅ Yes (offloads from app) | ✅ Yes (TLS listener) |
| **WebSockets** | ✅ Yes | ✅ Yes |
| **Static IP** | ❌ No (use DNS name) | ✅ Yes (Elastic IP per AZ) |
| **Latency** | ~400ms added | ~100μs added (ultra-low) |
| **Throughput** | Millions req/sec | Millions packets/sec |
| **Source IP** | Visible via X-Forwarded-For header | Preserved (client sees real IP) |
| **Health checks** | HTTP/HTTPS (path, status code) | TCP, HTTP, HTTPS |
| **WAF support** | ✅ Yes | ❌ No |
| **Lambda target** | ✅ Yes | ❌ No |
| **Use case** | Web apps, APIs, microservices | Gaming, IoT, financial, real-time |
| **Cost** | $0.0225/hr + $0.008/LCU | $0.0225/hr + $0.006/NLCU |

### 🗣️ When to Use Which — Decision Tree

```
Do you need to route by URL path or hostname?
  YES → ALB

Do you need ultra-low latency (<1ms)?
  YES → NLB

Do you need a static IP?
  YES → NLB (or ALB behind Global Accelerator)

Do you need to attach WAF?
  YES → ALB

Do you need non-HTTP protocols (TCP/UDP)?
  YES → NLB

Do you need Lambda as a target?
  YES → ALB

Default choice for web apps?
  → ALB
```

### ❓ Ask Students:

*"I have a microservices architecture: `/api/users` goes to User Service, `/api/orders` goes to Order Service, and `/api/payments` goes to Payment Service. ALB or NLB?"*

*"Answer: ALB. You need path-based routing — NLB can't inspect URLs."*

---

## Part 3: ALB Deep Dive (25 minutes)

### 🗣️ ALB Architecture

```
Internet
   │
   ▼
┌────────────────────────────────────────────────┐
│            Application Load Balancer           │
│                                                │
│  Listener: Port 443 (HTTPS)                    │
│    │                                           │
│    ├── Rule 1: IF path = /api/*                │
│    │            → Forward to: api-target-group  │
│    │                                           │
│    ├── Rule 2: IF host = admin.app.com         │
│    │            → Forward to: admin-tg          │
│    │                                           │
│    └── Default: → Forward to: web-target-group  │
│                                                │
└─────────────────┬──────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
┌────────┐  ┌────────┐  ┌────────┐
│  TG:   │  │  TG:   │  │  TG:   │
│  web   │  │  api   │  │  admin │
│  EC2-1 │  │  EC2-3 │  │  EC2-5 │
│  EC2-2 │  │  EC2-4 │  │        │
└────────┘  └────────┘  └────────┘
```

### 🗣️ ALB Components

#### 1. Listeners

*"A listener checks for connection requests on a port + protocol."*

| Listener | What It Does |
|----------|-------------|
| HTTP:80 | Listens for HTTP traffic |
| HTTPS:443 | Listens for HTTPS traffic (needs SSL certificate) |

*"Best practice: Create BOTH. HTTP:80 listener redirects to HTTPS:443."*

#### 2. Rules (Priority-based)

*"Each listener has rules that decide where to send traffic. Rules are evaluated in priority order (lowest number first)."*

| Rule Condition | What It Checks | Example |
|---------------|---------------|---------|
| **Path pattern** | URL path | `/api/*`, `/images/*`, `/health` |
| **Host header** | Domain name | `api.sskdevops.in`, `admin.sskdevops.in` |
| **HTTP method** | GET, POST, etc. | Route POSTs differently |
| **Source IP** | Client IP range | Route internal IPs to different target |
| **HTTP header** | Any header value | Custom `X-Api-Version` header |
| **Query string** | URL parameters | `?version=2` routes to v2 target |

#### 3. Rule Actions

| Action | What It Does | Example |
|--------|-------------|---------|
| **Forward** | Send to target group | Normal routing |
| **Redirect** | Return 301/302 redirect | HTTP → HTTPS redirect |
| **Fixed response** | Return a static response | `/maintenance` returns 503 |
| **Authenticate** | Require OIDC/Cognito login | Admin pages require auth |

### 🗣️ Path-Based Routing — Example

```
Rule 1 (Priority 1): IF path = /api/*     → api-tg
Rule 2 (Priority 2): IF path = /static/*  → s3-tg (or redirect to CDN)
Rule 3 (Priority 3): IF path = /health    → Fixed: 200 "OK"
Default:                                   → web-tg
```

### 🗣️ Host-Based Routing — Example

```
Rule 1: IF host = api.sskdevops.in    → api-tg
Rule 2: IF host = admin.sskdevops.in  → admin-tg
Rule 3: IF host = staging.sskdevops.in → staging-tg
Default: (sskdevops.in)                → web-tg
```

*"One ALB, multiple apps. Instead of running separate ALBs ($16/month each), route by hostname on ONE ALB. Saves money."*

#### 4. Target Groups

*"A target group is a collection of targets (EC2, Lambda, IPs) that receive traffic."*

| Target Type | What It Is | Use Case |
|-------------|-----------|----------|
| **Instance** | EC2 instance IDs | Standard web servers |
| **IP** | Private IPs | ECS tasks, on-prem servers via VPN |
| **Lambda** | Lambda function ARN | Serverless APIs |
| **ALB** | Another ALB | Chaining ALBs (rare) |

#### 5. Health Checks

*"The ALB pings each target every X seconds to check if it's alive."*

| Setting | Default | Recommended |
|---------|---------|-------------|
| **Protocol** | HTTP | HTTP or HTTPS |
| **Path** | `/` | `/health` (dedicated health endpoint) |
| **Port** | Traffic port | Same |
| **Healthy threshold** | 5 checks | 2-3 checks |
| **Unhealthy threshold** | 2 checks | 2-3 checks |
| **Interval** | 30 seconds | 10-15 seconds |
| **Timeout** | 5 seconds | 5 seconds |
| **Success codes** | 200 | 200-299 |

*"If the health check fails, the ALB stops sending traffic to that target. When it recovers, traffic resumes. No manual intervention."*

```
ALB health check → EC2-1 → /health → 200 ✅ (healthy)
ALB health check → EC2-2 → /health → 502 ❌ (unhealthy)
ALB health check → EC2-3 → /health → 200 ✅ (healthy)

Traffic distribution:
  EC2-1: 50% ✅
  EC2-2: 0%  ❌ (removed from rotation)
  EC2-3: 50% ✅
```

### 🗣️ Sticky Sessions

*"By default, each request goes to a different target (round robin). But what if your app stores session data in memory? A user logs in on EC2-1, then their next request goes to EC2-2 — they're logged out!"*

*"Sticky Sessions (Session Affinity) solve this by routing the same user to the same target:"*

| Type | How It Works | Duration |
|------|-------------|----------|
| **Application cookie** | ALB sets `AWSALB` cookie | Configurable (1 sec to 7 days) |
| **Duration-based** | ALB tracks client → target mapping | Configurable |
| **App-managed** | Your app sets a custom cookie | Your app controls it |

*"Better approach: DON'T use sticky sessions. Store sessions in Redis (ElastiCache) or DynamoDB. Then any target can handle any request. This is how Netflix, Amazon, and Google do it."*

### 🗣️ Cross-Zone Load Balancing

*"This is important. By default, ALB distributes traffic evenly across ALL targets in ALL AZs."*

```
Without Cross-Zone:
  AZ-a has 2 targets → each AZ gets 50% total traffic
  AZ-b has 8 targets → each AZ gets 50% total traffic
  
  AZ-a targets: 50% / 2 = 25% each (OVERLOADED!)
  AZ-b targets: 50% / 8 = 6.25% each (underutilized)

With Cross-Zone (ALB default):
  Total: 10 targets
  Each target gets 10% (regardless of AZ)
  ✅ Even distribution!
```

| LB Type | Cross-Zone Default | Data Transfer Cost |
|---------|-------------------|-------------------|
| ALB | ✅ Always ON | Free |
| NLB | ❌ OFF by default | Charged if enabled |

---

## Part 4: NLB Deep Dive (10 minutes)

### 🗣️ When You Need NLB

*"NLB is raw speed. It doesn't read HTTP. It routes TCP/UDP packets at wire speed."*

### 🗣️ Key Differences from ALB

| Feature | Detail |
|---------|--------|
| **Static IPs** | One Elastic IP per AZ (great for firewall whitelisting) |
| **Source IP preservation** | Client IP is visible to your app (no X-Forwarded-For needed) |
| **Protocols** | TCP, UDP, TLS (encrypted TCP) |
| **Connection is passed through** | NLB doesn't terminate TCP — your app handles it |
| **TLS Termination** | Optional — can terminate TLS at the NLB or pass through |
| **Zonal isolation** | Traffic stays in the same AZ by default |
| **Proxy Protocol v2** | Adds client info to TCP header if needed |

### 🗣️ NLB Use Cases

| Use Case | Why NLB |
|----------|---------|
| **Gaming servers** | UDP protocol, ultra-low latency |
| **IoT** | Millions of device connections on TCP |
| **Financial trading** | Microsecond latency matters |
| **Email (SMTP)** | Port 25/587, not HTTP |
| **Database proxy** | MySQL/PostgreSQL on TCP 3306/5432 |
| **VPN endpoint** | UDP 500/4500 for IPSec |
| **Firewall whitelisting** | Static IP required by partner |

### 🗣️ NLB + ALB Combo

*"If you need static IP AND Layer 7 routing:"*

```
Internet → NLB (static IP) → ALB → Target Groups
```

*"Or use AWS Global Accelerator, which gives you static IPs that front an ALB."*

---

## Part 5: Gateway Load Balancer (GWLB) (5 minutes)

### 🗣️ What is GWLB?

*"GWLB is for inline network appliances — firewalls, IDS/IPS, deep packet inspection."*

```
Internet → GWLB Endpoint → GWLB → Firewall Appliance → GWLB → Your App
                                   (Palo Alto, Fortinet)
```

*"It uses the GENEVE protocol to encapsulate all traffic, send it to a security appliance for inspection, then forward it to your app. Transparent — your app doesn't even know the firewall exists."*

*"You'll rarely set this up unless you work in security-heavy industries (banking, government)."*

---

## Part 6: SSL/TLS Termination (10 minutes)

### 🗣️ What is SSL Termination?

*"HTTPS traffic is encrypted. Someone has to DECRYPT it. You have two choices:"*

```
Option 1: Terminate at ALB (Recommended)
  Client ──HTTPS──→ ALB (decrypts here) ──HTTP──→ EC2
  ✅ Simpler. EC2 doesn't manage certificates.
  ✅ Offloads CPU from EC2

Option 2: Pass-through (End-to-End)
  Client ──HTTPS──→ NLB (just passes it) ──HTTPS──→ EC2 (decrypts here)
  ✅ Better for compliance (data never decrypted in transit)
  ❌ EC2 must manage certificates

Option 3: Re-encrypt
  Client ──HTTPS──→ ALB (decrypts, then re-encrypts) ──HTTPS──→ EC2
  ✅ ALB inspects traffic AND EC2 encryption maintained
  ❌ Most complex
```

### 🗣️ ACM (AWS Certificate Manager)

*"You need a certificate for HTTPS. ACM provides FREE SSL certificates."*

| Feature | Detail |
|---------|--------|
| **Cost** | Free (for ACM-managed certs on AWS resources) |
| **Renewal** | Automatic (never expires if attached to ALB/CloudFront) |
| **Validation** | DNS validation (add a CNAME record) or Email |
| **Wildcard** | `*.sskdevops.in` covers all subdomains |
| **Region** | Must be in same region as ALB. Must be us-east-1 for CloudFront. |

### 🗣️ SNI (Server Name Indication)

*"What if you have multiple domains on one ALB?"*

```
sskdevops.in       → Certificate 1
api.sskdevops.in   → Certificate 2
admin.sskdevops.in → Certificate 3
```

*"SNI solves this. The client includes the hostname in the TLS handshake. The ALB checks the hostname and presents the correct certificate. One ALB, multiple SSL certs."*

*"ALB supports up to 25 certificates per listener using SNI."*

---

## Part 7: Load Balancer Pricing (5 minutes)

### 🗣️ ALB Pricing

```
Hourly:    $0.0225/hour × 730 = $16.43/month
LCU cost:  $0.008/LCU-hour

LCU (Load Capacity Unit) = highest of:
  - New connections/sec (25 per LCU)
  - Active connections/min (3,000 per LCU)
  - Processed bytes/hour (1 GB per LCU)
  - Rule evaluations/sec (1,000 per LCU)

Typical small app (100 req/sec, 5 rules):
  Hourly: $16.43
  LCU:    ~2 LCUs × $0.008 × 730 = $11.68
  Total:  ~$28/month
```

### 🗣️ NLB Pricing

```
Hourly:     $0.0225/hour × 730 = $16.43/month
NLCU cost:  $0.006/NLCU-hour

NLCU = highest of:
  - New connections/sec (800 TCP, 400 UDP per NLCU)
  - Active connections/min (100,000 per NLCU)
  - Processed bytes/hour (1 GB per NLCU)
```

---

# SECTION B: AUTO SCALING GROUPS

## Part 8: Why Auto Scaling? (10 minutes)

### 🗣️ The Problem

*"Monday morning, 9 AM: 500 users. 2 servers handle it fine."*
*"Breaking news article goes viral linking to your site: 50,000 users in 10 minutes."*
*"2 servers crash. Site goes down. You manually launch 20 servers. Takes 15 minutes."*
*"By the time servers are ready, users have left. Traffic drops. Now you're paying for 20 servers you don't need."*

*"Auto Scaling solves ALL of this:"*

```
9:00 AM  — 500 users   — 2 instances  ← Normal
9:10 AM  — 50,000 users — 2 instances  ← CPU spikes to 95%!
9:11 AM  — CloudWatch alarm fires → ASG launches 10 instances
9:15 AM  — 12 instances running → CPU drops to 40% ✅
11:00 AM — Traffic drops → ASG terminates 8 instances
11:05 AM — Back to 4 instances ← Right-sized
```

*"You didn't touch anything. It happened automatically."*

---

## Part 9: Auto Scaling Group Core Concepts (20 minutes)

### 🗣️ Architecture

```
┌──────────────────────────────────────────────┐
│              Auto Scaling Group               │
│                                              │
│  Desired: 4    Min: 2    Max: 10             │
│                                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│  │  EC2-1 │ │  EC2-2 │ │  EC2-3 │ │  EC2-4 │ │
│  │  AZ-a  │ │  AZ-b  │ │  AZ-a  │ │  AZ-b  │ │
│  └────────┘ └────────┘ └────────┘ └────────┘ │
│                                              │
│  Launch Template: ami-abc123, t3.medium      │
│                                              │
│  Scaling Policies:                           │
│    Scale OUT: CPU > 70% → add 2 instances    │
│    Scale IN:  CPU < 30% → remove 1 instance  │
│                                              │
└──────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │     ALB      │ ← ASG auto-registers new instances
  │ Target Group │
  └──────────────┘
```

### 🗣️ Key Components

#### 1. Capacity Settings

| Setting | What It Does | Example |
|---------|-------------|---------|
| **Minimum** | Floor — never go below this | 2 (always 2 servers running) |
| **Maximum** | Ceiling — never exceed this | 10 (cost protection) |
| **Desired** | Current target number | 4 (what ASG aims for right now) |

```
Min: 2    Desired: 4    Max: 10

At 2 AM (low traffic):
  ASG scales in → Desired: 2 (hits minimum, stops)

At peak (viral traffic):
  ASG scales out → Desired: 10 (hits maximum, stops)
  Even if CPU is still high, it won't go above 10
```

*"MAXIMUM is your cost safety net. Without it, a traffic spike could launch 100 instances and bankrupt you."*

#### 2. Launch Template

*"The blueprint for new instances. Every instance ASG launches uses this template."*

| Setting | What It Specifies |
|---------|------------------|
| **AMI** | Which image (Amazon Linux 2023, your custom AMI) |
| **Instance type** | t3.medium, c5.xlarge, etc. |
| **Key pair** | SSH key |
| **Security Groups** | Firewall rules |
| **User Data** | Bootstrap script (install nginx, pull code) |
| **IAM Role** | Instance profile with permissions |
| **Network** | VPC, subnets (ASG can span multiple AZs) |
| **Storage** | EBS volume type and size |
| **Tags** | Name, Environment, Team, etc. |

*"Launch Template replaces Launch Configuration (deprecated). Launch Templates support versioning — you can update the template and roll out new versions."*

### ❓ Ask Students:

*"I update my Launch Template to use a new AMI. Do existing instances get updated?"*

*"Answer: NO. Existing instances keep the old AMI. Only NEW instances use the new template. To update existing ones, you need to do an Instance Refresh (rolling update)."*

#### 3. AZ Distribution

*"ASG distributes instances evenly across your selected AZs:"*

```
VPC with 3 AZs, Desired: 6

AZ-a: 2 instances
AZ-b: 2 instances
AZ-c: 2 instances

If AZ-a goes down:
  AZ-a: 0 instances (failed)
  AZ-b: 3 instances (ASG adds 1)
  AZ-c: 3 instances (ASG adds 1)
  → Still 6 instances, just redistributed!
```

*"This is automatic AZ failover. ASG ALWAYS rebalances across AZs."*

---

## Part 10: Scaling Policies (25 minutes)

### 🗣️ Four Types of Scaling

#### 1. Target Tracking Scaling (RECOMMENDED)

*"You set a target. ASG figures out the rest."*

```
"Keep average CPU at 50%"

CPU at 30% → ASG removes instances (too cold)
CPU at 50% → ASG does nothing (perfect)
CPU at 70% → ASG adds instances (too hot)
```

| Common Targets | What It Tracks |
|---------------|---------------|
| `ASGAverageCPUUtilization` | Average CPU across all instances |
| `ALBRequestCountPerTarget` | Requests per target (from ALB) |
| `ASGAverageNetworkIn` | Network bytes in |
| `ASGAverageNetworkOut` | Network bytes out |
| Custom CloudWatch metric | Your own metric (queue depth, etc.) |

*"Target Tracking is the SIMPLEST and SMARTEST policy. It's like a thermostat. You set 72°F, the AC figures out when to cool and when to stop. Start here."*

**Best practice targets:**
| Metric | Target | Why |
|--------|--------|-----|
| CPU | 50-60% | Leaves headroom for spikes |
| Request count/target | Based on load testing | e.g., 1,000 req/target |

#### 2. Step Scaling

*"Different actions at different severity levels."*

```
CPU 50-70%:  Add 1 instance    (warm)
CPU 70-85%:  Add 3 instances   (hot)
CPU 85-100%: Add 5 instances   (on fire!)

CPU 30-50%:  Remove 1 instance (cooling)
CPU <30%:    Remove 2 instances (cold)
```

*"Step Scaling gives you more control than Target Tracking. But it's more complex to configure."*

#### 3. Simple Scaling

*"Oldest type. One alarm → one action. Wait for cooldown → repeat."*

```
CloudWatch Alarm: CPU > 80%
  → Add 2 instances
  → Wait 300 seconds (cooldown)
  → Check again
```

*"Don't use Simple Scaling for new projects. Use Target Tracking or Step Scaling."*

#### 4. Scheduled Scaling

*"You KNOW when traffic will change — scale proactively."*

```
Cron: Every Monday-Friday at 8:30 AM IST
  → Set Desired: 10 (people start working)

Cron: Every Monday-Friday at 7:00 PM IST
  → Set Desired: 3 (end of business)

Cron: Every Black Friday (Nov 29) at 12:00 AM
  → Set Min: 20, Desired: 50  (brace for impact!)
```

*"Scheduled Scaling is perfect for predictable patterns. Combine it with Target Tracking for unpredictable spikes."*

### 🗣️ Cooldown Period

*"After a scaling action, ASG waits before taking another action. This prevents flapping."*

```
CPU hits 90% → ASG launches 3 instances
  → COOLDOWN (300 sec default)
  → New instances start, take time to boot, register with ALB
  → After cooldown, check CPU again
  → If still high → launch more
  → If normalized → do nothing
```

*"Without cooldown, ASG might keep launching instances while the first batch is still booting. You'd overshoot."*

*"Default: 300 seconds. Set it to slightly longer than your instance boot time."*

### 🗣️ Warm-Up Period (Target Tracking)

*"When a new instance launches, it takes time to boot, install software, and start handling traffic. During this warm-up, its CPU is sky-high (installation), which would trick ASG into launching even MORE instances."*

*"Warm-up period tells ASG: 'Ignore this instance's metrics for X seconds after launch.'"*

```
Default: 300 seconds
Recommended: Time from launch to fully serving traffic
```

---

## Part 11: Instance Refresh (Rolling Updates) (10 minutes)

### 🗣️ The Problem

*"You updated your AMI or your Launch Template. How do you roll it out to ALL running instances without downtime?"*

### 🗣️ Instance Refresh

*"Instance Refresh replaces instances in batches:"*

```
Starting state: [OLD-1] [OLD-2] [OLD-3] [OLD-4]

Step 1: Terminate OLD-1, launch NEW-1
   [NEW-1] [OLD-2] [OLD-3] [OLD-4]
   → Health check on NEW-1 → Healthy ✅

Step 2: Terminate OLD-2, launch NEW-2
   [NEW-1] [NEW-2] [OLD-3] [OLD-4]
   → Health check on NEW-2 → Healthy ✅

Step 3: Terminate OLD-3, launch NEW-3
Step 4: Terminate OLD-4, launch NEW-4

Final: [NEW-1] [NEW-2] [NEW-3] [NEW-4]
```

### 🗣️ Instance Refresh Settings

| Setting | What It Does | Default |
|---------|-------------|---------|
| **Min healthy percentage** | % of instances that must stay healthy during refresh | 90% |
| **Instance warmup** | Wait time after launch before checking health | 300 sec |
| **Checkpoint** | Pause after X% for manual verification | Optional |
| **Skip matching** | Don't replace instances already matching the template | ✅ |

*"Min healthy 90% with 4 instances: at most 1 can be replacing at a time (floor of 10% of 4 = 0.4 ≈ 1)."*

---

## Part 12: Lifecycle Hooks (5 minutes)

### 🗣️ What Are Lifecycle Hooks?

*"Hooks let you run custom actions DURING launch or terminate:"*

```
ASG decides to launch instance:
  → Instance enters "Pending:Wait" state
  → YOUR HOOK runs (install software, register with service registry, run tests)
  → Hook completes → Instance moves to "InService"
  → ALB starts sending traffic

ASG decides to terminate instance:
  → Instance enters "Terminating:Wait" state
  → YOUR HOOK runs (drain connections, deregister from service, backup data)
  → Hook completes → Instance terminates
```

| Hook | Use Case |
|------|----------|
| **Launch hook** | Pull latest code from Git, register with Consul/etcd, warm cache |
| **Terminate hook** | Drain load balancer connections, upload logs to S3, notify Slack |

---

## Part 13: ASG + ALB Integration (5 minutes)

### 🗣️ How They Work Together

```
ASG launches new instance
  → ASG automatically registers it in ALB Target Group
  → ALB health check starts
  → Once healthy → ALB sends traffic to it

ASG terminates instance
  → ALB starts connection draining (300 sec default)
  → Existing requests finish
  → ALB deregisters the instance
  → Instance terminates
```

| Feature | What Happens |
|---------|-------------|
| **Auto-registration** | New instances auto-added to ALB target group |
| **Health check source** | ASG can use ALB health checks (not just EC2 checks) |
| **Connection draining** | ALB drains connections before ASG terminates instance |
| **Deregistration delay** | 300 seconds default — time to finish in-flight requests |

*"CRITICAL: Set ASG health check type to `ELB`, not `EC2`. With EC2 health checks, ASG only knows if the instance is running. With ELB health checks, ASG knows if the APPLICATION is healthy (the `/health` endpoint returns 200)."*

---

## Part 14: Scaling Best Practices (5 minutes)

### 🗣️ Top 10 Best Practices

1. **Use Target Tracking as your primary policy** — simplest, smartest
2. **Set CPU target to 50-60%** — leaves headroom for spikes
3. **Scale OUT fast, scale IN slow** — add 3 instances immediately, remove 1 at a time
4. **Use health check type ELB** — catches app failures, not just hardware
5. **Spread across 3+ AZs** — survive AZ failures
6. **Use mixed instances policy** — mix instance types (t3 + m5 + c5) to avoid capacity issues
7. **Bake AMIs** — install software in AMI, not User Data (faster boot)
8. **Set Max capacity** — cost protection against runaway scaling
9. **Combine Scheduled + Target Tracking** — proactive + reactive
10. **Monitor ASG CloudWatch metrics** — `GroupDesiredCapacity`, `GroupInServiceInstances`

---

## Part 15: Interview Questions (10 minutes)

### 🗣️ Top 20 Interview Questions

**Load Balancers:**

1. **What are the types of AWS load balancers?**
   → ALB (Layer 7, HTTP), NLB (Layer 4, TCP/UDP), GWLB (Layer 3, network appliances), CLB (deprecated).

2. **When would you use ALB vs NLB?**
   → ALB: HTTP routing by path/host, WAF support, Lambda targets. NLB: TCP/UDP, static IP, ultra-low latency, non-HTTP protocols.

3. **What is path-based routing?**
   → ALB routes traffic to different target groups based on URL path. `/api/*` → API servers, `/images/*` → image servers.

4. **What is a target group?**
   → A collection of targets (EC2, IP, Lambda) that receive traffic from the load balancer, along with health check configuration.

5. **What is cross-zone load balancing?**
   → Distributes traffic evenly across ALL targets in ALL AZs, regardless of how many targets are in each AZ. Enabled by default for ALB.

6. **What is SSL termination?**
   → The load balancer decrypts HTTPS traffic and forwards HTTP to backend targets. Offloads encryption CPU from app servers.

7. **What is SNI?**
   → Server Name Indication. Allows one ALB listener to serve multiple SSL certificates based on the hostname the client requests.

8. **What is connection draining (deregistration delay)?**
   → When a target is deregistered, the ALB waits for in-flight requests to complete (default 300 sec) before fully removing it.

9. **Can ALB route to Lambda?**
   → Yes. Create a target group with type "Lambda" and attach the function.

10. **What is sticky sessions?**
    → Routes all requests from the same client to the same target using cookies. Useful for stateful apps but discouraged in favor of external session stores.

**Auto Scaling:**

11. **What is an Auto Scaling Group?**
    → A managed collection of EC2 instances that automatically scales based on demand, with defined min, max, and desired capacity.

12. **What is a Launch Template?**
    → A versioned blueprint defining AMI, instance type, security groups, key pair, user data, and other settings for instances launched by ASG.

13. **What are the scaling policy types?**
    → Target Tracking (set a target, ASG adjusts), Step (different actions at different thresholds), Simple (one alarm → one action), Scheduled (cron-based).

14. **Which scaling policy should I use?**
    → Start with Target Tracking. Add Scheduled Scaling for predictable patterns. Use Step Scaling for fine-grained control.

15. **What is the cooldown period?**
    → Wait time after a scaling action before another action can happen. Prevents over-scaling while new instances are still booting. Default: 300 seconds.

16. **What happens when an AZ goes down?**
    → ASG redistributes instances to remaining AZs to maintain desired capacity.

17. **What is Instance Refresh?**
    → A rolling update mechanism that replaces instances in batches to deploy a new Launch Template version without downtime.

18. **What is a lifecycle hook?**
    → A pause point during launch or termination where you can run custom scripts (install software, drain connections, upload logs).

19. **Should ASG health check be EC2 or ELB?**
    → ELB. EC2 checks only verify the instance is running. ELB checks verify the application is responding correctly on the health check path.

20. **What is predictive scaling?**
    → Machine learning-based scaling that analyzes historical traffic patterns and pre-scales BEFORE the predicted load arrives. Great for recurring patterns.

---

# SECTION C: HANDS-ON LABS

## 🟢 Lab 1: BASIC — ALB with Two EC2 Instances (25 minutes)

### Step 1: Launch Two EC2 Instances

**Instance 1:**
1. **EC2** → **Launch Instance**
   - Name: `web-server-1`
   - AMI: Amazon Linux 2023
   - Type: `t2.micro`
   - VPC: Your VPC, Subnet: public-1a
   - Security Group: Allow HTTP(80) from `0.0.0.0/0`, SSH(22) from your IP
   - User Data:
```bash
#!/bin/bash
yum install -y nginx
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>StreamFlix - Server 1</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0;}
h1{color:#e94560;font-size:48px;} .info{background:#16213e;padding:20px;border-radius:10px;display:inline-block;margin:10px;}
</style></head>
<body>
<h1>🎬 StreamFlix</h1>
<div class="info"><strong>Instance:</strong> $INSTANCE_ID</div>
<div class="info"><strong>AZ:</strong> $AZ</div>
<div class="info"><strong>Server:</strong> web-server-1</div>
<p>Refresh the page to see load balancing in action!</p>
</body></html>
EOF
cat > /usr/share/nginx/html/health <<EOF
{"status":"healthy","server":"web-server-1","instance":"$INSTANCE_ID"}
EOF
systemctl enable nginx
systemctl start nginx
```

**Instance 2:** Same config but:
- Name: `web-server-2`
- Subnet: public-1b (DIFFERENT AZ!)
- User Data: Change `Server 1` → `Server 2` and `web-server-1` → `web-server-2`

### Step 2: Verify Both Instances

```bash
curl http://<EC2-1-Public-IP>/
curl http://<EC2-2-Public-IP>/
# Both should show the StreamFlix page with different Instance IDs
```

### Step 3: Create Target Group

1. **EC2** → **Target Groups** → **Create**
   - Target type: **Instances**
   - Name: `streamflix-tg`
   - Protocol: HTTP, Port: 80
   - VPC: Your VPC
   - Health check path: `/health`
   - Healthy threshold: 2
   - Interval: 10 seconds
2. **Register targets:** Select both EC2 instances → **Include as pending** → Create

### Step 4: Create ALB

1. **EC2** → **Load Balancers** → **Create** → **ALB**
   - Name: `streamflix-alb`
   - Scheme: Internet-facing
   - Mappings: Select both AZs (same as your EC2s)
   - Security Group: Create new → Allow HTTP(80), HTTPS(443) from `0.0.0.0/0`
   - Listener: HTTP:80 → Forward to `streamflix-tg`
2. **Create**
3. Wait 2-3 minutes for state to become `Active`

### Step 5: Test Load Balancing

```bash
ALB_URL="http://streamflix-alb-XXXXX.us-east-1.elb.amazonaws.com"

# Hit the ALB 10 times — watch the server name alternate!
for i in $(seq 1 10); do
  echo -n "Request $i: "
  curl -s "$ALB_URL" | grep "Server:" | head -1
done
```

**Expected output:**
```
Request 1: <strong>Server:</strong> web-server-1
Request 2: <strong>Server:</strong> web-server-2
Request 3: <strong>Server:</strong> web-server-1
Request 4: <strong>Server:</strong> web-server-2
...
```

*"The ALB is alternating between servers! That's round-robin load balancing."*

### Step 6: Show Health Check & Failover

1. SSH into `web-server-1`:
```bash
sudo systemctl stop nginx
```

2. Wait 20 seconds (2 health checks at 10-sec intervals)

3. Hit the ALB again:
```bash
for i in $(seq 1 5); do
  echo -n "Request $i: "
  curl -s "$ALB_URL" | grep "Server:" | head -1
done
# → ALL requests go to web-server-2!
```

4. Check **Target Groups** → `streamflix-tg` → **Targets** tab
   - `web-server-1`: **unhealthy** 🔴
   - `web-server-2`: **healthy** 🟢

5. Restart nginx on web-server-1:
```bash
sudo systemctl start nginx
```
6. Wait 20 seconds → both targets healthy again → traffic splits again

---

## 🟡 Lab 2: INTERMEDIATE — ALB Path-Based Routing + HTTPS (30 minutes)

### Step 1: Request SSL Certificate

1. **ACM** → **Request certificate** → **Public**
2. Domain: `app.sskdevops.in` (or `*.sskdevops.in` for wildcard)
3. Validation: **DNS validation**
4. Create the CNAME record in Route 53 (click "Create records in Route 53" button)
5. Wait 5-10 minutes for validation → Status: **Issued** ✅

### Step 2: Add HTTPS Listener to ALB

1. **ALB** → `streamflix-alb` → **Listeners** tab
2. **Add listener:**
   - Protocol: HTTPS
   - Port: 443
   - Default action: Forward to `streamflix-tg`
   - Certificate: Select your ACM certificate
3. **Add**

### Step 3: Add HTTP → HTTPS Redirect

1. Select HTTP:80 listener → **Edit rules**
2. **Delete** the existing forward rule
3. **Add rule:** Default → **Redirect to** → HTTPS, 443, `#{host}`, `#{path}`, `#{query}`, 301
4. Save

### Step 4: Create API Target Group

1. Launch a new EC2 (`api-server-1`) with User Data that responds with JSON on port 80
2. Create target group: `api-tg`, health check: `/health`
3. Register `api-server-1`

### Step 5: Add Path-Based Rule

1. ALB → HTTPS:443 listener → **View/edit rules**
2. **Add rule:**
   - **IF** Path is `/api/*`
   - **THEN** Forward to `api-tg`
   - Priority: 1

3. **Add rule:**
   - **IF** Path is `/health`
   - **THEN** Fixed response: 200, `{"status":"ok"}`, `application/json`
   - Priority: 2

### Step 6: Point Route 53 to ALB

1. Route 53 → `sskdevops.in` → Create record:
   - Name: `app`
   - Type: A → Alias
   - Route to: ALB → your region → `streamflix-alb`

### Step 7: Test

```bash
# HTTPS works with SSL
curl -s https://app.sskdevops.in/ | grep "Server:"
# → StreamFlix page

# HTTP redirects to HTTPS
curl -sI http://app.sskdevops.in/ | grep -i location
# → Location: https://app.sskdevops.in/

# Path-based routing
curl -s https://app.sskdevops.in/api/test
# → Routed to api-tg

# Health check
curl -s https://app.sskdevops.in/health
# → {"status":"ok"}
```

---

## 🔴 Lab 3: ADVANCED — Auto Scaling Group with Target Tracking + Instance Refresh (40 minutes)

### Step 1: Create Launch Template

1. **EC2** → **Launch Templates** → **Create**
   - Name: `streamflix-lt`
   - AMI: Amazon Linux 2023
   - Type: `t2.micro`
   - Key pair: Your key
   - Security Group: Allow HTTP(80), SSH(22)
   - User Data:

```bash
#!/bin/bash
yum install -y nginx stress
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
LAUNCH_TIME=$(date)
cat > /usr/share/nginx/html/index.html <<EOF
<html><head><title>StreamFlix ASG</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#0f0f23;color:#e0e0e0;}
h1{color:#00d2ff;} .card{background:#1a1a3e;padding:15px;border-radius:8px;display:inline-block;margin:10px;}
</style></head><body>
<h1>🎬 StreamFlix (Auto Scaled)</h1>
<div class="card"><strong>Instance:</strong> $INSTANCE_ID</div>
<div class="card"><strong>AZ:</strong> $AZ</div>
<div class="card"><strong>Launch Template Version:</strong> v1</div>
<div class="card"><strong>Launched:</strong> $LAUNCH_TIME</div>
</body></html>
EOF
echo '{"status":"healthy"}' > /usr/share/nginx/html/health
systemctl enable nginx && systemctl start nginx
```

2. **Create launch template**

### Step 2: Create Auto Scaling Group

1. **EC2** → **Auto Scaling Groups** → **Create**
2. **Name:** `streamflix-asg`
3. **Launch Template:** `streamflix-lt` (latest version)
4. **Network:**
   - VPC: Your VPC
   - Subnets: Select 2+ AZs (public subnets)
5. **Load Balancing:**
   - Attach to existing ALB target group: `streamflix-tg`
   - Health check type: **ELB** ← IMPORTANT!
   - Health check grace period: 120 seconds
6. **Group size:**
   - Desired: `2`
   - Minimum: `2`
   - Maximum: `6`
7. **Scaling policies:**
   - Select **Target tracking scaling policy**
   - Policy name: `CPU-Target-50`
   - Metric: Average CPU Utilization
   - Target value: `50`
   - Instance warmup: 120 seconds
8. **Notifications:**
   - Add SNS topic `streamflix-alerts`
   - Events: Launch, Terminate, Fail
9. **Create**

### Step 3: Verify the ASG

```bash
# Check instances are running
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names streamflix-asg \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].InstanceId}'

# Hit the ALB — should alternate between 2 ASG instances
for i in $(seq 1 6); do
  echo -n "Request $i: "
  curl -s "http://streamflix-alb-XXXXX.us-east-1.elb.amazonaws.com/" | grep "Instance:"
done
```

### Step 4: Trigger Scale-Out (Stress Test)

SSH into BOTH ASG instances and stress the CPU:

```bash
# On each instance:
stress --cpu 4 --timeout 300
```

### Step 5: Watch the Scaling

```bash
# Monitor in real-time (run every 30 seconds)
watch -n 30 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names streamflix-asg \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,Running:length(Instances[?LifecycleState==\`InService\`])}"'
```

**Expected timeline:**
```
0:00  — Stress starts, CPU: 95%
1:00  — CloudWatch alarm enters ALARM state
2:00  — ASG increases desired capacity: 2 → 4
3:00  — 2 new instances launching
4:00  — New instances InService, registered with ALB
5:00  — CPU drops to ~50% (load distributed across 4 instances)
```

After stopping `stress`:
```
7:00  — CPU drops to ~5%
10:00 — Scale-in alarm fires (15min delay)
12:00 — ASG decreases desired capacity: 4 → 2
13:00 — 2 instances terminated
14:00 — Back to 2 instances ✅
```

### Step 6: Instance Refresh (Rolling Update)

1. Update the Launch Template — change the version text:
   - **Launch Templates** → `streamflix-lt` → **Create new version**
   - Change `v1` to `v2` in user data
   - Make this version the **default**

2. Start Instance Refresh:
   - **ASG** → `streamflix-asg` → **Instance refresh** tab → **Start instance refresh**
   - Min healthy: 90%
   - Instance warmup: 120 seconds
   - **Start**

3. Watch instances being replaced one by one:

```bash
# Monitor refresh progress
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-names streamflix-asg \
  --query 'InstanceRefreshes[0].{Status:Status,Progress:PercentageComplete}'
```

4. Hit the ALB — watch responses change from `v1` to `v2`:
```bash
for i in $(seq 1 10); do
  echo -n "Request $i: "
  curl -s "$ALB_URL/" | grep "Version:" | head -1
  sleep 2
done
# → Gradually shifts from v1 to v2
```

---

## Cleanup

```bash
# 1. Delete ASG (terminates all instances automatically)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name streamflix-asg \
  --force-delete

# 2. Delete Launch Template
aws ec2 delete-launch-template --launch-template-name streamflix-lt

# 3. Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>

# 4. Delete Target Groups
aws elbv2 delete-target-group --target-group-arn <TG_ARN>

# 5. Delete standalone EC2 instances (Lab 1)
aws ec2 terminate-instances --instance-ids i-xxx i-yyy

# 6. Delete ACM certificate (if no longer needed)
# 7. Delete Route 53 records
# 8. Delete Security Groups (non-default)
```

---

## Summary: What Each Lab Teaches

| Lab | Level | Duration | Concepts |
|-----|-------|----------|----------|
| 🟢 **Lab 1** | Basic | 25 min | ALB creation, target group, health checks, round-robin, failover demo |
| 🟡 **Lab 2** | Intermediate | 30 min | HTTPS with ACM, HTTP→HTTPS redirect, path-based routing, host-based routing |
| 🔴 **Lab 3** | Advanced | 40 min | Launch Template, ASG, target tracking policy, stress test scale-out/in, Instance Refresh rolling update |

---

## Timing Summary

| Section | Duration |
|---------|----------|
| **Load Balancers** | |
| Part 1: Why Load Balancing | 10 min |
| Part 2: Types (ALB/NLB/GWLB) | 15 min |
| Part 3: ALB Deep Dive | 25 min |
| Part 4: NLB Deep Dive | 10 min |
| Part 5: GWLB Overview | 5 min |
| Part 6: SSL/TLS | 10 min |
| Part 7: Pricing | 5 min |
| **☕ BREAK** | **10 min** |
| **Auto Scaling** | |
| Part 8: Why Auto Scaling | 10 min |
| Part 9: Core Concepts | 20 min |
| Part 10: Scaling Policies | 25 min |
| Part 11: Instance Refresh | 10 min |
| Part 12: Lifecycle Hooks | 5 min |
| Part 13: ASG + ALB Integration | 5 min |
| Part 14: Best Practices | 5 min |
| Part 15: Interview Questions | 10 min |
| 🟢 Lab 1: Basic | 25 min |
| 🟡 Lab 2: Intermediate | 30 min |
| 🔴 Lab 3: Advanced | 40 min |
| **Total** | **~4 hours** |

> **Trainer tip:** Take the break after SSL/TLS (Part 6). First half = load balancers (what distributes traffic). Second half = auto scaling (what creates/destroys servers). Labs are where it all clicks — the stress test in Lab 3 is the "wow" moment.

> **Trainer tip:** In Lab 1, the failover demo (stopping nginx on one server) is the most impactful moment. Students SEE the ALB instantly rerouting traffic. Let them all hit the ALB URL in their browsers and watch.

> **Trainer tip:** In Lab 3, the Instance Refresh is a real production technique. Point out that this is how companies like Netflix do zero-downtime deployments. No blue/green, no canary — just rolling replacement.
