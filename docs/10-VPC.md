# AWS VPC — Complete Teaching Script

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. This is a ~3 hour session with break.

---

## Part 1: Why Does VPC Exist? (15 minutes)

### 🗣️ Opening Hook

*"Before we touch any AWS service, I want you to think about something. When you launch an EC2 instance, where does it actually RUN? Is it just floating in space? Does it share a network with every other AWS customer?"*

*"In the early days of cloud (2006-2009), that was actually the case. All EC2 instances lived on a shared, flat network. Your instance, my instance, some random company's instance — all on the same network. If you misconfigured something, someone else could potentially reach your server."*

*"AWS realized this was terrible. In 2009, they invented the VPC — Virtual Private Cloud. Think of it as YOUR OWN private data center inside AWS. Your own network, your own IP ranges, your own firewall rules. Completely isolated from every other customer."*

*"Since December 2013, every single AWS resource launches inside a VPC. You cannot avoid it. So if you don't understand VPC, you don't understand AWS. Period."*

---

### 🗣️ The Apartment Building Analogy

*"Let me give you an analogy that will make everything click."*

*"AWS is like a massive apartment complex — thousands of buildings (data centers). When you create a VPC, you're renting one FLOOR of one building. That floor is completely yours."*

```
AWS Region (Mumbai) = The apartment complex
  │
  ├── Availability Zone A (ap-south-1a) = Building A
  ├── Availability Zone B (ap-south-1b) = Building B
  └── Availability Zone C (ap-south-1c) = Building C

VPC = Your entire floor (spans ALL buildings)
  │
  ├── Public Subnet (AZ-A) = Living room (guests can enter)
  ├── Private Subnet (AZ-A) = Bedroom (only family enters)
  ├── Public Subnet (AZ-B) = Living room (Building B)
  └── Private Subnet (AZ-B) = Bedroom (Building B)

Internet Gateway = The main entrance door to the complex
NAT Gateway = A one-way mail slot (you send out, nothing comes in)
Route Table = The directory board in the lobby
Security Group = The lock on your apartment door
NACL = The security guard at the floor entrance
```

*"Keep this analogy in mind. I'll refer back to it throughout."*

---

## Part 2: CIDR Blocks and IP Addressing (15 minutes)

### 🗣️ What is CIDR?

*"Before we create a VPC, you need to understand CIDR — Classless Inter-Domain Routing. It's how we define IP address ranges."*

*"An IPv4 address looks like this:"*

```
10.0.0.1
```

*"Each number is 8 bits. Four numbers = 32 bits total. CIDR notation adds a slash and a number after the IP:"*

```
10.0.0.0/16
            └── This means: the first 16 bits are FIXED, the rest can change
```

### 🗣️ CIDR Cheat Sheet

*"Here's the only chart you need to memorize:"*

| CIDR | Network Bits Fixed | Host Bits | Available IPs | Use Case |
|------|-------------------|-----------|---------------|----------|
| `/32` | All 32 | 0 | **1 IP** | Single host (for Security Groups, WAF) |
| `/28` | 28 | 4 | **16** (11 usable) | Tiny subnet |
| `/24` | 24 | 8 | **256** (251 usable) | Standard subnet |
| `/20` | 20 | 12 | **4,096** | Large subnet |
| `/16` | 16 | 16 | **65,536** | Typical VPC |
| `/8` | 8 | 24 | **16,777,216** | Massive (10.0.0.0/8 = all 10.x.x.x) |

*"The smaller the number after the slash, the MORE IPs you get."*

### 🗣️ Private IP Ranges (RFC 1918)

*"Not all IPs are yours to use. The internet has agreed on three ranges reserved for PRIVATE networks:"*

| Range | CIDR | Total IPs | Commonly Used For |
|-------|------|-----------|-------------------|
| `10.0.0.0` – `10.255.255.255` | `10.0.0.0/8` | 16 million | AWS VPCs (most common) |
| `172.16.0.0` – `172.31.255.255` | `172.16.0.0/12` | 1 million | AWS default VPC uses 172.31.x.x |
| `192.168.0.0` – `192.168.255.255` | `192.168.0.0/16` | 65,536 | Home routers, small offices |

*"AWS VPCs MUST use private IP ranges. You cannot create a VPC with public IPs like `8.8.8.0/24` (that's Google's)."*

### 🗣️ AWS Reserved IPs in Each Subnet

*"In every subnet, AWS reserves 5 IPs that you CANNOT use:"*

```
Subnet: 10.0.1.0/24 (256 IPs)

10.0.1.0   — Network address (can never be used)
10.0.1.1   — AWS reserves for the VPC router
10.0.1.2   — AWS reserves for DNS
10.0.1.3   — AWS reserves for future use
10.0.1.255 — Broadcast address (not used in VPC but reserved anyway)

Usable: 256 - 5 = 251 IPs
```

### ❓ Ask Students:

*"I create a subnet with CIDR `10.0.1.0/28`. How many IPs can I actually use for EC2 instances?"*

*"Answer: /28 = 16 IPs total. Minus 5 AWS reserved = 11 usable IPs."*

---

## Part 3: VPC — The Foundation (10 minutes)

### 🗣️ Creating a VPC — What Happens

*"When you create a VPC, you're defining a private network with a CIDR block. Let's say we create:"*

```
VPC Name: streamflix-vpc
CIDR: 10.0.0.0/16
```

*"This means our VPC owns ALL IPs from `10.0.0.0` to `10.0.255.255` — that's 65,536 IPs. But creating a VPC alone does NOTHING useful. You need to carve it into subnets."*

### 🗣️ What Gets Created Automatically

*"When you create a VPC, AWS automatically creates:"*

| Resource | Why |
|----------|-----|
| **Main Route Table** | Default routing for all subnets (only has local route) |
| **Default NACL** | Allows ALL inbound and outbound traffic |
| **Default Security Group** | Allows outbound, denies inbound (except from same SG) |

*"AWS does NOT create: Internet Gateway, NAT Gateway, subnets, or anything else. You build those yourself."*

### 🗣️ Default VPC vs Custom VPC

*"Every AWS region comes with a DEFAULT VPC pre-built. It has:"*

| Feature | Default VPC | Custom VPC |
|---------|-------------|------------|
| CIDR | `172.31.0.0/16` | You choose |
| Subnets | One per AZ (auto-created) | You create |
| Internet Gateway | Attached | You create and attach |
| Public IPs | Auto-assigned | Not assigned by default |
| Use case | Quick testing, learning | Production workloads |

*"NEVER use the default VPC for production. It's wide open. Always create a custom VPC."*

---

## Part 4: Subnets — Carving the Network (15 minutes)

### 🗣️ What is a Subnet?

*"A subnet is a SLICE of your VPC's CIDR range. It lives in ONE Availability Zone."*

```
VPC: 10.0.0.0/16 (65,536 IPs)
  │
  ├── Subnet A: 10.0.1.0/24 (256 IPs) → AZ: ap-south-1a
  ├── Subnet B: 10.0.2.0/24 (256 IPs) → AZ: ap-south-1a
  ├── Subnet C: 10.0.3.0/24 (256 IPs) → AZ: ap-south-1b
  └── Subnet D: 10.0.4.0/24 (256 IPs) → AZ: ap-south-1b
```

*"A subnet CANNOT span multiple AZs. One subnet = one AZ. But a VPC spans ALL AZs in the region."*

### 🗣️ Public Subnet vs Private Subnet

*"This is the most important concept in VPC. Listen carefully."*

*"There is NO checkbox that says 'make this subnet public.' A subnet becomes public or private based on its ROUTE TABLE."*

| Feature | Public Subnet | Private Subnet |
|---------|---------------|----------------|
| Route to Internet Gateway? | ✅ Yes (`0.0.0.0/0 → igw-xxx`) | ❌ No |
| Route to NAT Gateway? | No (doesn't need it) | ✅ Yes (`0.0.0.0/0 → nat-xxx`) |
| Instances get public IP? | Yes (auto-assign enabled) | No |
| Reachable from internet? | Yes | No |
| What goes here? | Load balancers, bastion hosts, NAT GW | App servers, databases, Lambda |

```
INTERNET
    │
    ▼
┌──────────────────┐
│ Internet Gateway │
└────────┬─────────┘
         │
    ┌────▼────┐          ┌──────────┐
    │ PUBLIC  │          │ PRIVATE  │
    │ SUBNET  │──────────│ SUBNET   │
    │         │          │          │
    │ 🔵 ALB  │          │ 🟢 EC2   │
    │ 🔵 NAT  │          │ 🟢 RDS   │
    │ 🔵 Bastn│          │ 🟢 Lambda│
    └─────────┘          └──────────┘
```

*"The golden rule: Only ALBs, NAT Gateways, and bastion hosts should be in public subnets. Everything else goes in private subnets."*

### ❓ Ask Students:

*"I have a web application with an ALB, 3 EC2 servers, and an RDS database. Which goes in public subnets? Which goes in private?"*

*"Answer: ALB in public (needs to receive internet traffic). EC2 and RDS in private (should never be directly accessible from internet)."*

---

## Part 5: Internet Gateway (IGW) (5 minutes)

### 🗣️ What is an Internet Gateway?

*"The Internet Gateway is the FRONT DOOR of your VPC. Without it, nothing in your VPC can reach the internet, and the internet can't reach your VPC."*

**Key facts:**
- *One VPC can have only ONE Internet Gateway*
- *An IGW is horizontally scaled, redundant, and highly available — AWS manages it*
- *It does NOT limit bandwidth — it's not a bottleneck*
- *It performs Network Address Translation (NAT) for instances with public IPs*

### 🗣️ How It Works

```
1. EC2 (10.0.1.50) in public subnet sends packet to google.com
2. Packet hits route table: 0.0.0.0/0 → igw-xxx
3. IGW translates 10.0.1.50 → 54.230.10.42 (public IP) 
4. Packet goes to the internet
5. Response comes back to 54.230.10.42
6. IGW translates 54.230.10.42 → 10.0.1.50
7. Packet delivered to EC2
```

*"The IGW does the public-to-private IP translation. Without it, your private IP (10.0.1.50) means nothing on the internet."*

### 🗣️ Steps to Enable Internet Access

*"Just attaching an IGW is not enough. Three things must be true:"*

1. ✅ Internet Gateway attached to VPC
2. ✅ Route table has `0.0.0.0/0 → igw-xxx`
3. ✅ Instance has a public IP (or Elastic IP)

*"Miss any ONE of these and internet access doesn't work. This is the #1 debugging issue for beginners."*

---

## Part 6: NAT Gateway (10 minutes)

### 🗣️ The Problem NAT Solves

*"Your database server is in a private subnet. Good — it's not reachable from the internet. But the database needs to download security patches from the internet. How?"*

*"It can't use the Internet Gateway directly — the private subnet has no route to the IGW. And we DON'T want to add one, because then the database would be publicly accessible."*

*"Enter NAT Gateway — a one-way door. Traffic goes OUT to the internet. But nothing comes IN."*

```
INTERNET
    ▲ (responses come back)
    │
    │ (outbound traffic goes out)
┌───┴────────────┐
│  NAT Gateway   │ ← Lives in PUBLIC subnet
│  (One-way)     │ ← Has an Elastic IP
└───┬────────────┘
    │
┌───▼────────────┐
│ PRIVATE SUBNET │
│                │
│  EC2 wants to  │
│  run yum update│ → Route: 0.0.0.0/0 → nat-xxx
│                │
└────────────────┘
```

### 🗣️ NAT Gateway vs NAT Instance

| Feature | NAT Gateway (Preferred) | NAT Instance (Old way) |
|---------|------------------------|----------------------|
| **Managed by** | AWS (zero maintenance) | You (patching, scaling) |
| **Bandwidth** | Up to 100 Gbps | Depends on instance type |
| **Availability** | Redundant within AZ | Single instance = SPOF |
| **Cost** | $0.045/hour + $0.045/GB | EC2 cost (cheaper but risky) |
| **Security Group** | Not supported | Supports SG |

*"Always use NAT Gateway in production. NAT Instance is only for cost-saving in dev/test."*

### 🗣️ High Availability Pattern

*"A NAT Gateway lives in ONE AZ. If that AZ goes down, private subnets in other AZs lose internet access. For HA:"*

```
AZ-A:
  Public Subnet A → NAT Gateway A (Elastic IP 1)
  Private Subnet A → Route: 0.0.0.0/0 → NAT-GW-A

AZ-B:
  Public Subnet B → NAT Gateway B (Elastic IP 2)
  Private Subnet B → Route: 0.0.0.0/0 → NAT-GW-B
```

*"One NAT Gateway per AZ, each with its own route table. If AZ-A dies, AZ-B still has internet access."*

### 🗣️ Cost Warning

*"NAT Gateway is one of the most EXPENSIVE parts of AWS networking:"*

```
$0.045/hour × 24 × 30 = $32.40/month (just for existing)
+ $0.045/GB data processed

If your private instances download 100GB/month:
$32.40 + (100 × $0.045) = $36.90/month PER NAT Gateway

Two AZs = $73.80/month just for NAT!
```

*"This catches beginners off guard. In dev, consider a NAT Instance ($3-5/month on t3.nano) or VPC endpoints to bypass NAT entirely."*

### ❓ Ask Students:

*"My EC2 in a private subnet can't run `yum update`. What should I check?"*

*"Answer: Check three things: (1) Is there a NAT Gateway in a public subnet? (2) Does the private subnet's route table have `0.0.0.0/0 → nat-xxx`? (3) Does the NAT Gateway's public subnet have a route to the Internet Gateway?"*

---

## Part 7: Route Tables (10 minutes)

### 🗣️ What is a Route Table?

*"A route table is a set of rules (routes) that determine WHERE network traffic goes. Every subnet is associated with exactly ONE route table."*

### 🗣️ Anatomy of a Route Table

```
Public Subnet Route Table:
┌─────────────────────┬──────────────────┐
│ Destination         │ Target           │
├─────────────────────┼──────────────────┤
│ 10.0.0.0/16         │ local            │  ← "Stay in VPC" (auto-created, can't delete)
│ 0.0.0.0/0           │ igw-abc123       │  ← "Everything else → Internet Gateway"
└─────────────────────┴──────────────────┘

Private Subnet Route Table:
┌─────────────────────┬──────────────────┐
│ Destination         │ Target           │
├─────────────────────┼──────────────────┤
│ 10.0.0.0/16         │ local            │  ← "Stay in VPC"
│ 0.0.0.0/0           │ nat-xyz789       │  ← "Everything else → NAT Gateway"
└─────────────────────┴──────────────────┘
```

### 🗣️ Key Rules

1. **Every route table has a `local` route** — can't be deleted. This allows communication within the VPC.
2. **Most specific route wins** — `10.0.1.0/24` is more specific than `10.0.0.0/16` which is more specific than `0.0.0.0/0`.
3. **0.0.0.0/0** is the "catch-all" — if traffic doesn't match any other route, use this one.
4. **Main route table** — every VPC has one. Subnets not explicitly associated with any route table use the main one. Keep the main table private (no IGW route).

### 🗣️ Best Practice

*"Create SEPARATE route tables for public and private subnets. Never add an IGW route to the main route table. If you do, any new subnet you forget to associate gets public access by default. That's a security nightmare."*

---

## Part 8: Security Groups (15 minutes)

### 🗣️ What is a Security Group?

*"A Security Group is a virtual firewall that controls traffic to and from an EC2 instance (or ENI). Think of it as the LOCK on your apartment door."*

### 🗣️ Key Characteristics

| Feature | Security Group |
|---------|---------------|
| **Level** | Instance-level (attached to ENI) |
| **State** | **STATEFUL** — if you allow inbound, outbound response is auto-allowed |
| **Default** | Denies ALL inbound, allows ALL outbound |
| **Rules** | ALLOW rules only — you cannot write a DENY rule |
| **Evaluation** | All rules evaluated together (not in order) |
| **Changes** | Take effect immediately |
| **Scope** | Within a VPC (can't be used across VPCs) |

### 🗣️ Stateful — What Does It Mean?

*"This is critical. If you allow INBOUND on port 80, the OUTBOUND response is automatically allowed — you don't need to add an outbound rule for it."*

```
Inbound Rule: Allow port 80 from 0.0.0.0/0
→ A user sends HTTP request on port 80 → ALLOWED ✓
→ The server sends the response back → AUTOMATICALLY ALLOWED ✓
  (Even though there's no explicit outbound rule for port 80)
```

*"This is because Security Groups track connections. They remember: 'This inbound connection exists, so the outbound response belongs to it.'"*

### 🗣️ Example: 3-Tier Web App Security Groups

```
SG: web-alb-sg (for ALB)
  Inbound:  Port 80  from 0.0.0.0/0 (internet)
  Inbound:  Port 443 from 0.0.0.0/0 (internet)
  Outbound: All traffic

SG: app-sg (for EC2 app servers)
  Inbound:  Port 8080 from web-alb-sg  ← REFERENCE by SG ID, not IP!
  Outbound: All traffic

SG: db-sg (for RDS)
  Inbound:  Port 3306 from app-sg      ← Only app servers can reach DB
  Outbound: All traffic
```

### 🗣️ Security Group Referencing — The Superpower

*"Notice I wrote `from web-alb-sg` not `from 10.0.1.0/24`. This is a HUGE feature."*

*"When you reference another Security Group as the source, you're saying: 'Allow traffic from ANY instance that has this SG attached, regardless of its IP.' If you add or remove instances from that SG, the rules automatically apply. No IP updates needed."*

### ❓ Ask Students:

*"My EC2 instance can receive traffic but can't send responses. What's wrong?"*

*"Trick question! This can't happen with Security Groups because they're STATEFUL. If inbound is allowed, responses go out automatically. This symptom is a NACL problem, not a Security Group problem."*

---

## Part 9: Network ACLs (NACLs) (15 minutes)

### 🗣️ What is a NACL?

*"A Network ACL is a firewall at the SUBNET level. If Security Groups are locks on individual apartment doors, NACLs are the security guard at the floor entrance."*

### 🗣️ Security Group vs NACL — The Comparison

| Feature | Security Group | NACL |
|---------|---------------|------|
| **Level** | Instance | Subnet |
| **State** | Stateful | **Stateless** |
| **Default** | Deny all inbound | Allow all inbound AND outbound |
| **Rules** | ALLOW only | ALLOW and **DENY** |
| **Evaluation** | All rules checked | Rules checked IN ORDER (by number) |
| **Applied to** | Instance/ENI | All instances in the subnet |

### 🗣️ STATELESS — The Key Difference

*"NACLs are STATELESS. They don't remember connections. If you allow inbound on port 80, you MUST ALSO allow outbound on the EPHEMERAL port range for the response."*

```
NACL for public subnet:

INBOUND:
  Rule 100: Allow TCP port 80 from 0.0.0.0/0   ← HTTP
  Rule 110: Allow TCP port 443 from 0.0.0.0/0   ← HTTPS
  Rule 120: Allow TCP port 22 from 10.0.0.0/16   ← SSH from within VPC
  Rule *:   DENY ALL                              ← Default deny

OUTBOUND:
  Rule 100: Allow TCP port 1024-65535 to 0.0.0.0/0  ← Ephemeral ports (responses!)
  Rule 110: Allow TCP port 443 to 0.0.0.0/0          ← HTTPS outbound
  Rule *:   DENY ALL
```

*"See Rule 100 outbound? Port 1024-65535? Those are EPHEMERAL PORTS. When a client connects to your server on port 80, the response goes back on a random high port (like 52431). If you don't allow those outbound in the NACL, responses are blocked."*

*"This is the #1 NACL gotcha. Students set up inbound rules perfectly, then wonder why nothing works — because they forgot outbound ephemeral ports."*

### 🗣️ Rule Evaluation Order

*"NACL rules have numbers. They're evaluated from LOWEST to HIGHEST. First match wins."*

```
Rule 100: ALLOW port 80 from 0.0.0.0/0
Rule 200: DENY port 80 from 198.51.100.50/32  ← NEVER REACHED!
Rule *:   DENY ALL
```

*"In this example, the DENY on rule 200 is useless because rule 100 already ALLOWed ALL port 80 traffic. Fix:"*

```
Rule 50:  DENY port 80 from 198.51.100.50/32  ← Checked FIRST
Rule 100: ALLOW port 80 from 0.0.0.0/0        ← Everyone else allowed
Rule *:   DENY ALL
```

*"Best practice: Number rules in increments of 10 or 100 so you can insert new rules between them."*

### 🗣️ When to Use NACLs

*"Honestly? Most of the time, Security Groups are enough. Use NACLs for:"*

1. **Blocking specific IPs at the subnet level** — faster than SG changes
2. **Defense in depth** — an extra layer on top of SGs
3. **Compliance** — some regulations require network-level controls
4. **Deny rules** — SGs can't deny, NACLs can

*"In production, keep NACLs simple. Don't try to replicate all your SG rules in NACLs. That's a maintenance nightmare."*

---

## Part 10: VPC Peering (10 minutes)

### 🗣️ What is VPC Peering?

*"VPC Peering connects two VPCs so they can communicate using private IPs — as if they're on the same network."*

```
VPC A (10.0.0.0/16) ←── Peering Connection ──→ VPC B (172.16.0.0/16)
  EC2: 10.0.1.50                                  RDS: 172.16.3.20
  
  10.0.1.50 can now ping 172.16.3.20 directly!
```

### 🗣️ Key Rules

1. **No overlapping CIDRs** — If both VPCs use `10.0.0.0/16`, peering is impossible. This is why CIDR planning matters!
2. **Not transitive** — If A↔B and B↔C, A CANNOT reach C through B. You need a separate A↔C peering.
3. **Cross-region supported** — VPC in Mumbai can peer with VPC in Virginia.
4. **Cross-account supported** — Your VPC can peer with another AWS account's VPC.
5. **Route tables required** — You must manually add routes in BOTH VPCs.

```
VPC A Route Table:
  172.16.0.0/16 → pcx-abc123 (peering connection)

VPC B Route Table:
  10.0.0.0/16 → pcx-abc123 (peering connection)
```

### 🗣️ When to Use VPC Peering

*"Use peering when:*
- *Dev VPC needs to access shared services in a Prod VPC*
- *Two departments need to share a database but keep environments separate*
- *Cross-account access (your VPC + partner's VPC)*

*Don't use peering when you have 10+ VPCs — that's 45 peering connections (n×(n-1)/2). Use Transit Gateway instead."*

---

## Part 11: VPC Endpoints (10 minutes)

### 🗣️ The Problem

*"Your EC2 in a private subnet needs to access S3. Currently, the traffic flows like this:"*

```
EC2 (private) → NAT Gateway → Internet Gateway → INTERNET → S3
```

*"That's insane. Your traffic leaves AWS, goes through the public internet, and comes back to AWS. It's slow, costs money (NAT charges), and is less secure."*

### 🗣️ The Solution: VPC Endpoints

*"VPC Endpoints create a private connection from your VPC directly to AWS services without going through the internet."*

```
EC2 (private) → VPC Endpoint → S3 (directly, no internet!)
```

### 🗣️ Two Types of VPC Endpoints

#### Gateway Endpoints (FREE!)

*"Available for only two services:"*
| Service | Cost |
|---------|------|
| **S3** | Free |
| **DynamoDB** | Free |

*"How it works: You add a route in your route table pointing to the endpoint."*

```
Route Table:
  pl-xxxxxxxx (S3 prefix list) → vpce-abc123 (Gateway Endpoint)
```

*"No NAT Gateway needed. No internet traffic. Free. Always use this for S3 and DynamoDB."*

#### Interface Endpoints (PrivateLink)

*"For every other AWS service (CloudWatch, SQS, SNS, Secrets Manager, etc.)"*

*"How it works: Creates an ENI (network interface) in your subnet with a private IP."*

```
EC2 (10.0.2.50) → ENI (10.0.2.100) → CloudWatch Logs
                   ↑
            This ENI IS the endpoint
            Powered by AWS PrivateLink
```

| Feature | Gateway Endpoint | Interface Endpoint |
|---------|-----------------|-------------------|
| **Cost** | Free | $0.01/hour + $0.01/GB |
| **Services** | S3, DynamoDB only | 100+ AWS services |
| **How it works** | Route table entry | ENI in your subnet |
| **DNS** | Uses S3/DynamoDB URLs | Private DNS or endpoint URL |

### 🗣️ Cost Savings Example

*"Without S3 Gateway Endpoint: 1TB of S3 traffic through NAT Gateway = $45/month in NAT charges."*
*"With S3 Gateway Endpoint: Same 1TB = $0. It's free."*
*"If you don't create S3 gateway endpoints, you're literally burning money."*

---

## Part 12: Elastic IP (5 minutes)

### 🗣️ What is an Elastic IP?

*"An Elastic IP is a STATIC public IPv4 address. Normal EC2 public IPs change when you stop/start the instance. Elastic IPs don't."*

**Key facts:**
- *Free when attached to a running instance*
- *Costs $0.005/hour (~$3.60/month) when NOT attached — AWS charges you for wasting it*
- *Can be moved between instances (useful for failover)*
- *Limit: 5 per region (can request more)*

*"Use case: You have a server that external systems connect to by IP (like an SMTP server or a VPN endpoint). You need the IP to stay the same even if you replace the instance."*

*"For most web apps, don't use Elastic IPs. Use an ALB + Route 53 ALIAS instead."*

---

## Part 13: VPC Flow Logs (10 minutes)

### 🗣️ What are Flow Logs?

*"Flow Logs capture information about the IP traffic going to and from network interfaces in your VPC. Think of it as a security camera recording who entered and left your building."*

### 🗣️ Three Levels

| Level | What It Captures |
|-------|-----------------|
| **VPC Flow Log** | All traffic in the entire VPC |
| **Subnet Flow Log** | All traffic in a specific subnet |
| **ENI Flow Log** | Traffic to/from a specific network interface |

### 🗣️ Sample Flow Log Entry

```
2 123456789012 eni-abc123 10.0.1.50 52.94.76.4 443 49321 6 15 1200 1681234567 1681234577 ACCEPT OK
```

| Field | Value | Meaning |
|-------|-------|---------|
| Version | 2 | Log format version |
| Account | 123456789012 | AWS account |
| ENI | eni-abc123 | Network interface |
| Src IP | 10.0.1.50 | Source IP |
| Dst IP | 52.94.76.4 | Destination IP |
| Dst Port | 443 | Destination port |
| Src Port | 49321 | Source port |
| Protocol | 6 | TCP (6=TCP, 17=UDP, 1=ICMP) |
| Packets | 15 | Packet count |
| Bytes | 1200 | Byte count |
| Start | 1681234567 | Start time (Unix) |
| End | 1681234577 | End time (Unix) |
| Action | ACCEPT | Security Group/NACL decision |
| Status | OK | Log capture status |

### 🗣️ Flow Logs for Debugging

*"When an EC2 instance can't connect to something, check flow logs:"*

- **ACCEPT** → Traffic passed SG/NACL. Problem is application-level.
- **REJECT** → Traffic blocked by SG or NACL. Check your rules.
- **No entries** → Traffic never reached the ENI. Problem is routing (route table).

### 🗣️ Destinations

| Destination | Use Case |
|-------------|----------|
| **CloudWatch Logs** | Quick analysis, metric filters, alarms |
| **S3** | Long-term storage, Athena queries |
| **Kinesis Firehose** | Real-time stream to SIEM (Splunk, Datadog) |

---

## Part 14: Bastion Host / Jump Box (5 minutes)

### 🗣️ What is a Bastion Host?

*"Your app servers are in private subnets. Good for security. But how do YOU SSH into them?"*

*"A bastion host (or jump box) is a small EC2 instance in a PUBLIC subnet used as a 'stepping stone' to SSH into private instances."*

```
Your Laptop → SSH (port 22) → Bastion Host (public subnet)
                                    │
                                    └── SSH (port 22) → EC2 in private subnet
```

### 🗣️ Bastion Security

| Security Measure | How |
|-----------------|-----|
| Only allow YOUR IP | SG: Port 22 from `your-ip/32` only |
| Harden the OS | Disable root, use key-only auth |
| Small instance | t3.nano ($3/month) — only used for jumping |
| Log everything | Enable session logging with SSM |
| Consider alternatives | AWS Systems Manager Session Manager = no bastion needed |

*"Modern approach: Use **AWS Systems Manager Session Manager** instead of bastion hosts. It provides a browser-based shell to private instances without opening port 22 at all. No SSH keys, no bastion host, no inbound rules."*

---

## Part 15: Transit Gateway (5 minutes)

### 🗣️ The Problem with VPC Peering at Scale

*"If you have 5 VPCs and each needs to talk to every other, you need 10 peering connections. 10 VPCs = 45 connections. 100 VPCs = 4,950 connections. Unmanageable."*

### 🗣️ Transit Gateway = Hub and Spoke

```
Without Transit Gateway:          With Transit Gateway:

  VPC-A ─── VPC-B                    VPC-A ─┐
    │  ╲  ╱  │                       VPC-B ─┤
    │   ╲╱   │                       VPC-C ─┼── Transit Gateway ── On-Prem
    │   ╱╲   │                       VPC-D ─┤
    │  ╱  ╲  │                       VPC-E ─┘
  VPC-C ─── VPC-D                    
  (6 connections)                    (5 connections)
```

*"Transit Gateway is a CENTRALIZED HUB. Each VPC connects to it once. Routing is managed centrally. Supports up to 5,000 VPCs."*

*"Cost: $0.05/hour (~$36/month) + $0.02/GB processed. Expensive but worth it at scale."*

---

## Part 16: VPN and Direct Connect (5 minutes)

### 🗣️ Connecting Your Office to AWS

#### Site-to-Site VPN
*"Creates an encrypted tunnel over the internet from your office to your VPC."*
- Cost: $0.05/hour (~$36/month)
- Bandwidth: Depends on internet speed (typically 1-2 Gbps)
- Setup time: Minutes
- Uses: IPSec tunnel from your on-prem router to a Virtual Private Gateway in AWS

#### AWS Direct Connect
*"A dedicated, PHYSICAL fiber connection from your data center to AWS."*
- Cost: $0.30/hour + port fees ($200-14,000/month depending on speed)
- Bandwidth: 1 Gbps, 10 Gbps, or 100 Gbps
- Setup time: Weeks to months (physical cable installation)
- Uses: When you need guaranteed bandwidth, low latency, or move massive data

*"VPN = quick, cheap, encrypted over internet. Direct Connect = expensive, dedicated, fastest. Most companies start with VPN and add Direct Connect when they have performance requirements."*

---

## Part 17: Practical Demo — Build a VPC from Scratch (30 minutes)

### 🖥️ Demo: Complete VPC Setup in Console

*"Let's build a production-grade VPC from scratch. No defaults."*

#### Step 1: Create VPC

1. **VPC Console** → **Create VPC**
2. **VPC Settings:** Select **VPC only** (not VPC and more)

| Field | Value |
|-------|-------|
| Name | `streamflix-vpc` |
| CIDR | `10.0.0.0/16` |
| IPv6 | No |
| Tenancy | Default |

3. Create VPC

#### Step 2: Create Internet Gateway

1. **Internet Gateways** → **Create**
2. Name: `streamflix-igw`
3. Create → **Actions** → **Attach to VPC** → Select `streamflix-vpc`

#### Step 3: Create Subnets (4 subnets)

| Name | CIDR | AZ | Type |
|------|------|----|------|
| `public-subnet-1a` | `10.0.1.0/24` (251 IPs) | ap-south-1a | Public |
| `public-subnet-1b` | `10.0.2.0/24` (251 IPs) | ap-south-1b | Public |
| `private-subnet-1a` | `10.0.3.0/24` (251 IPs) | ap-south-1a | Private |
| `private-subnet-1b` | `10.0.4.0/24` (251 IPs) | ap-south-1b | Private |

For each: **Subnets** → **Create subnet** → Select VPC → Fill in name, AZ, CIDR

#### Step 4: Enable Auto-Assign Public IP for Public Subnets

1. Select `public-subnet-1a` → **Actions** → **Edit subnet settings**
2. Check **Enable auto-assign public IPv4 address** → Save
3. Repeat for `public-subnet-1b`

#### Step 5: Create Route Tables

**Public Route Table:**
1. **Route Tables** → **Create** → Name: `public-rt` → VPC: `streamflix-vpc`
2. Select `public-rt` → **Routes** tab → **Edit routes** → **Add route**
   - Destination: `0.0.0.0/0`
   - Target: `streamflix-igw` (Internet Gateway)
   - Save
3. **Subnet Associations** tab → **Edit** → Check both public subnets → Save

**Private Route Table:**
1. **Create** → Name: `private-rt` → VPC: `streamflix-vpc`
2. NO route to internet (we'll add NAT Gateway later if needed)
3. **Subnet Associations** → Check both private subnets → Save

#### Step 6: Create Security Groups

**ALB Security Group:**
1. **Security Groups** → **Create**
2. Name: `streamflix-alb-sg`, VPC: `streamflix-vpc`
3. Inbound:
   - HTTP (80) from `0.0.0.0/0`
   - HTTPS (443) from `0.0.0.0/0`

**App Security Group:**
1. Create → Name: `streamflix-app-sg`
2. Inbound:
   - Custom TCP (8080) from `streamflix-alb-sg` ← Reference the ALB SG!
   - SSH (22) from `your-ip/32`

**DB Security Group:**
1. Create → Name: `streamflix-db-sg`
2. Inbound:
   - MySQL (3306) from `streamflix-app-sg` ← Only app servers!

#### Step 7: Verify

```bash
# Launch an EC2 in the public subnet
# SSH into it
ssh -i key.pem ec2-user@<public-ip>

# Can you reach the internet?
curl -s ifconfig.me
# → Should show your public IP

# Launch an EC2 in the private subnet
# Try to SSH from the public instance (bastion pattern)
ssh -i key.pem ec2-user@10.0.3.x

# Can the private instance reach the internet?
curl -s --connect-timeout 5 ifconfig.me
# → Should TIMEOUT (no NAT Gateway yet)
```

*"See? The private instance can't reach the internet. It's isolated. That's exactly what we want."*

---

## Part 18: Interview Questions (5 minutes)

### 🗣️ Top 15 VPC Interview Questions

1. **What is a VPC?**
   → A logically isolated virtual network in AWS where you launch resources.

2. **What makes a subnet public vs private?**
   → A subnet is public if its route table has a route to an Internet Gateway (`0.0.0.0/0 → igw`).

3. **What's the difference between Security Group and NACL?**
   → SG: instance-level, stateful, allow-only, all rules evaluated. NACL: subnet-level, stateless, allow & deny, rules evaluated in order.

4. **What does stateful mean?**
   → Return traffic is automatically allowed. If you allow inbound port 80, outbound response is auto-allowed.

5. **Can a VPC span multiple AZs?**
   → Yes. A VPC spans ALL AZs in a region. But a subnet is bound to ONE AZ.

6. **Why are 5 IPs reserved in each subnet?**
   → Network address, VPC router, DNS, future use, broadcast.

7. **What is a NAT Gateway used for?**
   → Allows instances in private subnets to initiate outbound internet connections while preventing inbound connections.

8. **Is VPC Peering transitive?**
   → No. If A↔B and B↔C, A cannot reach C through B.

9. **What is a Gateway Endpoint?**
   → A free, route-based private connection to S3 or DynamoDB. No internet needed.

10. **What is the maximum CIDR size for a VPC?**
    → /16 (65,536 IPs). Minimum is /28 (16 IPs).

11. **Can Security Groups span VPCs?**
    → No. SGs are VPC-scoped.

12. **How do you troubleshoot "can't connect" in VPC?**
    → Check: Route table → NACL → Security Group → OS firewall → Application. Flow logs to see ACCEPT/REJECT.

13. **What is AWS PrivateLink?**
    → Interface VPC Endpoints that create private connections to AWS services using ENIs. No internet exposure.

14. **Can you SSH directly from the internet to a private subnet EC2?**
    → No. Use a bastion host in a public subnet, or Systems Manager Session Manager.

15. **What happens if you delete the main route table?**
    → You can't. The main route table can't be deleted. But you can replace it.

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1-2: Why VPC + CIDR | 30 min |
| Part 3-4: VPC + Subnets | 25 min |
| Part 5-6: IGW + NAT Gateway | 15 min |
| Part 7: Route Tables | 10 min |
| **☕ BREAK** | **10 min** |
| Part 8-9: Security Groups + NACLs | 30 min |
| Part 10-11: Peering + Endpoints | 20 min |
| Part 12-13: Elastic IP + Flow Logs | 15 min |
| Part 14-16: Bastion + Transit GW + VPN | 15 min |
| Part 17: Practical Demo | 30 min |
| Part 18: Interview Questions | 5 min |
| **Total** | **~3 hours** |

> **Trainer tip:** Take the break after Route Tables. The first half is "building blocks" — VPC, subnets, IGW, NAT, routes. The second half is "security + advanced" — SGs, NACLs, peering, endpoints. Students need the break to absorb.

> **Trainer tip:** During the practical demo, have students build their OWN VPC alongside you. Don't just show them — make them DO it. They should have a working VPC with 4 subnets, an IGW, and proper route tables by the end.
