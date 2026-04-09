# Route 53 — Complete Teaching Script

> **For the trainer:** This is your word-for-word classroom script. Read it, internalize it, adapt it to your style. Sections marked 🗣️ are what you SAY. Sections marked 🖥️ are what you DO on screen. Sections marked ❓ are questions to ask students.

---

## Part 1: What Problem Does DNS Solve? (15 minutes)

### 🗣️ Opening Hook

*"Okay everyone, I want you to do something right now. Open your browser and type this into the address bar:"*

```
142.250.193.206
```

*"What happened? Google loaded! Now type `google.com`. Same page. So here's my question — if computers only understand numbers, how does typing `google.com` magically find the right server out of billions of machines on the internet?"*

*"The answer is DNS — the Domain Name System. And today we're going to learn AWS Route 53, which is Amazon's DNS service. By the end of this session, you will:*
1. *Understand what DNS is and how it works behind the scenes*
2. *Know every record type and when to use which one*
3. *Understand all 8 routing policies*
4. *Actually configure DNS records in the AWS console and verify them*

*Let's start from absolute zero."*

---

### 🗣️ DNS Explained Like You're 5

*"Imagine the internet is a massive city with millions of buildings. Each building has an address — like `142.250.193.206`. That's an IP address. Now imagine trying to remember the address of every shop, restaurant, and office you visit. Impossible, right?"*

*"So we created a phonebook. You look up 'Google' and it tells you the address. DNS is that phonebook."*

*"But here's the thing — there isn't ONE phonebook. There's a hierarchy. Let me draw it:"*

### 🖥️ Draw on whiteboard or show diagram:

```
    You type: www.streamflix.com
          │
          ▼
    ┌─────────────┐
    │  Browser     │  "Do I already know this IP?" (Browser cache)
    │  Cache       │  If yes → done. If no → ask OS.
    └──────┬──────┘
           ▼
    ┌─────────────┐
    │  OS Cache /  │  Checks /etc/hosts file and OS DNS cache
    │  hosts file  │  If yes → done. If no → ask resolver.
    └──────┬──────┘
           ▼
    ┌─────────────┐
    │  ISP DNS     │  Your internet provider's resolver (Jio, Airtel, etc.)
    │  Resolver    │  "Do I have this cached?" If no → start the hunt.
    └──────┬──────┘
           ▼
    ┌─────────────┐
    │  Root DNS    │  13 root server clusters worldwide
    │  Server (.)  │  "I don't know streamflix.com, but go ask .com servers"
    └──────┬──────┘
           ▼
    ┌─────────────┐
    │  TLD Server  │  Manages all .com domains
    │  (.com)      │  "streamflix.com? Go ask these nameservers: ns-1234.awsdns-12.org"
    └──────┬──────┘
           ▼
    ┌─────────────────┐
    │  Authoritative   │  ← THIS IS ROUTE 53!
    │  DNS Server      │  "streamflix.com = 54.230.10.42. Here you go!"
    │  (Route 53)      │
    └─────────────────┘
```

*"Route 53 sits at the bottom of this chain. It's the AUTHORITATIVE server — the final source of truth. When someone asks 'where is streamflix.com?', Route 53 gives the definitive answer."*

### ❓ Ask Students:

*"Quick question — when you type google.com in your browser, how many DNS lookups happen? One? Five? Ten?"*

*"Answer: Usually ZERO. Because your browser, OS, and ISP all cache the result. A full DNS lookup only happens the very first time or when the cache expires. That expiry time is called TTL — Time to Live. We'll talk about that soon."*

---

## Part 2: What is AWS Route 53? (10 minutes)

### 🗣️ Why "Route 53"?

*"Two reasons for the name:*
1. *DNS uses **port 53** — that's the network port for DNS traffic*
2. *'Route' because it **routes** traffic to your resources*

*Simple. Now let me tell you what makes Route 53 special compared to regular DNS providers like GoDaddy or Namecheap DNS."*

### 🗣️ Key Facts About Route 53

*"Write these down — they come up in interviews:"*

| Fact | Detail |
|------|--------|
| **100% Availability SLA** | The ONLY AWS service that guarantees this. Not 99.99%. Not 99.999%. **100%.** |
| **Global Anycast Network** | Route 53 servers are everywhere. Your DNS query goes to the nearest one automatically. |
| **Not just DNS** | Route 53 does 3 things: Domain Registration, DNS Management, and Health Checking. |
| **Integrated with AWS** | Can directly point to ALBs, CloudFront, S3, Elastic Beanstalk — using ALIAS records (we'll cover this). |
| **Pricing** | $0.50/month per hosted zone + $0.40 per million queries. Domain registration: $3-12/year depending on TLD. |

### 🗣️ Three Functions of Route 53

*"Route 53 is not just a DNS server. It does THREE things:"*

**1. Domain Registration**
*"You can BUY domain names directly from AWS. Go to Route 53 → Registered Domains → Register Domain. Prices: `.com` = $12/year, `.click` = $3/year, `.io` = $32/year. When you buy here, Route 53 automatically creates a Hosted Zone for you."*

**2. DNS Management (Hosted Zones)**
*"This is the main feature. You create records that tell the internet where your stuff is. 'streamflix.com goes to this IP.' 'mail.streamflix.com goes to Google's mail servers.' That's DNS management."*

**3. Health Checks & Monitoring**
*"Route 53 can ping your servers every 10 or 30 seconds from multiple locations around the world. If a server stops responding, Route 53 can automatically route traffic away from it. This is how you build auto-failover."*

---

## Part 3: Hosted Zones Deep Dive (10 minutes)

### 🗣️ What is a Hosted Zone?

*"A Hosted Zone is basically a container — a folder — that holds all the DNS records for ONE domain. If you own `streamflix.com`, you create one hosted zone for it. Inside that hosted zone, you put all your records."*

### 🗣️ Public vs Private Hosted Zones

*"There are two types:"*

#### Public Hosted Zone
*"This is for domains accessible from the internet. When someone types `streamflix.com` in their browser, the public hosted zone answers."*

*"When you create a public hosted zone, Route 53 assigns 4 name servers (NS records) to it. These are your zone's 'address' in the DNS world."*

```
ns-1234.awsdns-12.org
ns-567.awsdns-23.co.uk
ns-890.awsdns-34.net
ns-101.awsdns-45.com
```

*"Why 4 servers in 4 different TLDs (.org, .co.uk, .net, .com)? Redundancy. Even if one entire TLD's infrastructure goes down, your DNS still works."*

#### Private Hosted Zone
*"This is for internal DNS that only works INSIDE a VPC. Your application servers need to talk to database servers? Instead of hardcoding IPs, use:*

```
database.internal.streamflix.com → 10.0.3.50
cache.internal.streamflix.com    → 10.0.4.20
```

*Nobody on the internet can resolve these. They only work inside your VPC. This is how big companies like Amazon organize their internal service discovery."*

### ❓ Ask Students:

*"If I buy a domain on GoDaddy but I want to manage DNS on Route 53, what do I need to do?"*

*"Answer: Create a hosted zone in Route 53 for that domain. Route 53 gives you 4 NS records. Go to GoDaddy → your domain → change nameservers → paste those 4 Route 53 NS records. Now Route 53 controls your DNS."*

### 🗣️ Auto-Created Records

*"When you create a hosted zone, Route 53 automatically creates TWO records. Don't delete them:"*

**1. NS Record (Name Server)**
*"Lists the 4 nameservers assigned to your zone. This is how the internet knows that Route 53 is the authority for your domain."*

**2. SOA Record (Start of Authority)**
*"Contains metadata: which nameserver is the primary, admin email, serial number (increments with every change), and timing values for how often secondary servers should refresh. You'll never need to edit this."*

---

## Part 4: Record Types — The Complete Guide (25 minutes)

### 🗣️ The Big Picture

*"DNS records are instructions. Each record says: 'When someone asks for THIS name, give them THIS answer.' There are different TYPES of answers you can give. Let me cover every single one."*

---

### 🗣️ A Record (Address Record)

*"The most fundamental record. Maps a domain name to an IPv4 address."*

```
streamflix.com  →  A  →  54.230.10.42
```

*"When to use:*
- *You have an EC2 instance with an Elastic IP*
- *You have an on-premises server with a static IP*
- *You want to point your domain directly to a known IP address*

*Limitation: The IP is static. If your server IP changes, you have to manually update the record."*

### 🗣️ AAAA Record (IPv6 Address)

*"Same as A record but for IPv6 addresses. IPv6 looks like this:"*

```
streamflix.com  →  AAAA  →  2600:1f18:4af6:1d01::1
```

*"When to use: When your infrastructure supports IPv6. Most modern AWS services are dual-stack (both IPv4 and IPv6). CloudFront, ALB, and S3 all support IPv6."*

*"Quick trivia: Why is it called AAAA and not just 'IPv6 record'? Because an IPv6 address is 4 times longer than IPv4. A = 1 unit, AAAA = 4 units. That's literally why."*

---

### 🗣️ CNAME Record — DNS to DNS Mapping

*"This is where students get confused, so pay attention."*

*"A CNAME maps one domain name to ANOTHER domain name. NOT to an IP. To another NAME."*

```
www.streamflix.com  →  CNAME  →  streamflix.com
blog.streamflix.com  →  CNAME  →  myblog.wordpress.com
```

*"How it works: Your browser asks for `www.streamflix.com`. DNS says 'that's actually `streamflix.com`'. Then your browser asks AGAIN for `streamflix.com`. DNS returns the IP. So there are TWO lookups. That's why CNAME is slightly slower."*

### 🗣️ ⚠️ THE CRITICAL CNAME RULE

*"Listen carefully — this is an interview favorite:"*

> **You CANNOT create a CNAME at the zone apex (root domain).**

*"What does that mean? You CANNOT do this:"*

```
❌  streamflix.com  →  CNAME  →  something.cloudfront.net
```

*"But you CAN do this:"*

```
✅  www.streamflix.com  →  CNAME  →  something.cloudfront.net
✅  blog.streamflix.com  →  CNAME  →  something.wordpress.com
```

*"Why? Because the DNS specification (RFC 1912) says: a CNAME record cannot coexist with any other record at the same name. But the root domain MUST have NS and SOA records. So CNAME at the root is illegal."*

*"This is a real problem. How do you point `streamflix.com` (no www) to CloudFront or an ALB? AWS invented the ALIAS record to solve this."*

### ❓ Ask Students:

*"I have an ALB with DNS name `my-alb-123.us-east-1.elb.amazonaws.com`. I want `streamflix.com` to point to it. Can I use a CNAME?"*

*"Answer: NO. Because `streamflix.com` is the root domain. You must use an ALIAS record."*

---

### 🗣️ ALIAS Record — AWS's Superpower ⭐

*"ALIAS is AWS's invention. It doesn't exist in standard DNS. It's only available in Route 53. And it's the single most important record type you'll use in AWS."*

*"An ALIAS record looks like an A record to the outside world (the client gets an IP address back), but internally Route 53 resolves the target DNS name for you."*

```
streamflix.com  →  ALIAS (A)  →  d3abc.cloudfront.net
                                  └── Route 53 resolves this to actual IPs
                                      and returns them directly
```

### 🗣️ CNAME vs ALIAS — The Comparison

*"Let me put them side by side so you never confuse them again:"*

| Feature | CNAME | ALIAS |
|---------|-------|-------|
| Works at zone apex (root domain)? | ❌ No | ✅ Yes |
| Query cost | $0.40 per million | **FREE** |
| Extra DNS hop? | Yes (slower) | No (resolved server-side) |
| Health check aware? | No | Yes |
| Can point to non-AWS targets? | ✅ Yes (any domain) | ❌ No (AWS resources only) |
| Standard DNS? | Yes (RFC standard) | No (AWS proprietary) |

### 🗣️ What Can ALIAS Point To?

*"ALIAS only works with these AWS resources:"*

1. **CloudFront distribution** — `d3abc.cloudfront.net`
2. **Application Load Balancer (ALB)** — `my-alb.us-east-1.elb.amazonaws.com`
3. **Network Load Balancer (NLB)**
4. **S3 website endpoint** — `my-bucket.s3-website-us-east-1.amazonaws.com`
5. **Elastic Beanstalk environment**
6. **API Gateway custom domain**
7. **Another Route 53 record in the SAME hosted zone**

*"Notice: you CANNOT use ALIAS to point to an EC2 instance, an RDS endpoint, or a third-party service. For those, use A records or CNAME."*

### 🗣️ Golden Rule

*"Here's the rule of thumb:*
- *Pointing to an AWS resource? → Use **ALIAS***
- *Pointing to a non-AWS resource? → Use **CNAME** (but not at root)*
- *Pointing to a static IP? → Use **A record***

*ALIAS is always preferred for AWS resources because it's free and faster."*

---

### 🗣️ MX Record (Mail Exchange)

*"MX records tell the internet where to deliver EMAIL for your domain."*

```
streamflix.com  →  MX  →  10  mail.google.com
                         └── Priority (lower = higher priority)
```

*"If you use Google Workspace or Microsoft 365 for email, you add their MX records. The number (10, 20, 30) is the PRIORITY. Lower number = tried first."*

```
streamflix.com  →  MX  10  mail1.google.com    ← Try this first
streamflix.com  →  MX  20  mail2.google.com    ← Fallback
streamflix.com  →  MX  30  mail3.google.com    ← Last resort
```

*"If mail1 is down, the sending server tries mail2. If that's down, mail3. That's how email achieves high availability."*

---

### 🗣️ TXT Record (Text Record)

*"TXT records store arbitrary text. Three main uses:"*

**1. Domain Verification**
*"Google, Microsoft, and many SaaS tools ask you to prove you own a domain by adding a TXT record:"*
```
streamflix.com  →  TXT  →  "google-site-verification=abc123xyz"
```

**2. SPF (Sender Policy Framework)**
*"Tells email servers which IPs are allowed to send email on behalf of your domain. Prevents email spoofing."*
```
streamflix.com  →  TXT  →  "v=spf1 include:_spf.google.com ~all"
```
*"This says: only Google's servers can send email as @streamflix.com. If anyone else tries, mark it as suspicious."*

**3. DKIM (DomainKeys Identified Mail)**
*"A cryptographic signature proving the email wasn't tampered with in transit."*

---

### 🗣️ NS Record (Name Server)

*"Lists which DNS servers are authoritative for this domain. Auto-created. You almost never touch these."*

```
streamflix.com  →  NS  →  ns-1234.awsdns-12.org
                          ns-567.awsdns-23.co.uk
                          ns-890.awsdns-34.net
                          ns-101.awsdns-45.com
```

*"The only time you manually deal with NS records is when you delegate a subdomain to a different hosted zone or a different DNS provider."*

---

### 🗣️ SOA Record (Start of Authority)

*"Contains zone metadata. Auto-created. Never delete it. Includes:"*
- Primary nameserver
- Admin email (encoded as `admin.streamflix.com`)
- Serial number (increments on every change)
- Refresh, retry, expire, and minimum TTL values

---

### 🗣️ CAA Record (Certificate Authority Authorization)

*"Controls which Certificate Authorities (CAs) are allowed to issue SSL certificates for your domain."*

```
streamflix.com  →  CAA  →  0 issue "amazon.com"
streamflix.com  →  CAA  →  0 issue "letsencrypt.org"
```

*"This says: only Amazon ACM and Let's Encrypt can issue SSL certificates for streamflix.com. If a hacker somehow tricks DigiCert into issuing a cert for your domain, it would be rejected because DigiCert isn't in your CAA list."*

*"It's a security measure. Big companies use it. AWS doesn't require it, but it's best practice."*

---

### 🗣️ SRV Record (Service Locator)

*"SRV records specify which server handles a specific SERVICE, including the PORT number."*

```
_sip._tcp.streamflix.com  →  SRV  →  10 5 5060 sip.example.com
                                      │  │ │    └── Target host
                                      │  │ └── Port
                                      │  └── Weight
                                      └── Priority
```

*"Used for VoIP (SIP), XMPP chat, LDAP, game servers. You probably won't use these in typical web apps, but they show up in interviews."*

---

### 🗣️ PTR Record (Pointer / Reverse DNS)

*"The opposite of an A record. Given an IP, return the domain name."*

```
42.10.230.54.in-addr.arpa  →  PTR  →  streamflix.com
```

*"Used by email servers to verify that the sending IP actually belongs to the claimed domain. If your email server at IP 54.230.10.42 claims to be streamflix.com, the receiving server does a reverse DNS lookup to confirm."*

---

## Part 5: TTL — Time to Live (5 minutes)

### 🗣️ What is TTL?

*"Every DNS record has a TTL value — measured in seconds. It tells DNS resolvers: 'cache this answer for X seconds, then ask again.'"*

```
streamflix.com  →  A  →  54.230.10.42  (TTL: 300)
```

*"This means: keep this IP cached for 300 seconds (5 minutes). During those 5 minutes, if anyone asks again, use the cached answer. After 5 minutes, ask Route 53 again."*

### 🗣️ TTL Strategy

| TTL | When to Use |
|-----|-------------|
| **60 seconds** | You're about to change something (migration, failover). Want fast propagation. |
| **300 seconds** (5 min) | Normal records that change occasionally. Good default. |
| **3600 seconds** (1 hour) | Stable records (MX, TXT) that rarely change. |
| **86400 seconds** (24 hours) | Records that NEVER change. Reduces DNS query costs. |

*"Pro tip: Before a migration, LOWER your TTL to 60 seconds a day in advance. Then make your change. After the change, raise TTL back to 3600. This ensures everyone gets the new IP within 60 seconds."*

### 🗣️ ALIAS Records and TTL

*"ALIAS records DON'T have a configurable TTL. Route 53 automatically sets the TTL to match the target resource. For example, if you ALIAS to a CloudFront distribution, Route 53 uses CloudFront's TTL (60 seconds)."*

---

## Part 6: Health Checks (10 minutes)

### 🗣️ What Are Health Checks?

*"Route 53 can monitor your servers from 15+ locations around the world. Every 10 or 30 seconds, it sends a request to your server. If enough health checkers report failure, Route 53 marks the endpoint as unhealthy."*

### 🗣️ Three Types of Health Checks

**1. Endpoint Health Check**
*"Hits a specific URL and checks the response."*
```
URL: http://54.230.10.42/health
Protocol: HTTP or HTTPS or TCP
Expected: HTTP 200 (or 2xx/3xx)
Interval: Every 10 or 30 seconds
Failure threshold: 3 consecutive failures = unhealthy
```

*"15 global health checkers vote. If >18% report healthy, the endpoint is considered healthy. So even if 2-3 checkers can't reach you (network blip), you're still healthy."*

**2. Calculated Health Check**
*"Combines results of OTHER health checks using AND, OR, or threshold logic."*
```
Child checks: web-server-1, web-server-2, web-server-3
Logic: At least 2 of 3 must be healthy
```

*"Use case: You have 3 servers behind a DNS record. You only want Route 53 to mark the record unhealthy if 2 or more servers are down."*

**3. CloudWatch Alarm Health Check**
*"Monitors a CloudWatch alarm instead of hitting a URL. If the alarm fires, Route 53 marks it unhealthy."*
```
CloudWatch alarm: database-cpu-above-90-percent
If alarm: ALARM state → endpoint marked unhealthy
```

*"Use case: Your database CPU is at 95%. You want Route 53 to route traffic to the DR region before the database crashes."*

### 🗣️ Health Check + Routing

*"Health checks are useless by themselves. They become powerful when combined with routing policies. If a weighted record's health check fails, Route 53 removes it from rotation. If a failover record's primary fails, traffic goes to secondary. This is automatic — no human intervention."*

---

## Part 7: Routing Policies — The Brain of Route 53 (30 minutes)

### 🗣️ Introduction

*"So far, all our records have been simple: name → value. But Route 53 can be SMART about which value it returns. It can split traffic, route by location, failover automatically, and more. These are called Routing Policies. There are 8 of them."*

---

### 🗣️ Policy 1: Simple Routing

*"The default. One name, one or more values. No intelligence."*

```
streamflix.com  →  A  →  54.230.10.42
```

*"If you put multiple IPs, Route 53 returns ALL of them. The client picks one randomly. That's it."*

**Key points:**
- *Only ONE record per name (can't create two A records for same name)*
- *NO health checks. If the server is dead, DNS still points to it.*
- *Use case: Single server, simple website, dev/test environments.*

### ❓ Ask Students:
*"What's the problem with Simple Routing if you have 3 IPs and one server dies?"*
*"Answer: DNS still returns the dead IP. 1 in 3 users get an error."*

---

### 🗣️ Policy 2: Weighted Routing

*"Distributes traffic by percentages. You assign a WEIGHT to each record."*

```
v2.streamflix.com  →  A  →  10.0.1.10  (Weight: 70)  ← 70% of traffic
v1.streamflix.com  →  A  →  10.0.2.20  (Weight: 30)  ← 30% of traffic
```

*"Formula: `percentage = weight / sum_of_all_weights`. So 70/(70+30) = 70%."*

**Use cases:**
- *Canary deployment: Send 5% to new version, 95% to old*
- *A/B testing: 50/50 split*
- *Gradual migration: Start at 10/90, increase to 50/50, then 100/0*
- *Setting weight to 0 = zero traffic (useful for maintenance)*

**Key points:**
- *Each record needs a unique 'Set ID' (just a label)*
- *Supports health checks — if a target fails, its weight redistributes*
- *All records must have the SAME name and type*

### 🗣️ Real-World Example

*"Netflix deploys a new version of their streaming service. They don't push it to 100% of users immediately. They set up weighted routing: 5% to the new version, 95% to the old. Engineers monitor error rates for 1 hour. If errors are low, bump to 25%, then 50%, then 100%. If errors spike, set new version weight to 0 immediately. Zero-downtime rollback."*

---

### 🗣️ Policy 3: Latency-Based Routing

*"Routes each user to the AWS region with the LOWEST network latency to them."*

```
User in Mumbai     → Route 53 → ap-south-1 (Mumbai)     12ms ✓
User in New York   → Route 53 → us-east-1 (Virginia)    8ms ✓
User in London     → Route 53 → eu-west-1 (Ireland)     15ms ✓
```

**How it works:**
*"AWS maintains a global latency database — they periodically measure latency from every major ISP to every AWS region. When a user's DNS resolver queries Route 53, it checks: 'What's the fastest region for this resolver's IP location?' and returns that region's IP."*

**Key points:**
- *It's NOT based on geographic distance. A user in India might get Dubai or Singapore if those are faster than Mumbai.*
- *You need to deploy your app in multiple AWS regions first.*
- *Each record specifies which region it's associated with.*
- *Supports health checks — if the nearest region is unhealthy, Route 53 picks the next fastest.*

### ❓ Ask Students:
*"Is latency-based routing the same as geolocation routing?"*
*"Answer: No! Latency = which server responds fastest. Geolocation = where the user physically is. A user in Dubai might get fastest response from Mumbai (latency), but geolocation would route them to a Middle East server if you configured one."*

---

### 🗣️ Policy 4: Failover Routing

*"Creates an active-passive pair. If the primary fails, traffic automatically goes to the secondary."*

```
                    Health Check
                        │
                        ▼
Primary:   app.streamflix.com  →  ALB-Virginia     (Failover: PRIMARY)
                                     │
                                     │ If health check fails 3 times...
                                     ▼
Secondary: app.streamflix.com  →  ALB-Ireland      (Failover: SECONDARY)
                                  OR
                              →  S3 "maintenance" page
```

**How it works:**
1. *Create a health check for the primary endpoint*
2. *Create primary record (Failover type = PRIMARY) with health check attached*
3. *Create secondary record (Failover type = SECONDARY)*
4. *If health check fails 3 consecutive times → Route 53 returns the secondary IP*
5. *When primary recovers → Route 53 switches back automatically*

**Key points:**
- *Only TWO records: primary and secondary. Not three or four.*
- *The secondary can be another ALB, another region, or a static S3 "sorry" page.*
- *Health check interval: 10 seconds (default) or 30 seconds.*
- *Switchover happens within ~1 minute of failure detection.*

### 🗣️ Real-World Example

*"A banking website runs in us-east-1 (Virginia). Standby in eu-west-1 (Ireland). In 2017, a massive S3 outage took down most of us-east-1. Banks using failover routing? Their customers were automatically routed to Ireland. Zero downtime. Banks NOT using failover? Down for 4 hours."*

### 🗣️ Common Pattern

*"The cheapest failover: Primary = your real ALB. Secondary = a static S3 website that just shows 'We're experiencing issues, please try again in a few minutes.' This costs almost nothing but saves your reputation during outages."*

---

### 🗣️ Policy 5: Geolocation Routing

*"Routes based on WHERE the user physically IS — country, continent, or US state."*

```
Japan users       → jp.streamflix.com  (Tokyo server)
European users    → eu.streamflix.com  (Ireland server)
Indian users      → in.streamflix.com  (Mumbai server)
Everyone else     → us.streamflix.com  (Virginia server - DEFAULT)
```

**This is NOT about performance. This is about CONTENT and COMPLIANCE.**

**Use cases:**
1. *Content licensing: Netflix shows different movies in different countries*
2. *GDPR compliance: EU users must be served from EU servers with EU data laws*
3. *Language: Japanese users see Japanese content, German users see German*
4. *Legal restrictions: Gambling sites blocked in certain countries*
5. *Pricing: Show different prices in different markets*

**Key points:**
- *You MUST create a DEFAULT record. Without it, users from unlisted countries get NXDOMAIN (no answer = site doesn't exist).*
- *Most specific match wins: Country > Continent > Default*
- *Route 53 determines location from the DNS resolver's IP, not the user's actual IP. Most of the time they're the same, but VPN users will appear to be in a different location.*

### ❓ Ask Students:
*"I set up geolocation routing. India → Mumbai server. But I forgot to create a Default record. A user from Brazil tries to access my site. What happens?"*

*"Answer: They get NXDOMAIN — the site doesn't exist for them. That's why the Default record is CRITICAL."*

---

### 🗣️ Policy 6: Geoproximity Routing

*"Routes based on geographic DISTANCE with a configurable BIAS to shift traffic."*

*"Think of it like this — each resource has a 'magnetic field' around it. The bias control makes the field bigger or smaller."*

```
Mumbai (bias: +25)  ← Attracts more traffic (bigger catchment area)
Virginia (bias: 0)  ← Normal area
Ireland (bias: -10) ← Shrinks area (repels traffic)
```

**How bias works:**
- *Bias range: -99 to +99*
- *Positive bias = grow the region's area = attract more traffic*
- *Negative bias = shrink the region's area = push traffic to neighbors*
- *Bias 0 = pure geographic distance*

**Important:** *This is ONLY available via Route 53 Traffic Flow (the visual policy editor). You can't create geoproximity records normally. Traffic Flow costs $50/month per policy.*

**Use case:**
*"You're expanding into a new market. You launched Mumbai servers but most Middle East traffic still goes to Ireland (distance-wise). Set Mumbai bias to +25 → some Middle East users start getting routed to Mumbai. Increase to +50 over weeks as you add capacity."*

### 🗣️ Geolocation vs Geoproximity

| Feature | Geolocation | Geoproximity |
|---------|-------------|--------------|
| Based on | Country/continent boundaries | Physical distance + bias |
| Granularity | Country, continent, US state | Continuous distance calculation |
| Can shift traffic? | No (hard boundaries) | Yes (bias control) |
| Needs Traffic Flow? | No | Yes ($50/month) |

---

### 🗣️ Policy 7: Multivalue Answer Routing

*"Returns UP TO 8 healthy IP addresses. The client randomly picks one."*

```
User query → Route 53 returns:
  10.0.1.10  ✅ (healthy)
  10.0.2.20  ✅ (healthy)
  10.0.3.30  ❌ (unhealthy — NOT returned)
  10.0.4.40  ✅ (healthy)
```

*"It's like Simple Routing WITH health checks."*

**Key difference from Simple Routing:**
| Feature | Simple | Multivalue |
|---------|--------|------------|
| Health checks | ❌ | ✅ |
| Dead IPs returned | Yes | No |
| Multiple records | One record, multiple values | Multiple records, one value each |
| Set IDs | Not needed | Required |

**Is this a replacement for ALB?**
*"NO. ALB is Layer 7 load balancing — it understands HTTP, supports sticky sessions, path-based routing, WebSocket, etc. Multivalue is just DNS-level distribution. It has no concept of connection persistence. Use Multivalue only when you can't afford an ALB (~$16/month) and you just need basic distribution."*

---

### 🗣️ Policy 8: IP-Based Routing

*"The newest routing policy (added 2022). Routes based on the CLIENT'S IP ADDRESS RANGE."*

*"You create CIDR collections — groups of IP ranges — and associate them with DNS records."*

```
Jio users (203.0.113.0/24)        → Mumbai CDN endpoint
Airtel users (198.51.100.0/24)    → Chennai CDN endpoint  
Everyone else                      → Default endpoint
```

**Use cases:**
- *ISP-specific optimization: Route Jio users to a CDN with better Jio peering*
- *Enterprise: Route office network IPs to internal servers*
- *Compliance: Ensure specific networks reach specific regions*

*"This is rarely seen in interviews but very useful for ISPs and large enterprises."*

---

## Part 8: Route 53 Traffic Flow (5 minutes)

### 🗣️ What is Traffic Flow?

*"Traffic Flow is Route 53's VISUAL POLICY EDITOR. Instead of creating individual records, you build a flowchart-style diagram:"*

```
[Start] → [Geolocation Rule]
              │
              ├── Asia → [Latency Rule]
              │              ├── Mumbai ← bias +10
              │              └── Singapore
              │
              ├── Europe → [Weighted Rule]
              │              ├── Ireland (70%)
              │              └── Frankfurt (30%)
              │
              └── Default → [Failover Rule]
                               ├── Primary: Virginia
                               └── Secondary: S3 maintenance page
```

*"You can COMBINE routing policies! Geolocation at the top, then latency within a region, then failover as the last resort. This is how Netflix, Amazon, and global SaaS companies route traffic."*

**Cost:** *$50/month per traffic policy. Not per query — per policy. Most companies have 1-3 policies.*

---

## Part 9: Practical Demo (30 minutes)

### 🖥️ Demo 1: Show Route 53 Console

*"Let me open the AWS console and show you everything we just talked about."*

1. **Open Route 53 Console**
   - Show the three sections: Hosted Zones, Health Checks, Registered Domains
   - Open your hosted zone → show the auto-created NS and SOA records

2. **Show the Record Creation Form**
   - Click "Create Record"
   - Show all record types in the dropdown (A, AAAA, CNAME, MX, TXT, NS, SOA, SRV, CAA, PTR)
   - Show the "Alias" toggle
   - Show the "Routing Policy" dropdown (Simple, Weighted, Latency, Failover, Geolocation, Multivalue, IP-based)
   - Show the TTL field

### 🖥️ Demo 2: Deploy StreamFlix and Map DNS

*"Now let's actually DO it. I have a web server running on EC2. Let's map a domain name to it."*

**Step 1: Show the EC2 instance**
```bash
# Visit via IP
open http://<EC2-PUBLIC-IP>
# "See? The app works. But the URL is just an IP. Ugly and unmemorable."
```

**Step 2: Create an A Record**
```
Record name: server1
Type: A
Value: <EC2-PUBLIC-IP>
TTL: 60
Routing: Simple
```

**Step 3: Verify with dig**
```bash
dig server1.yourdomain.com A +short
# → 54.230.10.42

# "BOOM. We just mapped an IP to a name. This is the most basic DNS operation."
```

**Step 4: Visit via domain name**
```bash
open http://server1.yourdomain.com
# "Same page! But now accessible via a human-readable URL."
```

### 🖥️ Demo 3: Show ALB Load Balancing + ALIAS

*"Now watch this. I have TWO EC2 instances behind an ALB."*

```bash
# Hit the ALB directly — notice the instance ID changes
for i in {1..6}; do
  echo "Request $i: $(curl -s http://<ALB-DNS>/metadata.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"instance_id\"]} in {d[\"availability_zone\"]}')")"
done
```

*"See the instance ID alternating? That's load balancing. Now let's map a domain to this ALB."*

**Create ALIAS Record:**
```
Record name: app
Type: A
Alias: YES
Route traffic to: Application Load Balancer → us-east-1 → select your ALB
```

```bash
dig app.yourdomain.com A +short
# Returns ALB IPs (they change!)

open http://app.yourdomain.com
# "Refresh! Watch the green banner — the instance ID changes!"
```

### 🖥️ Demo 4: CNAME

```
Record name: www
Type: CNAME
Value: app.yourdomain.com
TTL: 300
```

```bash
dig www.yourdomain.com CNAME +short
# → app.yourdomain.com

open http://www.yourdomain.com
# "Same site! www → app → ALB → EC2. Three DNS hops."
```

### 🖥️ Demo 5: Show the StreamFlix DNS Simulator

*"Now open the StreamFlix app and scroll to the Route 53 section. See the DNS Lookup Simulator? Try each scenario — it shows you exactly what a `dig` command returns for each record type and routing policy."*

---

## Part 10: Interview Questions to Close (5 minutes)

### 🗣️ Top 10 Route 53 Interview Questions

*"Before we close, let me give you the top 10 questions that interviewers ask about Route 53. Write these down:"*

1. **What's the difference between CNAME and ALIAS?**
   → CNAME: standard DNS, maps name→name, costs money, can't be at zone apex. ALIAS: AWS-only, maps name→AWS resource, free, works at zone apex.

2. **Can you create a CNAME at the zone apex?**
   → No. DNS RFC prohibits it. Use ALIAS instead.

3. **What's the 100% SLA mean?**
   → Route 53 guarantees 100% availability — the only AWS service with this guarantee.

4. **Difference between Latency and Geolocation routing?**
   → Latency: fastest server. Geolocation: user's physical country. A user in India might get Singapore (latency) but India (geolocation).

5. **How does failover routing work?**
   → Health check monitors primary. 3 failures → traffic to secondary. Primary recovers → switches back.

6. **What's a hosted zone?**
   → A container for DNS records for one domain. Public (internet) or Private (VPC only).

7. **What happens if you don't create a Default record in geolocation routing?**
   → Users from unlisted countries get NXDOMAIN (site doesn't exist).

8. **Can Route 53 do health checks on resources in other clouds (GCP, Azure)?**
   → Yes. Health checks work on any public endpoint. They just ping a URL.

9. **Weighted routing — what happens if you set all weights to 0?**
   → Route 53 returns all records equally (same as Simple routing). It's a fallback behavior.

10. **What is Traffic Flow?**
    → Visual policy editor that lets you combine routing policies. Costs $50/month per policy.

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1: DNS Problem | 15 min |
| Part 2: What is Route 53 | 10 min |
| Part 3: Hosted Zones | 10 min |
| Part 4: Record Types | 25 min |
| Part 5: TTL | 5 min |
| Part 6: Health Checks | 10 min |
| Part 7: Routing Policies | 30 min |
| Part 8: Traffic Flow | 5 min |
| Part 9: Practical Demo | 30 min |
| Part 10: Interview Questions | 5 min |
| **Total** | **~2.5 hours** |

> **Trainer tip:** Take a 10-minute break after Part 4 (record types). That's the densest section. Students need a mental reset before routing policies.
