# AWS Certificate Manager (ACM) — Complete Teaching Script

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~3 hour session with break.

---

# SECTION A: UNDERSTANDING SSL/TLS & CERTIFICATES

## Part 1: Why Do We Need Certificates? (15 minutes)

### 🗣️ Opening Hook

*"Open your browser right now. Go to any website — Amazon, Google, whatever. Look at the address bar. See that little padlock icon? Click on it."*

*"It says 'Connection is secure.' But what does that mean? And more importantly — what happens if that padlock is MISSING?"*

*"Let me show you."*

### 🖥️ Show the Difference

```
🔒 https://streamflix.sskdevops.in     ← Padlock. Users trust this.
⚠️  http://streamflix.sskdevops.in      ← "Not Secure" warning. Users RUN.
```

*"Google Chrome literally labels HTTP sites as 'NOT SECURE' in red text. Safari shows a warning popup. Firefox blocks form submissions. If your site doesn't have HTTPS, you've already lost."*

*"But it's not just about trust badges. Without HTTPS, here's what can happen on a coffee shop WiFi:"*

```
You at Starbucks                     Hacker on same WiFi
       │                                    │
       ├──── HTTP (plain text) ─────────────┤
       │     POST /login                    │
       │     username=saikiran              │ ← Hacker reads EVERYTHING
       │     password=MyS3cret!             │
       │     credit_card=4111-1111-1111     │
       │                                    │
       └────────────────────────────────────┘

vs.

       ├──── HTTPS (encrypted) ────────────┤
       │     f4c8a92b1e7d3f6...            │ ← Hacker sees GARBAGE
       │     8b2e4a91c7f3d5a...            │
       └────────────────────────────────────┘
```

*"HTTPS encrypts EVERYTHING — the URL path, the body, the headers, the cookies. The ONLY thing visible to an attacker is the DESTINATION IP and that you're connecting. They can't see WHAT you're sending."*

### 🗣️ The Three Pillars of HTTPS

*"SSL/TLS certificates solve THREE problems:"*

| Problem | What It Means | Without It |
|---------|--------------|------------|
| **Encryption** | Data is scrambled in transit | Hackers read your passwords, credit cards, API keys |
| **Authentication** | Proves the server IS who it claims to be | Hacker sets up fake `amaz0n.com` and steals your login |
| **Integrity** | Ensures data wasn't tampered with | ISP injects ads into your pages. Hacker modifies API responses. |

*"A certificate is like a PASSPORT for your website. A passport proves your identity, is issued by a trusted authority (government), and has an expiry date. A certificate proves your server's identity, is issued by a Certificate Authority (CA), and also expires."*

### 🗣️ How TLS Works — The Handshake

*"When your browser connects to `https://streamflix.sskdevops.in`, this happens in about 50 milliseconds:"*

```
Browser                                     Server (ALB/CloudFront)
   │                                            │
   │  1. ClientHello                             │
   │     "Hi! I support TLS 1.3, 1.2.           │
   │      I can do AES-256-GCM, ChaCha20.       │
   │      Here's my random number."             │
   │  ──────────────────────────────────────►    │
   │                                            │
   │  2. ServerHello + Certificate              │
   │     "Let's use TLS 1.3 + AES-256-GCM.     │
   │      Here's MY random number.              │
   │      Here's my certificate (signed by      │
   │      Amazon Trust Services CA)."           │
   │  ◄──────────────────────────────────────   │
   │                                            │
   │  3. Browser verifies certificate            │
   │     ✅ Is it expired? No.                   │
   │     ✅ Is the CA trusted? Yes (Amazon).     │
   │     ✅ Does domain match? Yes.              │
   │     ✅ Is it revoked? No.                   │
   │                                            │
   │  4. Key Exchange (ECDHE)                    │
   │     Both sides generate a shared secret     │
   │     without ever sending it on the wire.   │
   │  ◄──────────────────────────────────────►  │
   │                                            │
   │  5. Encrypted Application Data              │
   │     All HTTP traffic is now encrypted.     │
   │  ◄═══════════════════════════════════════► │
   │                                            │
```

*"The key insight: the certificate is NEVER used to encrypt data. It's used to VERIFY identity. The actual encryption key is generated fresh for every session using Diffie-Hellman exchange. That's called Perfect Forward Secrecy — even if someone steals your certificate's private key, they can't decrypt past sessions."*

### ❓ Ask Students:

*"If I have a self-signed certificate (I sign it myself, no CA involved), will the browser show the padlock?"*

*"Answer: NO. The browser doesn't trust self-signed certs. You'll get a scary 'Your connection is not private' page. Self-signed is fine for internal development, but NEVER for production."*

---

## Part 2: Certificate Authorities & Trust Chain (10 minutes)

### 🗣️ Who Issues Certificates?

*"You can't just create a certificate and expect the world to trust it. A trusted third party must vouch for you. These are called Certificate Authorities (CAs)."*

| CA | Who Uses Them | Cost |
|----|--------------|------|
| **Amazon Trust Services** | Anyone using ACM | **FREE** (only on AWS resources) |
| **Let's Encrypt** | Open source projects, small sites | **FREE** (but you manage renewal) |
| **DigiCert** | Banks, enterprises | $200-1,000/year |
| **Sectigo (Comodo)** | Mid-market | $70-500/year |
| **GlobalSign** | Government, large enterprise | $250-1,500/year |

*"Why should you care about the CA? Because every browser and OS ships with a pre-installed list of trusted CAs. If your certificate is signed by one of those CAs, browsers trust it automatically. If not — scary warning page."*

### 🗣️ The Chain of Trust

```
Root CA (Amazon Root CA 1)              ← Pre-installed in browsers/OS
       │                                    Kept OFFLINE in a vault
       │ signs
       ▼
Intermediate CA (Amazon CA 1)           ← Used for actual signing
       │                                    If compromised, revoke without
       │ signs                              affecting the root
       ▼
Your Certificate (streamflix.sskdevops.in)  ← What ACM gives you
       │
       │ presented to
       ▼
Browser ────► checks chain ────► Root CA in trust store? ✅ TRUSTED
```

*"Why the intermediate CA? Security. The Root CA's private key is the crown jewel. It's stored in a hardware security module (HSM) in a vault, air-gapped from the internet. If the intermediate CA is compromised, Amazon revokes it and issues a new one. The Root CA stays safe."*

### 🗣️ Certificate Types by Validation Level

*"Not all certificates are created equal:"*

| Type | Validation | Time | Cost | Visual |
|------|-----------|------|------|--------|
| **DV (Domain Validation)** | Prove you own the domain | Minutes | Free-$50 | 🔒 Padlock |
| **OV (Organization Validation)** | DV + verify company exists | Days | $50-200 | 🔒 Padlock + Company in cert details |
| **EV (Extended Validation)** | OV + legal docs, phone call | Weeks | $200-1,500 | 🔒 Padlock (green bar removed in 2019) |

*"ACM provides DV certificates. For 99% of use cases, this is all you need. The green address bar that EV used to give? Chrome removed it in 2019. So paying $1,000+ for EV is mostly pointless now."*

---

## Part 3: What is AWS Certificate Manager? (10 minutes)

### 🗣️ ACM Overview

*"ACM is AWS's certificate management service. It does ONE thing incredibly well: it gives you FREE SSL/TLS certificates and handles ALL the painful parts automatically."*

| Feature | Detail |
|---------|--------|
| **Cost** | 🆓 **FREE** for public certificates used on AWS resources |
| **Renewal** | ✅ **Automatic** — certificates renew before expiry, zero intervention |
| **Validation** | DNS validation (recommended) or Email validation |
| **Wildcard** | `*.sskdevops.in` covers ALL subdomains in one cert |
| **SANs** | Add multiple domain names to one certificate |
| **Private key** | You NEVER see it. AWS manages it in HSMs. Cannot be exported. |
| **Integration** | ALB, NLB, CloudFront, API Gateway, Elastic Beanstalk, App Runner |
| **Region** | Certificate must be in the SAME region as the resource. Exception: CloudFront requires `us-east-1`. |

### 🗣️ Why ACM is a Game Changer

*"Before ACM, here's what managing certificates looked like:"*

```
The Old Way (Manual):
1. Generate a private key          ← Don't lose this!
2. Create a CSR (Certificate 
   Signing Request)                ← Encode your domain info
3. Buy a cert from DigiCert        ← $200+, wait for approval
4. Download the cert files          ← .crt, .key, .pem, .ca-bundle
5. Upload to your server            ← nginx config, restart
6. Set a calendar reminder for 
   1 year from now                  ← MANUAL RENEWAL
7. Panic when the cert expires 
   and your site goes down at 2 AM  ← This happens to EVERYONE

The ACM Way:
1. Request certificate              ← 3 clicks  
2. Validate domain ownership        ← 1 click (auto-create DNS record)
3. Attach to ALB/CloudFront         ← Select from dropdown
4. Done. Forever.                   ← Auto-renewal. Zero worry.
```

*"In 2017, Equifax's certificate expired on their security monitoring tool. They didn't notice for 76 days. During those 76 days, hackers stole data of 147 MILLION people. The biggest data breach in history — caused by a forgotten certificate renewal."*

*"ACM makes that scenario impossible."*

### ❓ Ask Students:

*"Can I use an ACM certificate on my on-premises nginx server?"*

*"Answer: NO. ACM certificates can ONLY be used on AWS-managed resources (ALB, CloudFront, API Gateway, etc.). You can't download or export the private key. If you need a cert for a non-AWS server, use ACM Private CA or a traditional CA like Let's Encrypt."*

---

## Part 4: ACM Public vs Private Certificates (10 minutes)

### 🗣️ Two Modes of ACM

*"ACM has two completely different products:"*

| Feature | ACM Public Certificates | ACM Private CA |
|---------|------------------------|----------------|
| **Trust** | Trusted by ALL browsers globally | Trusted only by systems you configure |
| **Cost** | 🆓 FREE | 💰 $400/month per CA + $0.75 per cert |
| **Use case** | Public websites, APIs | Internal microservices, IoT, VPN |
| **Exportable** | ❌ No (can't download private key) | ✅ Yes (install anywhere) |
| **Validation** | DNS or Email | No validation needed (you ARE the CA) |
| **Renewal** | Automatic (ACM managed) | Automatic (ACM managed) |

### 🗣️ When to Use Private CA

```
Public Internet (ACM Public):
  Users → Browser → https://streamflix.sskdevops.in → CloudFront → ALB
                     └── ACM public cert ──────────────┘

Internal Network (ACM Private CA):
  Microservice A → https://payments.internal:8443 → Microservice B
                    └── ACM private cert ────────────┘
  
  IoT Device → mTLS → https://iot-gateway.internal → IoT Core
               └── ACM private cert (installed on device)
```

*"Private CA is for companies running hundreds of internal microservices that need mutual TLS (mTLS). Each service has its own certificate. The services verify each other's identity before communicating. This is zero-trust networking."*

*"For our StreamFlix labs, we'll use public certificates — that's what 99% of you will use in real jobs."*

---

# SECTION B: ACM DEEP DIVE

## Part 5: Requesting a Certificate (15 minutes)

### 🗣️ Step-by-Step: What Happens When You Request

```
You: "I want a cert for streamflix.sskdevops.in"
                    │
                    ▼
┌─────────────────────────────────────────┐
│  ACM creates the certificate             │
│  Status: PENDING_VALIDATION              │
│                                          │
│  "Prove you own this domain first."      │
│                                          │
│  Option A: DNS Validation                │
│    → Add this CNAME to Route 53:         │
│    _abc123.streamflix.sskdevops.in        │
│       → _def456.acm-validations.aws      │
│                                          │
│  Option B: Email Validation              │
│    → We'll email these addresses:        │
│    admin@sskdevops.in                    │
│    hostmaster@sskdevops.in               │
│    postmaster@sskdevops.in               │
│    webmaster@sskdevops.in                │
│    administrator@sskdevops.in            │
└─────────────────────────────────────────┘
                    │
                    ▼ (after validation)
┌─────────────────────────────────────────┐
│  Status: ISSUED ✅                       │
│  Valid for: 13 months                    │
│  Auto-renewal: YES                       │
│                                          │
│  You can now attach this to:             │
│  • ALB  • NLB  • CloudFront             │
│  • API Gateway  • App Runner             │
└─────────────────────────────────────────┘
```

### 🗣️ DNS Validation vs Email Validation

| Aspect | DNS Validation | Email Validation |
|--------|---------------|-----------------|
| **How it works** | Add a CNAME record to your DNS | Click a link in an email |
| **Auto-renewal** | ✅ YES (ACM checks the CNAME exists) | ❌ NO (must click email again) |
| **Best for** | Production (always use this) | Quick test when you don't control DNS |
| **Time to validate** | 5-30 minutes | Depends on email speed |
| **Requires** | Access to DNS management | Access to domain admin email |

*"ALWAYS use DNS validation. Here's why: with DNS validation, ACM can automatically renew your certificate forever — it just checks that the CNAME record still exists. With email validation, someone has to click a link every 13 months. Forget once? Certificate expires. Site goes down."*

### 🗣️ The Validation CNAME Record

*"When you request a certificate, ACM gives you a CNAME record to add:"*

```
Record Name:  _a79865eb4cd1a6ab990a45779b4e0b96.streamflix.sskdevops.in
Record Value: _1e2ff8eb5dae3f3e6fb7c59e9e4e8e0c.mhbtsbpdnt.acm-validations.aws

Type: CNAME
```

*"This looks weird, but it's simple: ACM generated a unique token. By adding this CNAME to your DNS, you prove you control the domain. ACM checks it periodically, and as long as it exists, your cert stays valid."*

*"If your domain is in Route 53 — even easier. Click ONE button: 'Create records in Route 53.' Done."*

### ❓ Ask Students:

*"I request a certificate for `streamflix.sskdevops.in` and add the DNS validation record. It's been 2 hours and the status still shows 'Pending validation.' What could be wrong?"*

*"Answer: Check if the CNAME record was created in the CORRECT hosted zone. If you have both a public and private hosted zone for `sskdevops.in`, the record might be in the private one. ACM validates against PUBLIC DNS. Also check for typos in the CNAME value."*

---

## Part 6: Certificate Domain Names & Wildcards (10 minutes)

### 🗣️ Fully Qualified Domain Name (FQDN) vs Wildcard

```
FQDN (specific):
  streamflix.sskdevops.in        ← Covers ONLY this exact domain
  api.sskdevops.in               ← Need a separate cert (or add as SAN)

Wildcard:
  *.sskdevops.in                 ← Covers ALL subdomains:
                                     streamflix.sskdevops.in ✅
                                     api.sskdevops.in ✅
                                     admin.sskdevops.in ✅
                                     anything.sskdevops.in ✅
                                     
                                  BUT NOT:
                                     sskdevops.in ❌ (root domain)
                                     deep.sub.sskdevops.in ❌ (multi-level)
```

### 🗣️ Subject Alternative Names (SANs)

*"ACM lets you put up to 10 domain names (including wildcards) on ONE certificate. These are called SANs."*

```
Certificate for StreamFlix:
  Primary domain:     sskdevops.in
  SAN 1:              *.sskdevops.in
  SAN 2:              streamflix.com      (if you own this too)
  SAN 3:              *.streamflix.com

One certificate, four domains. All share the same cert.
```

*"This is how companies cover their entire domain portfolio with one certificate."*

### 🗣️ Best Practice: What to Request

| Scenario | What to Request | Why |
|----------|----------------|-----|
| **Simple app** | `app.sskdevops.in` | Covers the specific subdomain |
| **Multi-subdomain** | `*.sskdevops.in` + `sskdevops.in` (as SAN) | Covers root + all subdomains |
| **Multi-domain** | Primary: `sskdevops.in`, SANs: `*.sskdevops.in`, `streamflix.com`, `*.streamflix.com` | Covers everything |
| **CloudFront + ALB** | Two separate certificates — one in `us-east-1` for CloudFront, one in your app's region for ALB | CloudFront requires `us-east-1` |

### ❓ Ask Students:

*"I have a wildcard cert for `*.sskdevops.in`. Will it work for `deep.nested.sskdevops.in`?"*

*"Answer: NO. Wildcard only covers ONE level of subdomain. `deep.nested.sskdevops.in` has two levels. You'd need a separate cert for `*.nested.sskdevops.in` or specify it as a SAN."*

---

## Part 7: Certificate Auto-Renewal (10 minutes)

### 🗣️ How Auto-Renewal Works

*"ACM certificates are valid for 13 months. ACM starts the renewal process 60 days before expiry."*

```
Day 0:    Certificate issued. Valid until Day 395 (13 months).
Day 335:  ACM starts renewal process (60 days before expiry).

For DNS-validated certs:
  ACM checks: "Does the CNAME validation record still exist in DNS?"
    YES → New cert issued automatically. Rotated in place. Zero downtime.
    NO  → ⚠️ Renewal fails. ACM sends email warning. Fix it!

For email-validated certs:
  ACM sends renewal email to domain contacts.
  Someone must click the approval link.
  If no one clicks within 45 days → CERT EXPIRES. ☠️
```

### 🗣️ Renewal Failure Scenarios

| Scenario | What Happens | Fix |
|----------|-------------|-----|
| DNS validation CNAME deleted | Renewal fails, ACM sends warning email | Re-add the CNAME record |
| Domain transferred to another registrar | NS records changed, validation fails | Update validation records in new DNS |
| Certificate not attached to any resource | ACM doesn't auto-renew unused certs | Attach it or re-validate |
| Email validation, no one clicks | Cert expires after grace period | Switch to DNS validation |

*"This is why DNS validation is non-negotiable for production. Set it up once, forget about it forever. Email validation is a ticking time bomb."*

### 🗣️ Monitoring Certificate Expiry

*"Even with auto-renewal, monitor your certificates:"*

```
CloudWatch Metric:
  Namespace: AWS/CertificateManager
  Metric:    DaysToExpiry
  
  Alarm: If DaysToExpiry < 30 → SNS notification
  
  "If auto-renewal is working, you'll never see 
   DaysToExpiry drop below ~350 (it renews at 60 
   days before expiry, so it jumps back to 395)."
```

*"If DaysToExpiry is dropping below 60 and keeps going — SOMETHING IS WRONG with renewal. Investigate immediately."*

---

## Part 8: ACM Regional Requirements (10 minutes)

### 🗣️ The #1 ACM Gotcha — Region

*"This catches EVERYONE the first time, even experienced engineers:"*

```
┌────────────────────────────────────────────────────┐
│                   THE RULE                          │
│                                                    │
│  CloudFront → Certificate MUST be in us-east-1     │
│  ALB/NLB   → Certificate MUST be in SAME region    │
│  API Gateway → Certificate MUST be in SAME region  │
│  (Edge API GW → us-east-1)                        │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 🗣️ StreamFlix Example

```
StreamFlix Architecture:

CloudFront (Global)
  └── Cert: *.sskdevops.in               📍 MUST be in us-east-1
  
ALB in ap-south-1 (Mumbai)
  └── Cert: api.sskdevops.in             📍 MUST be in ap-south-1

ALB in us-east-1 (Virginia)
  └── Cert: api-us.sskdevops.in          📍 MUST be in us-east-1

API Gateway (Edge-optimized)
  └── Cert: api.sskdevops.in             📍 MUST be in us-east-1

API Gateway (Regional, Mumbai)
  └── Cert: api.sskdevops.in             📍 MUST be in ap-south-1
```

*"If you're deploying globally, you might need the SAME domain name on certificates in MULTIPLE regions. ACM lets you request the same domain in different regions — they're independent certificates."*

### 🗣️ Common Mistake

*"A student deploys an ALB in Mumbai, requests a certificate in Mumbai, attaches it — works perfectly. Then they create a CloudFront distribution and try to use the same certificate. ERROR."*

```
❌  "Certificate arn:aws:acm:ap-south-1:123:cert/abc not found"
    CloudFront is looking in us-east-1, but the cert is in ap-south-1!

✅  Solution: Request a SECOND certificate in us-east-1 for the same domain.
    One cert for ALB (ap-south-1), one cert for CloudFront (us-east-1).
```

### ❓ Ask Students:

*"I have an ALB in eu-west-1 (Ireland) and CloudFront in front of it. How many ACM certificates do I need?"*

*"Answer: TWO. One in eu-west-1 for the ALB's HTTPS listener. One in us-east-1 for CloudFront. Same domain name, different regions."*

---

## Part 9: ACM Integration with AWS Services (15 minutes)

### 🗣️ Service-by-Service Integration

#### 1. ALB (Application Load Balancer)

```
Internet → ALB (HTTPS:443) → EC2 (HTTP:80)
            └── ACM cert terminates TLS here
            └── EC2 doesn't need to know about certs
```

| Setting | Value |
|---------|-------|
| Listener | HTTPS, Port 443 |
| Certificate source | ACM |
| Security policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.3 + 1.2) |
| SNI support | Up to 25 certificates per listener |

*"The ALB decrypts HTTPS, inspects the HTTP request (path, headers, host), routes to the correct target group, and forwards as plain HTTP to EC2. Your app code never touches TLS."*

**HTTP → HTTPS Redirect:**
```
Listener 1 (HTTP:80):
  Default action: Redirect to HTTPS:443, status 301

Listener 2 (HTTPS:443):
  Default action: Forward to target group
  Certificate: arn:aws:acm:ap-south-1:123:cert/abc
```

*"ALWAYS create both listeners. HTTP:80 redirects to HTTPS:443. This way, users who type `http://streamflix.sskdevops.in` automatically get upgraded to HTTPS."*

#### 2. CloudFront

```
Users → CloudFront Edge (HTTPS) → S3 or ALB (HTTP/HTTPS)
         └── ACM cert (us-east-1 ONLY)
         └── TLS 1.2 minimum recommended
```

| Setting | Value |
|---------|-------|
| Certificate region | **us-east-1 (N. Virginia) ONLY** |
| SSL support method | SNI (recommended, free) or Dedicated IP ($600/month) |
| Minimum TLS version | TLSv1.2_2021 (recommended) |
| Alternate domain (CNAME) | Must match cert domain |

*"CloudFront is a global CDN — it doesn't 'live' in any single region. But the certificate configuration is stored in us-east-1 because that's where CloudFront's control plane runs."*

#### 3. NLB (Network Load Balancer)

```
Internet → NLB (TLS:443) → EC2 (TCP:80)
            └── ACM cert terminates TLS
            └── OR pass-through (no cert needed on NLB)
```

*"NLB supports two TLS modes:"*

| Mode | How It Works | When to Use |
|------|-------------|-------------|
| **TLS Termination** | NLB decrypts, sends plain TCP to targets | Same as ALB, but for TCP apps |
| **TCP Pass-through** | NLB forwards encrypted traffic to targets | Targets handle their own TLS (compliance) |

#### 4. API Gateway

```
Custom Domain:  api.sskdevops.in
                  └── ACM cert for api.sskdevops.in
                  └── Route 53 ALIAS → API Gateway domain

Default Domain: https://abc123.execute-api.us-east-1.amazonaws.com
                  └── AWS-managed cert (automatic, no ACM needed)
```

*"API Gateway comes with a free AWS-managed certificate on its default domain. You only need ACM when you want a CUSTOM domain like `api.sskdevops.in`."*

### 🗣️ Services That DON'T Support ACM

| Service | Alternative |
|---------|------------|
| **EC2 instances** | Install cert manually (Let's Encrypt, certbot) |
| **ECS on EC2** | Use ALB in front with ACM |
| **On-premises servers** | ACM Private CA (exportable), or traditional CA |
| **RDS** | Uses AWS-managed internal certs (not ACM) |
| **Non-AWS services** | Traditional CA, Let's Encrypt |

---

## Part 10: TLS Security Policies (10 minutes)

### 🗣️ What is a Security Policy?

*"When you attach an ACM certificate to an ALB, you also choose a SECURITY POLICY. This controls which TLS versions and cipher suites your load balancer supports."*

*"Think of it this way: the certificate is your ID badge. The security policy is the door lock. Even if you have a perfect badge, a weak lock lets anyone in."*

### 🗣️ Key Security Policies

| Policy | TLS Versions | When to Use |
|--------|-------------|-------------|
| `ELBSecurityPolicy-TLS13-1-2-2021-06` | TLS 1.3 + 1.2 | ✅ **Recommended.** Best security + compatibility |
| `ELBSecurityPolicy-TLS13-1-3-2021-06` | TLS 1.3 ONLY | Maximum security. May break old clients. |
| `ELBSecurityPolicy-TLS-1-2-2017-01` | TLS 1.2 ONLY | Legacy. Still secure but missing TLS 1.3 benefits. |
| `ELBSecurityPolicy-2016-08` | TLS 1.0, 1.1, 1.2 | ❌ **AVOID.** TLS 1.0/1.1 are deprecated and insecure. |

### 🗣️ TLS 1.2 vs TLS 1.3

| Feature | TLS 1.2 | TLS 1.3 |
|---------|---------|---------|
| **Handshake round trips** | 2 RTT | 1 RTT (50% faster!) |
| **0-RTT resumption** | ❌ | ✅ (returning visitors = instant) |
| **Cipher suites** | 37 options (some weak) | 5 options (all strong) |
| **Forward secrecy** | Optional | Mandatory |
| **Deprecated algorithms** | RSA key exchange still allowed | RSA key exchange removed |

*"TLS 1.3 is faster AND more secure. There's no reason not to use it. The only reason to keep TLS 1.2 is backward compatibility with old clients (ancient Android phones, old Java apps)."*

### ❓ Ask Students:

*"My company's security team says we must disable TLS 1.0 and 1.1. Which ALB security policy should I use?"*

*"Answer: `ELBSecurityPolicy-TLS13-1-2-2021-06`. This supports TLS 1.3 and 1.2 only. TLS 1.0 and 1.1 are completely disabled."*

---

# ☕ BREAK (10 minutes)

---

# SECTION C: ACM WITH STREAMFLIX — PRACTICAL PATTERNS

## Part 11: Architecture Patterns (15 minutes)

### 🗣️ Pattern 1: Simple HTTPS Website

```
Users ──HTTPS──► CloudFront ──HTTP──► S3 (static files)
                    │
                    └── ACM cert: streamflix.sskdevops.in (us-east-1)
                    └── Route 53 ALIAS → CloudFront
```

*"This is our StreamFlix setup. The cert is attached to CloudFront. S3 doesn't need a cert — it's private, accessed only by CloudFront via OAC."*

### 🗣️ Pattern 2: HTTPS API Backend

```
Users ──HTTPS──► ALB ──HTTP──► EC2 instances (Auto Scaling)
                  │               Target Group: streamflix-tg
                  ├── Listener: HTTPS:443 → Forward to TG
                  ├── Listener: HTTP:80 → Redirect to HTTPS:443
                  └── ACM cert: api.sskdevops.in (same region as ALB)
                  
Route 53: api.sskdevops.in → ALIAS → ALB
```

### 🗣️ Pattern 3: Full Stack — CloudFront + ALB (StreamFlix Production)

```
                    ┌──────────────────────────────────┐
                    │   ACM Cert #1 (us-east-1)         │
                    │   *.sskdevops.in                  │
                    │   For: CloudFront                 │
                    └──────────┬───────────────────────┘
                               │
Users ──HTTPS──► CloudFront ──►├──► S3 (static: /, *.html, *.css, *.js)
                               │
                               └──► ALB (dynamic: /api/*)
                                     │
                    ┌─────────────────┴─────────────────┐
                    │   ACM Cert #2 (ap-south-1)         │
                    │   api.sskdevops.in                 │
                    │   For: ALB HTTPS listener          │
                    └──────────────────────────────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   EC2 / ECS  │
                              │   (HTTP:80)  │
                              └─────────────┘
```

*"Two certificates, two regions, two purposes. CloudFront handles the frontend with a cert in us-east-1. The ALB handles the API with a cert in the app's region. This is how production architectures work."*

### 🗣️ Pattern 4: Multi-Domain with SNI

```
One ALB, Three Apps, Three Certs:

ALB HTTPS:443 Listener
  │
  ├── SNI: streamflix.sskdevops.in   → Cert 1 → TG: streamflix-web
  ├── SNI: api.sskdevops.in          → Cert 2 → TG: api-backend  
  └── SNI: admin.sskdevops.in        → Cert 3 → TG: admin-panel

Cost: ONE ALB ($16/month) instead of THREE ALBs ($48/month!)
```

*"SNI (Server Name Indication) is the magic that makes this possible. The browser includes the hostname in the TLS handshake. The ALB sees the hostname and presents the correct certificate. One ALB, many domains, many certs."*

---

## Part 12: Certificate Transparency & Security (5 minutes)

### 🗣️ Certificate Transparency Logs

*"Every public certificate issued by any CA is logged in a public, append-only database called Certificate Transparency (CT) logs."*

*"Why does this matter? Because you can MONITOR these logs. If someone (or some CA) issues a certificate for YOUR domain without your knowledge, you'll see it."*

```
Tools to monitor CT logs:
  • https://crt.sh         ← Search any domain's certificates
  • https://transparencyreport.google.com/https/certificates
  • AWS Config rule: acm-certificate-expiration-check
```

### 🗣️ CAA Records for Extra Security

*"Remember CAA records from the Route 53 session? This is where they matter:"*

```
sskdevops.in  CAA  0 issue "amazon.com"
sskdevops.in  CAA  0 issue "letsencrypt.org"
sskdevops.in  CAA  0 iodef "mailto:security@sskdevops.in"
```

*"This tells all CAs: only Amazon and Let's Encrypt can issue certs for my domain. If DigiCert gets a request for my domain, they MUST refuse. And if anything suspicious happens, email my security team."*

---

## Part 13: ACM Pricing (5 minutes)

### 🗣️ What's Free, What's Not

| Item | Cost |
|------|------|
| **Public certificates** | 🆓 FREE |
| **Certificate renewal** | 🆓 FREE |
| **Attaching to ALB/CloudFront/API GW** | 🆓 FREE (no ACM charge, but ALB/CF has its own cost) |
| **Private CA** | 💰 $400/month per CA |
| **Private certificates** | 💰 $0.75 per certificate/month |
| **ACM API calls** | 🆓 FREE |

*"For public-facing websites and APIs, ACM is completely free. You only pay for the resources you attach the cert to (ALB, CloudFront, etc.), but the certificate itself costs nothing."*

*"Compare this to buying certs from DigiCert ($200/year each) and manually renewing them. For a company with 50 domains, that's $10,000/year plus the operational overhead of managing renewals. With ACM: $0."*

---

## Part 14: ACM Limits & Quotas (5 minutes)

### 🗣️ Default Limits

| Limit | Default | Can Increase? |
|-------|---------|---------------|
| Certificates per account per region | 2,500 | Yes (service quota) |
| Domain names per certificate (SANs) | 10 | Yes, up to 100 |
| Certificates per ALB listener | 25 (1 default + 24 SNI) | No |
| Private CAs per account | 200 | Yes |
| ACM certificate validity | 13 months | No |
| Renewal window | Starts 60 days before expiry | No |

*"The most common limit you'll hit is the 10 SANs per certificate. If you have more than 10 subdomains, either request a quota increase or use wildcard certs."*

---

## Part 15: Troubleshooting ACM (10 minutes)

### 🗣️ Top 10 Issues & Fixes

**1. Certificate stuck in PENDING_VALIDATION**

```
Cause: DNS validation record not found
Fix: 
  - Check the CNAME was added to the CORRECT hosted zone (public, not private)
  - Verify with: dig _abc123.streamflix.sskdevops.in CNAME +short
  - Check for typos in the record name or value
  - Wait up to 30 minutes (DNS propagation)
```

**2. "Certificate not found" when attaching to CloudFront**

```
Cause: Certificate is NOT in us-east-1
Fix: Request a new certificate in us-east-1 with the same domain names
```

**3. "Certificate not found" when attaching to ALB**

```
Cause: Certificate is in a different region than the ALB
Fix: Request a certificate in the SAME region as the ALB
```

**4. Certificate issued but HTTPS shows "Not Secure"**

```
Cause: Mixed content — page loads over HTTPS but includes HTTP resources
Fix: 
  - Change all http:// links to https:// (or use //)
  - Check browser console for "Mixed Content" warnings
  - Add Content-Security-Policy header: upgrade-insecure-requests
```

**5. Certificate renewal failed**

```
Cause: DNS validation CNAME was deleted
Fix: 
  - Go to ACM console → Certificate → check "Renewal status"
  - Re-add the validation CNAME record
  - ACM will retry in 15 minutes
```

**6. ERR_CERT_COMMON_NAME_INVALID**

```
Cause: Domain you're visiting doesn't match any name on the certificate
Fix:
  - Certificate for *.sskdevops.in, but visiting deep.sub.sskdevops.in
  - Certificate for app.sskdevops.in, but visiting api.sskdevops.in
  - Add the missing domain as a SAN, or request a new cert
```

**7. Can't delete a certificate**

```
Cause: Certificate is still attached to a resource (ALB, CloudFront, etc.)
Fix: Disassociate the cert from ALL resources first, then delete
```

**8. ACM certificate not auto-renewing**

```
Cause: Certificate is not ASSOCIATED with any AWS resource
Fix: ACM only auto-renews certs that are actively in use.
     Attach it to an ALB, CloudFront, or API Gateway.
```

**9. Too many certificates for one domain**

```
Cause: Hitting the 2,500 cert per region limit
Fix: Delete unused/expired certificates. Request quota increase.
```

**10. TLS handshake failure**

```
Cause: Client doesn't support the TLS version required by ALB security policy
Fix: Lower the security policy (not recommended) or update the client
     Check: openssl s_client -connect streamflix.sskdevops.in:443
```

---

## Part 16: Interview Questions (10 minutes)

### 🗣️ Top 20 ACM Interview Questions

1. **What is ACM?**
   → AWS Certificate Manager. A service that provisions, manages, and deploys public and private SSL/TLS certificates for use with AWS services.

2. **How much does an ACM public certificate cost?**
   → Free. $0. You only pay for the AWS resources (ALB, CloudFront) you attach it to.

3. **Can you export an ACM public certificate's private key?**
   → No. The private key is managed by AWS in HSMs and is never accessible to you. You cannot install ACM public certs on non-AWS servers.

4. **What validation methods does ACM support?**
   → DNS validation (add a CNAME record, recommended) and Email validation (click a link sent to domain admin contacts).

5. **Why is DNS validation preferred over email?**
   → DNS validation enables automatic certificate renewal. Email validation requires manual approval every 13 months.

6. **What is the validity period of an ACM certificate?**
   → 13 months. Auto-renewal starts 60 days before expiry.

7. **Why must CloudFront certificates be in us-east-1?**
   → CloudFront is a global service whose control plane runs in us-east-1. All certificate configurations for CloudFront are stored there.

8. **Can I use the same ACM certificate on an ALB and CloudFront?**
   → Only if both are in us-east-1. If your ALB is in a different region, you need a separate certificate in that region.

9. **What is a wildcard certificate?**
   → A cert for `*.domain.com` that covers all single-level subdomains (app.domain.com, api.domain.com) but NOT the root domain (domain.com) or multi-level subdomains (a.b.domain.com).

10. **What is SNI?**
    → Server Name Indication. Allows one ALB listener to serve multiple SSL certificates based on the hostname in the TLS ClientHello. ALB supports up to 25 certs per listener using SNI.

11. **What is the difference between ACM public and private certificates?**
    → Public certs are free, trusted by all browsers, but can't be exported. Private certs (via ACM Private CA) cost $400/month per CA + $0.75/cert, are only trusted by your systems, but CAN be exported.

12. **What is Certificate Transparency?**
    → A public log system where all issued certificates are recorded. Allows domain owners to monitor for unauthorized certificate issuance.

13. **What is a CAA record?**
    → Certificate Authority Authorization. A DNS record that specifies which CAs are allowed to issue certificates for your domain.

14. **How does ACM auto-renewal work?**
    → For DNS-validated certs, ACM checks the validation CNAME still exists and automatically issues a new cert. For email-validated, it sends a renewal email requiring manual approval.

15. **What happens if auto-renewal fails?**
    → ACM sends notification emails and creates CloudWatch events. If not resolved, the certificate expires and HTTPS stops working.

16. **What is a TLS security policy on ALB?**
    → Defines which TLS versions and cipher suites the ALB supports. Use `ELBSecurityPolicy-TLS13-1-2-2021-06` for TLS 1.3 + 1.2 (recommended).

17. **What is SSL/TLS termination?**
    → The load balancer decrypts HTTPS traffic and forwards HTTP to backend targets. Offloads encryption CPU from application servers.

18. **What is the difference between SSL termination and TLS pass-through?**
    → Termination: LB decrypts, inspects, and re-routes. Pass-through: LB forwards encrypted traffic directly to the backend (NLB only). Pass-through is for compliance scenarios requiring end-to-end encryption.

19. **Can I use ACM with EC2 directly?**
    → No. ACM certificates cannot be installed on EC2 instances. Place an ALB in front of EC2 and attach the ACM cert to the ALB.

20. **How do I monitor certificate expiry?**
    → CloudWatch metric `DaysToExpiry` in the `AWS/CertificateManager` namespace. Set an alarm if it drops below 30 days.

---

# SECTION D: HANDS-ON LABS

## 🟢 Lab 1: BASIC — Request Certificate & Attach to ALB (20 minutes)

### Objective
Request an ACM certificate, validate it via DNS, and attach it to an ALB for HTTPS access to StreamFlix.

### Prerequisites
- ALB already created from the ELB/ASG lab (or create a quick one)
- Domain registered in Route 53 (e.g., `sskdevops.in`)
- Two EC2 instances running StreamFlix behind the ALB

### Step 1: Request ACM Certificate

1. Open **ACM** (Certificate Manager) console
2. ⚠️ **Verify your region** — must match your ALB's region!
3. Click **Request a certificate** → **Request a public certificate** → Next
4. **Domain names:**
   - Primary: `app.sskdevops.in`
   - Click **Add another name**: `*.sskdevops.in` (optional wildcard)
5. **Validation method:** DNS validation (recommended)
6. **Key algorithm:** RSA 2048 (default, fine for most cases)
7. Click **Request**

### Step 2: Validate the Certificate

1. Click into the new certificate (Status: **Pending validation**)
2. In the **Domains** section, click **Create records in Route 53**
3. Confirm by clicking **Create records**
4. Wait 2-5 minutes → Status changes to **Issued** ✅

```bash
# Verify the validation CNAME was created
dig _abc123.app.sskdevops.in CNAME +short
# → _def456.mhbtsbpdnt.acm-validations.aws.
```

> [!TIP]
> **Teaching moment:** "That one click automatically created a CNAME record in your Route 53 hosted zone. This CNAME proves to ACM that you own this domain. As long as it exists, ACM will auto-renew your certificate forever. NEVER delete it."

### Step 3: Add HTTPS Listener to ALB

1. Go to **EC2** → **Load Balancers** → Select `streamflix-alb`
2. **Listeners** tab → **Add listener**
3. Settings:
   - **Protocol:** HTTPS
   - **Port:** 443
   - **Default action:** Forward to `streamflix-tg`
   - **Security policy:** `ELBSecurityPolicy-TLS13-1-2-2021-06`
   - **Default SSL/TLS server certificate:** Select your ACM cert (`app.sskdevops.in`)
4. Click **Add**

### Step 4: Add HTTP → HTTPS Redirect

1. Select the **HTTP:80** listener → **Edit rules** → **Manage rules**
2. Delete the existing forward action
3. Add new action: **Redirect to** → HTTPS, 443, Status: 301
4. Save

### Step 5: Update Security Group

1. **EC2** → **Security Groups** → Select the ALB's security group
2. Ensure **HTTPS (443)** from `0.0.0.0/0` is allowed (it should be from the ELB lab)

### Step 6: Create Route 53 ALIAS Record

1. **Route 53** → **Hosted zones** → `sskdevops.in`
2. **Create record:**
   - Record name: `app`
   - Record type: `A`
   - Alias: **ON** ✅
   - Route traffic to: **Application Load Balancer** → your region → select `streamflix-alb`
3. Click **Create records**

### Step 7: Test Everything!

```bash
# Test HTTPS (should show StreamFlix page)
curl -sI https://app.sskdevops.in/ | head -5
# HTTP/2 200
# content-type: text/html

# Test HTTP redirect (should 301 to HTTPS)
curl -sI http://app.sskdevops.in/ | grep -i location
# location: https://app.sskdevops.in/

# Check SSL certificate details
echo | openssl s_client -connect app.sskdevops.in:443 -servername app.sskdevops.in 2>/dev/null | openssl x509 -noout -subject -dates -issuer
# subject=CN = app.sskdevops.in
# notBefore=Apr 15 00:00:00 2026 GMT
# notAfter=May 15 23:59:59 2027 GMT
# issuer=O = Amazon, CN = Amazon RSA 2048 M03

# Check certificate chain
echo | openssl s_client -connect app.sskdevops.in:443 2>/dev/null | grep -E "subject|issuer"
```

> [!IMPORTANT]
> **Key observation:** "Open `https://app.sskdevops.in` in your browser. Click the padlock. Click 'Certificate.' You can see: who issued it (Amazon), when it expires, and all the domain names it covers. This is your FREE ACM certificate in action!"

---

## 🟡 Lab 2: INTERMEDIATE — Multi-Domain ALB with SNI (25 minutes)

### Objective
Set up one ALB serving three different applications on three different subdomains, each with its own ACM certificate.

### Step 1: Request Three Certificates

Request certificates for:
1. `app.sskdevops.in` (may already have from Lab 1)
2. `api.sskdevops.in`
3. `admin.sskdevops.in`

For each: ACM → Request → DNS validation → Create records in Route 53

### Step 2: Create Three Target Groups

**Target Group 1: streamflix-web-tg** (existing from Lab 1)

**Target Group 2: streamflix-api-tg**
1. **EC2** → **Target Groups** → **Create**
   - Target type: Instances
   - Name: `streamflix-api-tg`
   - Protocol: HTTP, Port: 80
   - Health check: `/health`
2. Register an EC2 instance with API-like user data:

```bash
#!/bin/bash
yum install -y nginx
cat > /usr/share/nginx/html/index.html <<EOF
{"service":"StreamFlix API","version":"1.0","status":"running"}
EOF
echo '{"status":"healthy"}' > /usr/share/nginx/html/health
systemctl enable nginx && systemctl start nginx
```

**Target Group 3: streamflix-admin-tg**
1. Create with same settings, name: `streamflix-admin-tg`
2. Register an EC2 instance with admin-like user data:

```bash
#!/bin/bash
yum install -y nginx
cat > /usr/share/nginx/html/index.html <<EOF
<html><body style="background:#1a1a2e;color:#fff;text-align:center;padding:50px;">
<h1>🔒 StreamFlix Admin Panel</h1>
<p>Admin dashboard would go here</p>
</body></html>
EOF
echo '{"status":"healthy"}' > /usr/share/nginx/html/health
systemctl enable nginx && systemctl start nginx
```

### Step 3: Configure ALB with Multiple Certificates (SNI)

1. Go to **ALB** → `streamflix-alb` → **Listeners** → **HTTPS:443**
2. The **default certificate** should be `app.sskdevops.in`
3. Click **View/edit certificates** → **Add certificate**
   - Add `api.sskdevops.in`
   - Add `admin.sskdevops.in`

### Step 4: Add Host-Based Routing Rules

1. **HTTPS:443 Listener** → **View/edit rules**

2. **Add Rule 1 (Priority 1):**
   - IF: Host header is `api.sskdevops.in`
   - THEN: Forward to `streamflix-api-tg`

3. **Add Rule 2 (Priority 2):**
   - IF: Host header is `admin.sskdevops.in`
   - THEN: Forward to `streamflix-admin-tg`

4. **Default rule:** Forward to `streamflix-web-tg`

### Step 5: Create Route 53 Records

Create ALIAS records for each subdomain:
- `api.sskdevops.in` → ALIAS → ALB
- `admin.sskdevops.in` → ALIAS → ALB

### Step 6: Test SNI

```bash
# Each subdomain shows a different app, with a different certificate!
curl -s https://app.sskdevops.in/
# → StreamFlix web page

curl -s https://api.sskdevops.in/
# → {"service":"StreamFlix API","version":"1.0","status":"running"}

curl -s https://admin.sskdevops.in/
# → StreamFlix Admin Panel

# Verify each has its own certificate
echo | openssl s_client -connect app.sskdevops.in:443 -servername app.sskdevops.in 2>/dev/null | openssl x509 -noout -subject
# subject=CN = app.sskdevops.in

echo | openssl s_client -connect api.sskdevops.in:443 -servername api.sskdevops.in 2>/dev/null | openssl x509 -noout -subject
# subject=CN = api.sskdevops.in

echo | openssl s_client -connect admin.sskdevops.in:443 -servername admin.sskdevops.in 2>/dev/null | openssl x509 -noout -subject
# subject=CN = admin.sskdevops.in
```

> [!TIP]
> **Teaching moment:** "ONE ALB, THREE different domains, THREE different certificates, THREE different applications. The `-servername` flag in openssl is the SNI header. The ALB reads this and picks the right certificate. This saves you ~$32/month compared to running three separate ALBs."

---

## 🔴 Lab 3: ADVANCED — Full StreamFlix Production Stack with ACM (35 minutes)

### Objective
Deploy the complete StreamFlix production architecture: CloudFront (frontend) + ALB (API backend), each with its own ACM certificate in the correct region.

### Architecture

```
                         ┌─── ACM Cert #1 ────┐
                         │  *.sskdevops.in     │
                         │  Region: us-east-1  │
                         └────────┬────────────┘
                                  │
Users ──HTTPS──► CloudFront ──────┤──► S3 (static files)
                     │            │
                     │            └──► ALB /api/* (origin)
                     │                  │
                     │     ┌─── ACM Cert #2 ────────┐
                     │     │  api.sskdevops.in       │
                     │     │  Region: ap-south-1     │
                     │     └────────┬────────────────┘
                     │              │
                     └──────────────┤
                                    ▼
                              ┌──────────┐
                              │  EC2/ASG │
                              │ (HTTP:80)│
                              └──────────┘

Route 53:
  streamflix.sskdevops.in → ALIAS → CloudFront
  api.sskdevops.in        → ALIAS → ALB
```

### Step 1: Request Certificate for CloudFront (us-east-1)

1. ⚠️ **Switch region to us-east-1 (N. Virginia)**!
2. **ACM** → **Request certificate**
3. Domain names:
   - `streamflix.sskdevops.in`
   - `*.sskdevops.in` (as SAN)
4. DNS validation → Create records in Route 53
5. Wait for **Issued** ✅

### Step 2: Request Certificate for ALB (your app region)

1. **Switch to your app's region** (e.g., `ap-south-1` Mumbai)
2. **ACM** → **Request certificate**
3. Domain name: `api.sskdevops.in`
4. DNS validation → Create records in Route 53
5. Wait for **Issued** ✅

### Step 3: Deploy ALB Backend

*(If not already done from ELB/ASG lab)*

1. Create Launch Template with StreamFlix API user data
2. Create ASG (min: 2, max: 4, desired: 2)
3. Create ALB `streamflix-api-alb`:
   - HTTPS:443 listener → ACM cert `api.sskdevops.in`
   - HTTP:80 → Redirect to HTTPS
   - Security policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`

### Step 4: Upload StreamFlix Frontend to S3

```bash
# Create S3 bucket (if not already done)
aws s3 mb s3://streamflix-frontend-$(whoami)-$(date +%s) --region ap-south-1

# Upload files
aws s3 sync app/ s3://streamflix-frontend-xxx/ \
  --content-type "text/html" \
  --exclude "*" --include "*.html"

aws s3 sync app/ s3://streamflix-frontend-xxx/ \
  --content-type "text/css" \
  --exclude "*" --include "*.css"

aws s3 sync app/ s3://streamflix-frontend-xxx/ \
  --content-type "application/javascript" \
  --exclude "*" --include "*.js"
```

### Step 5: Create CloudFront Distribution

1. **CloudFront** → **Create distribution**
2. **Origin 1 (S3):**
   - Origin domain: S3 bucket
   - Origin access: OAC (create new)
3. **Origin 2 (ALB):**
   - Origin domain: ALB DNS name
   - Protocol: HTTPS only
   - Origin path: (blank)
4. **Default behavior:** S3 origin
5. **Additional behavior:**
   - Path pattern: `/api/*`
   - Origin: ALB
   - Viewer protocol: HTTPS only
   - Cache policy: CachingDisabled (API responses shouldn't cache)
6. **Settings:**
   - CNAME: `streamflix.sskdevops.in`
   - SSL certificate: Select ACM cert from **us-east-1**
   - Minimum TLS: TLSv1.2_2021
   - Default root object: `index.html`
7. **Create distribution**
8. Update S3 bucket policy (copy from CloudFront banner)

### Step 6: Create Route 53 Records

```
streamflix.sskdevops.in → A (ALIAS) → CloudFront distribution
api.sskdevops.in        → A (ALIAS) → ALB
```

### Step 7: Full Verification

```bash
# 1. Frontend loads over HTTPS
curl -sI https://streamflix.sskdevops.in/ | head -3
# HTTP/2 200
# server: CloudFront

# 2. HTTP redirects to HTTPS
curl -sI http://streamflix.sskdevops.in/ | grep -i location
# location: https://streamflix.sskdevops.in/

# 3. API works through CloudFront
curl -s https://streamflix.sskdevops.in/api/health
# {"status":"healthy"}

# 4. Direct ALB access also works
curl -s https://api.sskdevops.in/health
# {"status":"healthy"}

# 5. Check CloudFront certificate
echo | openssl s_client -connect streamflix.sskdevops.in:443 -servername streamflix.sskdevops.in 2>/dev/null | openssl x509 -noout -subject -issuer
# subject=CN = streamflix.sskdevops.in
# issuer=O = Amazon, CN = Amazon RSA 2048 M03

# 6. Check ALB certificate (different cert!)
echo | openssl s_client -connect api.sskdevops.in:443 -servername api.sskdevops.in 2>/dev/null | openssl x509 -noout -subject -issuer
# subject=CN = api.sskdevops.in
# issuer=O = Amazon, CN = Amazon RSA 2048 M03

# 7. Verify TLS version
echo | openssl s_client -connect streamflix.sskdevops.in:443 2>/dev/null | grep "Protocol"
# Protocol  : TLSv1.3
```

> [!IMPORTANT]
> **Key learning:** "You now have TWO ACM certificates — one in us-east-1 for CloudFront, one in your app region for the ALB. They're both free, both auto-renewing, and both managed entirely by AWS. You never touched a private key, never generated a CSR, never set a calendar reminder. This is the production pattern."

---

## Cleanup

> [!CAUTION]
> **Destroy after every lab session!** ALB costs ~$16/month, CloudFront costs by request volume.

```bash
# 1. Delete CloudFront distribution
#    First: Disable distribution → Wait → Delete

# 2. Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>

# 3. Delete Target Groups
aws elbv2 delete-target-group --target-group-arn <TG_ARN>

# 4. Terminate EC2 instances
aws ec2 terminate-instances --instance-ids i-xxx i-yyy

# 5. Delete ASG and Launch Template
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name streamflix-asg --force-delete
aws ec2 delete-launch-template --launch-template-name streamflix-lt

# 6. Empty and delete S3 bucket
aws s3 rm s3://streamflix-frontend-xxx --recursive
aws s3 rb s3://streamflix-frontend-xxx

# 7. Delete Route 53 records (A, ALIAS, CNAME)
#    ⚠️ Keep the ACM validation CNAMEs if you want certs to auto-renew

# 8. Delete ACM certificates (both regions!)
#    ACM → Select cert → Delete
#    ⚠️ Switch to us-east-1 to delete the CloudFront cert!

# 9. Delete Security Groups (non-default)
```

---

## Summary: What Each Lab Teaches

| Lab | Level | Duration | Concepts |
|-----|-------|----------|----------|
| 🟢 **Lab 1** | Basic | 20 min | Request cert, DNS validation, attach to ALB, HTTP→HTTPS redirect, verify with openssl |
| 🟡 **Lab 2** | Intermediate | 25 min | Multiple certs on one ALB, SNI, host-based routing, cert-per-domain architecture |
| 🔴 **Lab 3** | Advanced | 35 min | Multi-region certs (us-east-1 for CF, app region for ALB), full production architecture, CloudFront + ALB integration |

---

## Timing Summary

| Section | Duration |
|---------|----------|
| **Understanding SSL/TLS & Certificates** | |
| Part 1: Why Certificates? | 15 min |
| Part 2: Certificate Authorities & Trust Chain | 10 min |
| Part 3: What is ACM? | 10 min |
| Part 4: Public vs Private Certificates | 10 min |
| **ACM Deep Dive** | |
| Part 5: Requesting a Certificate | 15 min |
| Part 6: Domain Names & Wildcards | 10 min |
| Part 7: Auto-Renewal | 10 min |
| Part 8: Regional Requirements | 10 min |
| Part 9: Service Integration | 15 min |
| Part 10: TLS Security Policies | 10 min |
| **☕ BREAK** | **10 min** |
| **Practical Patterns & Security** | |
| Part 11: Architecture Patterns | 15 min |
| Part 12: Certificate Transparency | 5 min |
| Part 13: Pricing | 5 min |
| Part 14: Limits & Quotas | 5 min |
| Part 15: Troubleshooting | 10 min |
| Part 16: Interview Questions | 10 min |
| 🟢 Lab 1: Basic | 20 min |
| 🟡 Lab 2: Intermediate | 25 min |
| 🔴 Lab 3: Advanced | 35 min |
| **Total** | **~3.5 hours** |

> **Trainer tip:** Take the break after Part 10 (TLS Security Policies). First half = theory (what certificates are, how ACM works). Second half = practical patterns and labs. The "aha" moment is in Lab 3 when students see TWO certificates in TWO regions working together — that's when the regional requirement clicks.

> **Trainer tip:** The openssl commands in the labs are GOLD for interviews. Teach students to verify certificates from the command line — hiring managers love seeing this skill. Have students run `openssl s_client -connect` on popular sites (google.com, netflix.com) and examine the certificate chain.

> **Trainer tip:** The Equifax story in Part 3 is your emotional hook. A $700 million fine because of a forgotten certificate renewal. Use it. It makes students take certificate management seriously.
