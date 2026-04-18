# Amazon CloudFront & CDN — Complete Teaching Script

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~4 hour session with break.

---

# SECTION A: UNDERSTANDING CDNs

## Part 1: Why Do We Need a CDN? (15 minutes)

### 🗣️ Opening Hook

*"Let's do an experiment. I have the StreamFlix app hosted on a single EC2 instance in Mumbai. I want you to think about what happens when users from different locations access it."*

```
User in Mumbai      → Server in Mumbai  → 15ms   ✅ Fast!
User in New York    → Server in Mumbai  → 220ms  😐 Slow...
User in London      → Server in Mumbai  → 180ms  😐 Slow...
User in Sydney      → Server in Mumbai  → 260ms  😡 Painful
User in São Paulo   → Server in Mumbai  → 340ms  ☠️ Terrible
```

*"Why is it slow? Because data travels at the speed of light through fiber optic cables. Light is fast — but the Earth is BIG. Mumbai to New York is 13,000 km through undersea cables. Physics cannot be cheated."*

*"Each request has to cross oceans, pass through dozens of routers, hit your server, generate a response, and cross those same oceans back. That's a ROUND TRIP. For a web page with 50 assets (HTML, CSS, JS, images), that's 50 round trips."*

### 🗣️ The Pizza Analogy

*"Imagine a pizza company that makes the BEST pizza in the world. But their only kitchen is in Mumbai. If someone in New York orders, the pizza has to fly across the world. By the time it arrives — cold, stale, 4-hour delivery. Nobody orders."*

*"So what do they do? They open KITCHENS in every major city. Same recipe, same ingredients, same quality — but now the pizza is made 5 minutes away from you."*

*"A CDN does exactly this. Instead of serving every request from Mumbai, you place COPIES of your content in 400+ locations around the world. When a user in New York requests your site, they get it from a server in New York — 10ms, not 220ms."*

```
WITHOUT CDN:
  Every user → Mumbai server → variable latency

WITH CDN (CloudFront):
  Mumbai user  → Mumbai edge      → 5ms
  NYC user     → NYC edge         → 8ms
  London user  → London edge      → 6ms
  Sydney user  → Sydney edge      → 7ms
  São Paulo    → São Paulo edge   → 9ms
```

*"SAME content. SAME quality. But served from RIGHT NEXT to you."*

### 🗣️ What is a CDN?

*"CDN = Content Delivery Network. A globally distributed network of servers (called edge locations) that cache copies of your content close to users."*

| Without CDN | With CDN |
|-------------|----------|
| All traffic hits origin server | Traffic distributed across 400+ edge locations |
| High latency for distant users | Low latency for ALL users |
| Origin server handles all load | Edge servers absorb 90%+ of traffic |
| Single point of failure | Built-in redundancy |
| Higher bandwidth costs | Lower data transfer costs |
| DDoS hits your server directly | DDoS absorbed by CDN network |

### ❓ Ask Students:

*"Netflix has 200+ million users worldwide streaming 4K video simultaneously. Could they serve all that from a single data center?"*

*"Answer: Absolutely not. Netflix uses its own CDN called Open Connect with thousands of servers embedded inside ISP networks. When you watch Netflix, the video comes from a server INSIDE your ISP's building — sometimes literally in the same room as their routers."*

---

## Part 2: How CDNs Work — Behind the Scenes (15 minutes)

### 🗣️ The Request Flow

```
1. User types: https://streamflix.sskdevops.in
                    │
                    ▼
2. DNS Resolution (Route 53):
   streamflix.sskdevops.in → ALIAS → d3abc.cloudfront.net
   CloudFront uses ANYCAST → Routes to NEAREST edge
                    │
                    ▼
3. Edge Location (e.g., Mumbai PoP):
   ┌─────────────────────────────────────┐
   │  "Do I have this content cached?"    │
   │                                     │
   │  YES (Cache HIT) ────► Return       │
   │    immediately.       200 OK        │
   │    Origin never       Age: 3600     │
   │    touched.           X-Cache: Hit  │
   │                                     │
   │  NO (Cache MISS) ────► Fetch from   │
   │    origin (S3/ALB),   origin,       │
   │    cache it,          return to     │
   │    then return.       user, cache   │
   │                       for next req  │
   └─────────────────────────────────────┘
```

*"The FIRST user to request a page from a new edge location gets a cache MISS — CloudFront fetches it from your origin. But every subsequent user at that edge gets a cache HIT — instant response, no origin contact."*

### 🗣️ Cache HIT vs MISS

```bash
# First request from Mumbai edge (MISS — fetches from origin):
curl -sI https://streamflix.sskdevops.in/ | grep -i x-cache
X-Cache: Miss from cloudfront

# Second request (HIT — served from cache):
curl -sI https://streamflix.sskdevops.in/ | grep -i x-cache
X-Cache: Hit from cloudfront

# Response time comparison:
Miss: ~120ms (origin roundtrip)
Hit:  ~8ms   (local cache)
```

*"That's a 15x speed improvement. For FREE. Just by putting CloudFront in front of your content."*

### 🗣️ Edge Locations vs Regional Edge Caches

```
CloudFront's Two-Tier Cache:

Tier 1: Edge Locations (400+ worldwide)
  └── Small cache, closest to users
  └── First stop for ALL requests
  └── Cache expires faster

Tier 2: Regional Edge Caches (13 globally)
  └── MUCH larger cache
  └── Sits between edge locations and your origin
  └── If edge misses, checks regional cache FIRST
  └── Reduces origin load significantly

       User
        │
        ▼
  Edge Location (Mumbai)     ← HIT? Return immediately
        │ MISS
        ▼
  Regional Edge Cache (Asia) ← HIT? Return, also cache at edge
        │ MISS
        ▼
  Origin (S3 / ALB / EC2)   ← Fetch, cache at regional AND edge
```

*"This two-tier system means your origin server is RARELY hit. The regional edge caches catch what individual edge locations miss. Netflix reported that their CDN absorbs 95%+ of all requests — only 5% ever reach origin servers."*

### ❓ Ask Students:

*"If a user in Delhi and a user in Mumbai both request the same page, do they share the same edge cache?"*

*"Answer: It depends. If they're routed to the same edge location, yes. If they're at different edge locations (CloudFront has multiple PoPs in India), they might each experience their own cold cache. But they WILL share the regional edge cache."*

---

## Part 3: What is Amazon CloudFront? (10 minutes)

### 🗣️ CloudFront Overview

*"CloudFront is AWS's CDN service. It's the 4th most-used AWS service after EC2, S3, and RDS."*

| Feature | Detail |
|---------|--------|
| **Edge locations** | 400+ in 90+ cities across 47 countries |
| **Regional Edge Caches** | 13 globally |
| **Protocols** | HTTP/1.1, HTTP/2, HTTP/3 (QUIC), WebSocket |
| **TLS** | TLS 1.3, free SSL via ACM |
| **Performance** | Sub-10ms latency at edge, Brotli + Gzip compression |
| **Security** | Integrated with WAF, Shield, OAC, signed URLs, field-level encryption |
| **Origin types** | S3, ALB/NLB, EC2, API Gateway, MediaStore, ANY HTTP server |
| **Pricing** | Pay-per-use: data transfer out + requests. First 1TB/month free (free tier) |
| **SLA** | 99.9% availability |

### 🗣️ CloudFront vs Other CDNs

| Feature | CloudFront | Cloudflare | Akamai | Fastly |
|---------|-----------|------------|--------|--------|
| **Edge locations** | 400+ | 300+ | 4,100+ | 80+ |
| **Free tier** | 1TB/month | Unlimited (basic) | ❌ | ❌ |
| **AWS integration** | Native | Manual | Manual | Manual |
| **WAF** | AWS WAF | Built-in | Kona WAF | Signal Sciences |
| **Pricing model** | Pay-per-use | Plans | Enterprise contracts | Pay-per-use |
| **Dynamic content** | Good | Good | Excellent | Excellent |
| **Best for** | AWS-centric stacks | Everything, free | Enterprise | Developers |

*"If you're on AWS, CloudFront is the obvious choice — native integration with S3, ALB, ACM, WAF, Route 53, and Lambda@Edge. For non-AWS stacks, Cloudflare's free tier is hard to beat."*

---

## Part 4: CloudFront Core Concepts (20 minutes)

### 🗣️ Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                   CloudFront Distribution                 │
│                                                          │
│  Distribution ID: E1ABC2DEF3GHIJ                         │
│  Domain: d3abc123.cloudfront.net                         │
│  CNAME: streamflix.sskdevops.in                          │
│  SSL: ACM cert (us-east-1)                               │
│                                                          │
│  ┌────────────────────────────────────────────────┐      │
│  │  Origins (Where content COMES FROM)             │      │
│  │                                                │      │
│  │  Origin 1: S3 Bucket (static files)            │      │
│  │    └── OAC: streamflix-oac                     │      │
│  │                                                │      │
│  │  Origin 2: ALB (API backend)                   │      │
│  │    └── Custom origin, HTTPS only               │      │
│  │                                                │      │
│  │  Origin 3: Custom server (legacy)              │      │
│  │    └── on-prem.company.com:443                 │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  ┌────────────────────────────────────────────────┐      │
│  │  Cache Behaviors (HOW to handle requests)       │      │
│  │                                                │      │
│  │  Default (*):                                  │      │
│  │    → Origin 1 (S3), Cache 24h, HTTPS           │      │
│  │                                                │      │
│  │  /api/*:                                       │      │
│  │    → Origin 2 (ALB), No cache, HTTPS           │      │
│  │                                                │      │
│  │  /legacy/*:                                    │      │
│  │    → Origin 3 (custom), Cache 1h               │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  WAF Web ACL: streamflix-waf (attached)                   │
│  Price Class: All edge locations                         │
└──────────────────────────────────────────────────────────┘
```

### 🗣️ Key Concept 1: Distributions

*"A distribution is your CloudFront configuration — it defines WHERE content comes from, HOW it's cached, and WHO can access it."*

| Setting | What It Does |
|---------|-------------|
| **Domain name** | Auto-generated: `d3abc.cloudfront.net` |
| **Alternate domain (CNAME)** | Custom: `streamflix.sskdevops.in` |
| **SSL certificate** | ACM cert (must be in us-east-1) |
| **Price class** | Which edge locations to use (all, NA+EU only, cheapest) |
| **WAF** | Attach a Web ACL for security |
| **Default root object** | What to serve for `/` (usually `index.html`) |
| **HTTP versions** | HTTP/2 (default), HTTP/3 optional |
| **IPv6** | Enabled by default |

*"Each distribution gets a unique domain name. In production, you create a Route 53 ALIAS from your custom domain to this CloudFront domain."*

### 🗣️ Key Concept 2: Origins

*"Origins are the servers where your REAL content lives. CloudFront fetches from origins on cache misses."*

| Origin Type | Use Case | Example |
|------------|----------|---------|
| **S3 bucket** | Static websites, assets, media | `streamflix-frontend.s3.amazonaws.com` |
| **ALB/NLB** | Dynamic APIs, microservices | `streamflix-alb.us-east-1.elb.amazonaws.com` |
| **EC2 / Custom HTTP** | Legacy servers, non-AWS servers | `origin.company.com` |
| **API Gateway** | Serverless APIs | `abc123.execute-api.us-east-1.amazonaws.com` |
| **MediaStore** | Live/on-demand video streaming | `container.mediastore.us-east-1.amazonaws.com` |
| **Another CloudFront** | Multi-tier CDN (rare) | `d3other.cloudfront.net` |

*"You can have MULTIPLE origins per distribution. CloudFront routes to the right origin based on path patterns."*

#### S3 Origin Access Control (OAC)

*"When S3 is your origin, NEVER make the bucket public. Use Origin Access Control:"*

```
The Problem (WRONG):
  S3 bucket: Public access ON
  Anyone can access: s3://bucket/secrets.txt directly
  ❌ Security nightmare

The Solution (RIGHT — OAC):
  S3 bucket: Public access BLOCKED
  CloudFront: OAC configured
  Bucket policy: Only allows CloudFront service principal
  
  Users → CloudFront → OAC signs request → S3 validates → Returns content
  Users → S3 directly → 403 Forbidden ✅
```

```json
{
  "Statement": [{
    "Sid": "AllowCloudFrontServicePrincipal",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::streamflix-frontend/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::123456:distribution/EABC123"
      }
    }
  }]
}
```

*"OAC replaced the older OAI (Origin Access Identity) in 2022. OAC supports S3 SSE-KMS encryption, which OAI did not. Always use OAC for new distributions."*

### ❓ Ask Students:

*"I have a CloudFront distribution with an S3 origin using OAC. Users can access `https://streamflix.sskdevops.in/styles.css`. Can they also access `https://streamflix-frontend.s3.amazonaws.com/styles.css` directly?"*

*"Answer: No! The bucket policy only allows the CloudFront service principal. Direct S3 access returns 403 Forbidden. This is exactly what you want — all traffic goes through CloudFront where you have WAF, logging, and caching."*

### 🗣️ Key Concept 3: Cache Behaviors

*"Cache behaviors are RULES that define how CloudFront handles different types of requests."*

| Setting | What It Controls | Example |
|---------|-----------------|---------|
| **Path pattern** | Which URLs this behavior matches | `/api/*`, `/images/*`, `*.js` |
| **Origin** | Which origin to fetch from | S3, ALB, custom |
| **Viewer protocol** | HTTP, HTTPS, or redirect | Redirect HTTP → HTTPS |
| **Cache policy** | What to cache and for how long | 24h for static, 0 for API |
| **Allowed HTTP methods** | GET, POST, PUT, DELETE, etc. | GET+HEAD for static |
| **Compress** | Gzip/Brotli compression | ✅ Always enable |
| **Lambda@Edge** | Run code at the edge | Auth, redirects, A/B testing |

```
Cache Behavior Priority (top to bottom):

Path: /api/*         → ALB origin, no cache, all HTTP methods
Path: /images/*      → S3 origin, cache 7 days, GET+HEAD only
Path: /assets/*.js   → S3 origin, cache 1 year, immutable
Path: /assets/*.css  → S3 origin, cache 1 year, immutable
Default: *           → S3 origin, cache 24h, GET+HEAD
```

*"The most SPECIFIC path pattern wins. `/api/v2/users` matches `/api/*` (priority 1), not the default `*`."*

---

## Part 5: Cache Policies & TTL (15 minutes)

### 🗣️ How Caching Works

*"Caching is the CORE value of CloudFront. Understanding TTL (Time to Live) is critical."*

```
Request arrives at edge:
  │
  ├── Cache HIT (content exists + not expired)
  │     └── Return cached content immediately
  │         Headers: X-Cache: Hit from cloudfront
  │                  Age: 1234 (seconds since cached)
  │
  ├── Cache MISS (content not in cache)
  │     └── Fetch from origin → Cache → Return
  │         Headers: X-Cache: Miss from cloudfront
  │                  Age: 0
  │
  └── Cache EXPIRED (content exists but TTL exceeded)
        └── Conditional request to origin:
            If-Modified-Since: <last-modified-date>
            If-None-Match: <etag>
            │
            ├── Origin: 304 Not Modified → Use cached copy, reset TTL
            └── Origin: 200 OK → Replace with new content
```

### 🗣️ TTL Hierarchy

*"CloudFront determines cache duration using this priority order:"*

```
Priority 1: Cache-Control headers from origin
  Cache-Control: max-age=86400        → Cache 24 hours
  Cache-Control: no-cache             → Always revalidate
  Cache-Control: no-store             → Never cache
  Cache-Control: s-maxage=3600        → Shared cache (CDN) = 1h
  
Priority 2: CloudFront Cache Policy settings
  If origin sends NO cache headers, CloudFront uses:
    Default TTL: 86400 (24 hours)
    Minimum TTL: 0
    Maximum TTL: 31536000 (1 year)

Priority 3: Object-specific Expires header (legacy)
  Expires: Thu, 31 Dec 2026 23:59:59 GMT
```

### 🗣️ Cache Policy Best Practices

| Content Type | Cache-Control Header | CloudFront TTL | Why |
|-------------|---------------------|----------------|-----|
| **HTML pages** | `max-age=0, s-maxage=3600` | 1 hour | HTML changes frequently, but CDN can serve stale briefly |
| **CSS/JS (versioned)** | `max-age=31536000, immutable` | 1 year | `app.a1b2c3.js` — filename changes when content changes |
| **CSS/JS (unversioned)** | `max-age=86400` | 24 hours | `styles.css` — needs periodic refresh |
| **Images** | `max-age=2592000` | 30 days | Images rarely change |
| **API responses** | `no-store` or `max-age=0` | 0 (no cache) | Dynamic data, must be fresh |
| **Fonts** | `max-age=31536000` | 1 year | Fonts never change |

*"The golden rule: if the filename includes a hash (`app.a1b2c3.js`), cache forever. If it doesn't (`index.html`), cache cautiously."*

### 🗣️ Managed Cache Policies

*"AWS provides pre-built cache policies so you don't have to create your own:"*

| Managed Policy | What It Does | Use Case |
|---------------|-------------|----------|
| `CachingOptimized` | Default TTL: 86400, Gzip + Brotli | Static websites |
| `CachingDisabled` | TTL: 0, forwards all headers | APIs, dynamic content |
| `CachingOptimizedForUncompressedObjects` | Same as Optimized, no compression | Already compressed content |
| `Amplify` | Tuned for AWS Amplify apps | Amplify projects |
| `Elemental-MediaPackage` | Tuned for video streaming | Live/VOD video |

### 🗣️ Cache Key

*"The cache key determines WHAT makes a cached object unique. By default, it's just the URL path. But you can include:"*

| Component | Include in Cache Key? | When |
|-----------|----------------------|------|
| **URL path** | ✅ Always | Always unique per URL |
| **Query strings** | Optional | `?page=2` and `?page=3` are different content |
| **Headers** | Optional | `Accept-Language: en` vs `fr` = different content |
| **Cookies** | Optional | Session-specific content |

```
Cache key = URL + selected query strings + selected headers + selected cookies

Example with query string caching:
  /api/products?page=1   →  Cache key A  (different content)
  /api/products?page=2   →  Cache key B  (different content)
  /api/products?page=1   →  Cache key A  (HIT!)

Example WITHOUT query string caching:
  /api/products?page=1   →  Cache key X
  /api/products?page=2   →  Cache key X  (same! returns page 1 data ❌)
```

*"If your API uses query parameters, you MUST include them in the cache key. Otherwise CloudFront serves the wrong data."*

### ❓ Ask Students:

*"I deploy a CSS update to S3 but users still see the old styles. What happened?"*

*"Answer: CloudFront is serving the cached version. Three solutions: (1) Create a cache invalidation for `/styles.css`. (2) Use versioned filenames: `styles.v2.css` or `styles.a1b2c3.css`. (3) Set a shorter TTL for CSS files. Option 2 is the best practice — it's instant and doesn't cost money."*

---

# ☕ BREAK (10 minutes)

---

# SECTION B: CLOUDFRONT ADVANCED FEATURES

## Part 6: Cache Invalidation (10 minutes)

### 🗣️ What is Invalidation?

*"Invalidation tells CloudFront: 'This content has changed. Throw away your cached copy and fetch a fresh one from origin on the next request.'"*

```
You:        "Invalidate /index.html"
CloudFront: Sends invalidation to ALL 400+ edge locations
            Each edge marks /index.html as stale
            Next request → fetches fresh copy from origin
```

### 🗣️ Invalidation Paths

| Path | What It Invalidates |
|------|-------------------|
| `/index.html` | Just that one file |
| `/images/*` | Everything under /images/ |
| `/images/hero-*.jpg` | All hero images (wildcard) |
| `/*` | EVERYTHING (nuclear option) |

### 🗣️ Invalidation Costs & Limits

| Aspect | Detail |
|--------|--------|
| **First 1,000 paths/month** | 🆓 Free |
| **Additional** | $0.005 per path |
| **Wildcard paths** | `/*` counts as ONE path (use this!) |
| **Time to complete** | ~60-120 seconds for all edges |
| **Concurrent** | Up to 3,000 paths in progress |
| **Wildcard limit** | Up to 15 wildcard invalidations in progress |

*"Pro tip: `/*` (single wildcard) costs the same as `/index.html` (one path). So if you're invalidating more than a few files, just invalidate everything with `/*`. It's cheaper and easier."*

### 🗣️ Why Versioned Filenames Are Better

```
❌ Invalidation approach:
  1. Upload new styles.css to S3
  2. Create CloudFront invalidation: /styles.css
  3. Wait 60-120 seconds for propagation
  4. Pay if >1000 paths/month
  5. Browser might still use local cache!

✅ Versioned filename approach:
  1. Upload styles.a1b2c3.css to S3
  2. Update index.html to reference styles.a1b2c3.css
  3. Upload new index.html (short TTL or invalidate just this)
  4. Instant. Free. No stale content anywhere.
  
  Build tools (Vite, webpack) do this automatically!
```

*"Invalidation is for emergencies and for files that CAN'T be versioned (like `index.html`). For everything else — version your filenames."*

---

## Part 7: Origin Failover & Origin Groups (10 minutes)

### 🗣️ What if Your Origin Goes Down?

*"CloudFront supports origin failover. If the primary origin returns an error, CloudFront automatically tries a secondary origin."*

```
┌────────────────────────────┐
│       Origin Group          │
│                            │
│  Primary Origin: S3 bucket  │
│    (streamflix-frontend)    │
│         │                  │
│         │  5xx/4xx error   │
│         ▼                  │
│  Secondary Origin: S3 bucket│
│    (streamflix-backup)      │
│    (different region)       │
└────────────────────────────┘
```

### 🗣️ Failover Configuration

| Setting | What It Does |
|---------|-------------|
| **Origin Group** | A pair of origins (primary + secondary) |
| **Failover criteria** | Which HTTP status codes trigger failover |
| **Status codes** | 500, 502, 503, 504 (server errors), 403, 404 (optional) |
| **Connection timeout** | 10 seconds default (1-10 configurable) |
| **Connection attempts** | 3 default (1-3 configurable) |

```
Failover scenarios:
  Primary returns 503 → Immediately try secondary
  Primary times out   → After 10s × 3 attempts → Try secondary
  Primary returns 200 → Normal response (secondary never touched)
```

### 🗣️ Real-World Pattern: Multi-Region S3 Failover

```
Primary:   s3://streamflix-frontend-us-east-1  (Virginia)
Secondary: s3://streamflix-frontend-eu-west-1  (Ireland)

S3 Cross-Region Replication keeps them in sync.

If us-east-1 S3 goes down:
  CloudFront → tries primary → 503 → tries secondary → 200 ✅
  Users don't notice anything!
```

*"This is how you survive an entire AWS region failure for static content."*

---

## Part 8: CloudFront Functions & Lambda@Edge (15 minutes)

### 🗣️ Running Code at the Edge

*"CloudFront lets you run code at edge locations to transform requests and responses WITHOUT going to your origin server."*

```
Two Options:

CloudFront Functions:
  Lightweight, JavaScript-only
  Sub-millisecond execution
  Runs at EVERY edge location (400+)
  1/6th the cost of Lambda@Edge
  Max execution: 1ms
  Max memory: 2MB
  
Lambda@Edge:
  Full Lambda power (Node.js/Python)
  Up to 30 seconds execution (response events: 40KB)
  Runs at Regional Edge Caches (13)
  Can make network calls (API, database)
  Max memory: 128MB-10GB (depending on event type)
```

### 🗣️ When to Use Which

| Task | CloudFront Functions | Lambda@Edge |
|------|---------------------|-------------|
| URL rewrites/redirects | ✅ Perfect | Overkill |
| Add/modify headers | ✅ Perfect | Overkill |
| Cache key normalization | ✅ Perfect | Overkill |
| JWT validation (simple) | ✅ Simple checks | ✅ Complex checks |
| A/B testing | ✅ Cookie-based | ✅ With API calls |
| Geo-based redirects | ✅ Header-based | Overkill |
| Image transformation | ❌ Too slow | ✅ Perfect |
| Auth with external IdP | ❌ No network access | ✅ Can call APIs |
| Server-side rendering | ❌ Too limited | ✅ Full compute |
| Bot detection | ❌ Too simple | ✅ Complex logic |

### 🗣️ Event Triggers

```
Client                   CloudFront              Origin
  │                         │                       │
  │  ① Viewer Request       │                       │
  │  ──────────────────►    │                       │
  │  [CF Function or L@E]   │                       │
  │                         │  ② Origin Request     │
  │                         │  ──────────────────►  │
  │                         │  [Lambda@Edge only]   │
  │                         │                       │
  │                         │  ③ Origin Response    │
  │                         │  ◄──────────────────  │
  │                         │  [Lambda@Edge only]   │
  │                         │                       │
  │  ④ Viewer Response      │                       │
  │  ◄──────────────────    │                       │
  │  [CF Function or L@E]   │                       │
```

| Trigger | What It Does | CF Functions | Lambda@Edge |
|---------|-------------|-------------|-------------|
| **Viewer Request** | Before cache lookup | ✅ | ✅ |
| **Origin Request** | Before going to origin (cache miss) | ❌ | ✅ |
| **Origin Response** | After origin responds (before caching) | ❌ | ✅ |
| **Viewer Response** | Before sending to user | ✅ | ✅ |

### 🗣️ Example: Security Headers (CloudFront Function)

```javascript
// CloudFront Function: Add security headers to all responses
function handler(event) {
    var response = event.response;
    var headers = response.headers;
    
    // Prevent clickjacking
    headers['x-frame-options'] = { value: 'DENY' };
    
    // Prevent MIME type sniffing
    headers['x-content-type-options'] = { value: 'nosniff' };
    
    // Enable browser XSS protection
    headers['x-xss-protection'] = { value: '1; mode=block' };
    
    // HSTS — force HTTPS for 1 year
    headers['strict-transport-security'] = { 
        value: 'max-age=31536000; includeSubdomains; preload' 
    };
    
    // Content Security Policy
    headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' fonts.googleapis.com; font-src fonts.gstatic.com" 
    };
    
    return response;
}
```

*"This function runs on EVERY response, at EVERY edge location, in under 1ms. It adds critical security headers that protect against XSS, clickjacking, and protocol downgrade attacks."*

### 🗣️ Example: URL Rewrite (CloudFront Function)

```javascript
// Rewrite /about to /about/index.html (SPA support)
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // If URI doesn't have a file extension, serve index.html
    if (!uri.includes('.')) {
        request.uri = '/index.html';
    }
    
    return request;
}
```

*"This is essential for single-page apps (React, Vue, Angular). Without it, refreshing `/about` returns a 404 because S3 has no file called `/about` — only `/index.html` with client-side routing."*

---

## Part 9: Signed URLs & Signed Cookies (10 minutes)

### 🗣️ Restricting Content Access

*"What if you have PREMIUM content that only paying users should access?"*

```
StreamFlix Premium:
  Free users  → Can watch: /free/*
  Premium users → Can watch: /premium/*  ← Need to restrict this!
```

### 🗣️ Signed URLs

*"A signed URL contains an embedded authorization signature. Only users who receive the URL from your application can access the content."*

```
Normal URL (public):
  https://d3abc.cloudfront.net/premium/movie.mp4

Signed URL (restricted):
  https://d3abc.cloudfront.net/premium/movie.mp4
    ?Policy=eyJ...base64-encoded-policy...
    &Signature=abc123...signature...
    &Key-Pair-Id=K36X4OHG...

Contains:
  - Resource: Which file(s) can be accessed
  - Expiry: URL stops working after this time
  - IP restriction: Optional — only this IP can use it
  - Signature: Cryptographic proof from your private key
```

### 🗣️ Signed URLs vs Signed Cookies

| Feature | Signed URLs | Signed Cookies |
|---------|------------|----------------|
| **Scope** | ONE specific file | Multiple files / entire path |
| **Use case** | Download a single video/PDF | Access an entire premium section |
| **URL change** | Yes (URL is modified) | No (set cookie, use normal URLs) |
| **RTMP streaming** | ✅ Required for RTMP | ❌ Not supported |
| **Compatibility** | Works everywhere | Requires cookie support |

```
Signed URL flow (single file access):
  1. User clicks "Watch Movie"
  2. Your app server generates signed URL (expires in 2 hours)
  3. User's browser requests the signed URL
  4. CloudFront verifies signature → serves video
  5. After 2 hours → URL stops working

Signed Cookie flow (multi-file access):
  1. User logs in → your app verifies premium subscription
  2. App sets 3 cookies: CloudFront-Policy, CloudFront-Signature, CloudFront-Key-Pair-Id
  3. Browser includes cookies on ALL requests to CloudFront
  4. CloudFront verifies cookies → serves premium content
  5. Cookies expire → user must re-authenticate
```

*"Netflix uses a combination of both. Signed cookies for browsing the catalog. Signed URLs for the actual video streams (each stream segment has its own short-lived signed URL)."*

---

## Part 10: CloudFront + WAF Integration (10 minutes)

### 🗣️ CloudFront as a Security Shield

*"CloudFront isn't just a CDN — it's your first line of defense."*

```
Internet (attackers + legitimate users)
         │
         ▼
┌──────────────────────────────┐
│  CloudFront Edge Location     │
│                              │
│  Layer 1: AWS Shield Standard │ ← DDoS protection (FREE, always on)
│    └── Blocks volumetric      │
│       attacks (SYN flood,     │
│       UDP reflection)         │
│                              │
│  Layer 2: AWS WAF             │ ← Application firewall (attached)
│    └── Rate limiting          │
│    └── SQL injection block    │
│    └── XSS protection         │
│    └── Geo blocking           │
│    └── Bot control            │
│                              │
│  Layer 3: Signed URLs/Cookies │ ← Content access control
│                              │
│  Layer 4: OAC                 │ ← Origin access control
│                              │
└──────────┬───────────────────┘
           │ Only clean traffic reaches origin
           ▼
      Origin (S3 / ALB)
```

*"Notice: the origin NEVER sees attack traffic. CloudFront + WAF + Shield absorb it at the edge. Your origin servers can be tiny and cheap because they only handle legitimate requests."*

### 🗣️ WAF Attachment

```
WAF Web ACL (streamflix-waf):
  ✅ MUST be in CLOUDFRONT scope (not REGIONAL)
  ✅ Must be created in us-east-1
  
  Rule 1: Rate limit (100 req/5min per IP)
  Rule 2: AWS Managed Common Rule Set (OWASP Top 10)
  Rule 3: SQL Injection protection
  Rule 4: Known Bad Inputs (Log4j, etc.)
  Rule 5: Geo Block (block specific countries)
```

*"We covered WAF in detail in the WAF session. The key here is: WAF Web ACLs for CloudFront must be CLOUDFRONT scope (not REGIONAL). They must be created in us-east-1. This is separate from WAF rules for ALBs, which use REGIONAL scope."*

---

## Part 11: CloudFront with Different Origin Types (15 minutes)

### 🗣️ Pattern 1: S3 Static Website (StreamFlix Frontend)

```
Route 53 → CloudFront → OAC → S3 (private)

CloudFront Distribution:
  Origin: streamflix-frontend.s3.ap-south-1.amazonaws.com
  OAC: streamflix-oac
  Default root object: index.html
  Error pages: 403→index.html, 404→error.html (for SPA routing)
  Cache policy: CachingOptimized
  Viewer protocol: Redirect HTTP→HTTPS
```

*"This is the most common pattern. S3 stores files, CloudFront serves them globally. S3 is NOT a web server — it's a storage service. CloudFront is the web server."*

### 🗣️ Pattern 2: ALB Dynamic API

```
Route 53 → CloudFront → ALB → EC2/ECS

CloudFront Distribution:
  Origin: streamflix-alb.us-east-1.elb.amazonaws.com
  Protocol: HTTPS only (ALB must have ACM cert)
  Cache policy: CachingDisabled (APIs shouldn't be cached)
  Origin request policy: AllViewer (forward all headers)
  Allowed methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
```

*"Why put CloudFront in front of an ALB? Three reasons: (1) WAF protection at the edge, not at the ALB. (2) DDoS absorption before traffic reaches your VPC. (3) Static content caching if you serve mixed content."*

### 🗣️ Pattern 3: Mixed Origins (Production Architecture)

```
streamflix.sskdevops.in
  │
  ├── / (default)      → S3 (static HTML/CSS/JS)
  ├── /api/*            → ALB (dynamic API)
  ├── /images/*         → S3 (media bucket, long cache)
  └── /legacy/*         → Custom origin (on-prem server)
```

*"One CloudFront distribution, four different origins. Users see ONE domain name. This is the standard production pattern."*

### 🗣️ Pattern 4: Custom Domain on API Gateway

```
api.sskdevops.in → CloudFront → API Gateway → Lambda

Why CloudFront over direct API GW access?
  ✅ Custom domain (instead of xxx.execute-api.xxx.amazonaws.com)
  ✅ WAF protection
  ✅ Response caching for GET endpoints
  ✅ Global edge routing (API GW is regional)
```

---

## Part 12: CloudFront Pricing (10 minutes)

### 🗣️ Pricing Components

*"CloudFront pricing has three parts:"*

#### 1. Data Transfer Out (to Users)

| Region | First 10TB/month | Next 40TB | Next 100TB |
|--------|-----------------|-----------|------------|
| **North America, Europe** | $0.085/GB | $0.080/GB | $0.060/GB |
| **Asia Pacific** | $0.120/GB | $0.100/GB | $0.080/GB |
| **India** | $0.109/GB | $0.085/GB | $0.070/GB |
| **South America** | $0.110/GB | $0.100/GB | $0.080/GB |

#### 2. HTTP/HTTPS Requests

| Type | Price (N. America/Europe) |
|------|--------------------------|
| HTTP requests | $0.0075 per 10,000 |
| HTTPS requests | $0.0100 per 10,000 |

#### 3. Invalidation Requests

| Volume | Price |
|--------|-------|
| First 1,000 paths/month | Free |
| Additional paths | $0.005 each |

### 🗣️ Free Tier

*"CloudFront has a generous PERMANENT free tier (not just 12 months):"*

| Component | Free Allowance |
|-----------|---------------|
| Data transfer out | **1 TB/month** |
| HTTP/HTTPS requests | **10 million/month** |
| CloudFront Functions | **2 million invocations/month** |

*"For a typical startup doing 50,000 page views/month with 2 MB average page size — that's about 100 GB of transfer. Well within the free tier. CloudFront is essentially free until you get significant traffic."*

### 🗣️ Price Classes

*"You can reduce costs by limiting which edge locations CloudFront uses:"*

| Price Class | Edge Locations | Cost | Use Case |
|------------|---------------|------|----------|
| **PriceClass_All** | All 400+ locations | Highest | Global audience |
| **PriceClass_200** | N. America, Europe, Asia, Africa, Middle East | Medium | Most apps |
| **PriceClass_100** | N. America + Europe only | Lowest | US/EU audience |

*"If 95% of your users are in the US and Europe, PriceClass_100 saves money. Users in Asia will still work — they'll just hit a US/EU edge instead of a local one."*

### 🗣️ Cost Example: StreamFlix

```
Monthly traffic:
  100,000 page views
  Average page: 2 MB (HTML + CSS + JS + images)
  Total data: 200 GB
  Total requests: 500,000 HTTPS

Costs (US/Europe pricing):
  Data transfer: 200 GB × $0.085 = $17.00
  HTTPS requests: 500,000 × ($0.01/10,000) = $0.50
  Invalidations: 5 × $0 (free tier) = $0

  Total: ~$17.50/month

  Most of this is within free tier (1TB + 10M requests)!
  Actual cost with free tier: $0
```

---

# SECTION C: CLOUDFRONT OPERATIONS

## Part 13: Compression (5 minutes)

### 🗣️ Automatic Compression

*"CloudFront can compress content on the fly, reducing file sizes by 60-90%:"*

| Format | Compression Ratio | Support |
|--------|------------------|---------|
| **Gzip** | 60-80% reduction | All modern browsers |
| **Brotli** | 70-90% reduction | 95%+ of browsers |

```
CloudFront Cache Policy:
  EnableAcceptEncodingGzip: true
  EnableAcceptEncodingBrotli: true

Result:
  styles.css: 32 KB → 5 KB (Brotli) or 7 KB (Gzip)
  app.js: 27 KB → 4 KB (Brotli) or 6 KB (Gzip)
  
  Total savings: ~80% bandwidth reduction!
```

*"Always enable both Gzip and Brotli. CloudFront automatically serves Brotli to browsers that support it and falls back to Gzip for others."*

*"Important: CloudFront only compresses files between 1,000 bytes and 10 MB. Files smaller than 1KB aren't worth compressing. Files larger than 10MB should be pre-compressed at the origin."*

---

## Part 14: HTTP/2 and HTTP/3 (5 minutes)

### 🗣️ Protocol Improvements

| Feature | HTTP/1.1 | HTTP/2 | HTTP/3 (QUIC) |
|---------|----------|--------|----------------|
| **Multiplexing** | ❌ One request per connection | ✅ Multiple streams | ✅ Multiple streams |
| **Header compression** | ❌ None | ✅ HPACK | ✅ QPACK |
| **Server push** | ❌ No | ✅ Yes | ✅ Yes |
| **Transport** | TCP | TCP + TLS | UDP + QUIC |
| **Head-of-line blocking** | ✅ Full blocking | ✅ At TCP level | ❌ Eliminated |
| **0-RTT connection** | ❌ No | ❌ No | ✅ Yes (for returning visitors) |

```
CloudFront:
  HTTP/2: ✅ Always enabled (default since 2020)
  HTTP/3: ✅ Optional (recommended to enable)
```

*"HTTP/3 over QUIC is especially useful for mobile users on unreliable connections. If a packet is lost, only that stream is affected — other streams continue. With HTTP/2 over TCP, one lost packet blocks ALL streams."*

---

## Part 15: CloudFront Logging & Monitoring (10 minutes)

### 🗣️ Access Logs

*"CloudFront can log every request to an S3 bucket."*

```
Enable logging:
  Distribution → General → Edit
  Standard logging: ON
  S3 bucket: streamflix-cloudfront-logs
  Log prefix: cf-logs/
  Cookie logging: NO (unless needed)
```

*"Log format (tab-separated, one line per request):"*

```
2026-04-15 10:23:45 BOM62-P3 1234 103.21.xx.xx GET d3abc.cloudfront.net /styles.css 200 - Mozilla/5.0... - streamflix.sskdevops.in https 1432 0.003 Hit TLSv1.3 HTTP/2
```

| Field | Value | Meaning |
|-------|-------|---------|
| Date/Time | `2026-04-15 10:23:45` | When the request arrived |
| Edge location | `BOM62-P3` | Mumbai edge (BOM = airport code) |
| Bytes | `1234` | Response size |
| Client IP | `103.21.xx.xx` | User's IP |
| HTTP method | `GET` | Request method |
| Host | `d3abc.cloudfront.net` | CloudFront domain |
| URI | `/styles.css` | Requested path |
| Status | `200` | HTTP status code |
| Cache result | `Hit` | Cache HIT or MISS |
| Protocol | `HTTP/2` | Protocol used |

### 🗣️ Real-Time Monitoring

| Tool | What It Shows |
|------|-------------|
| **CloudFront Console → Monitoring** | Requests, bytes, errors, cache hit ratio |
| **CloudWatch Metrics** | `Requests`, `BytesDownloaded`, `4xxErrorRate`, `5xxErrorRate` |
| **CloudFront Metrics** | `CacheHitRate`, `OriginLatency` (enable additional metrics) |
| **Real-time logs** | Stream to Kinesis Data Firehose → S3/Elasticsearch |

### 🗣️ Key Metric: Cache Hit Ratio

*"This is the MOST important CloudFront metric. It tells you what percentage of requests are served from cache:"*

```
Cache Hit Ratio = Cache Hits / Total Requests × 100

Good:   >90% for static sites
OK:     70-90% for mixed content
Bad:    <70% (investigate cache policy, TTL, cache key)

If hit ratio is low:
  ❓ Are you caching API responses that shouldn't be cached?
  ❓ Is your cache key too specific (including unnecessary headers)?
  ❓ Are TTLs too short?
  ❓ Are you invalidating too frequently?
```

---

## Part 16: Custom Error Pages (5 minutes)

### 🗣️ Customizing Error Responses

*"By default, CloudFront returns ugly XML error pages. You can customize them:"*

```
CloudFront → Distribution → Error pages → Create custom error response

Error code: 403 (Forbidden)
  Response page path: /error.html
  Response code: 404
  Error caching TTL: 10 seconds

Error code: 404 (Not Found)
  Response page path: /error.html
  Response code: 404
  Error caching TTL: 10 seconds

Error code: 503 (Service Unavailable)
  Response page path: /maintenance.html
  Response code: 503
  Error caching TTL: 5 seconds
```

*"Why does our StreamFlix config map 403 to 404? Because S3 returns 403 for files that don't exist (it doesn't distinguish between 'file not found' and 'access denied' for non-existent objects). We map both to our custom 404 page."*

*"For SPAs (React, Vue): Map 403 AND 404 to `/index.html` with response code 200. This lets client-side routing handle all paths."*

---

## Part 17: Geo Restriction (5 minutes)

### 🗣️ Country-Level Blocking

*"CloudFront can block or allow access by country:"*

```
Whitelist mode:
  Allow ONLY: US, UK, IN, AU
  Everyone else: 403 Forbidden

Blacklist mode:
  Block: CN, RU, KP
  Everyone else: Allowed
```

| Setting | What It Does |
|---------|-------------|
| **Restriction type** | Whitelist (allow listed) or Blacklist (block listed) |
| **Country codes** | ISO 3166-1 alpha-2 codes (US, GB, IN, etc.) |
| **Determination** | CloudFront uses MaxMind GeoIP database |
| **Override** | Users with VPN may bypass (use WAF for stricter control) |

*"For content licensing (like Netflix), you'd combine geo restriction with signed URLs — CloudFront blocks the country, AND your signed URL limits the content to specific users."*

---

## Part 18: Interview Questions (10 minutes)

### 🗣️ Top 20 CloudFront Interview Questions

1. **What is CloudFront?**
   → AWS's CDN (Content Delivery Network). A globally distributed network of edge locations that cache content close to users for faster delivery.

2. **How many edge locations does CloudFront have?**
   → 400+ edge locations in 90+ cities across 47 countries, plus 13 regional edge caches.

3. **What is the difference between an edge location and a regional edge cache?**
   → Edge locations are closest to users (400+, smaller cache). Regional edge caches sit between edge locations and the origin (13 globally, much larger cache). If edge misses, it checks regional cache before going to the origin.

4. **What origin types does CloudFront support?**
   → S3, ALB/NLB, EC2, API Gateway, MediaStore, and any custom HTTP/HTTPS server (including non-AWS servers).

5. **What is OAC and why should you use it?**
   → Origin Access Control. It restricts S3 bucket access so only CloudFront can read files. The bucket stays private — no public access. OAC replaced the older OAI and supports SSE-KMS encryption.

6. **What is a cache behavior?**
   → A rule that defines how CloudFront handles requests matching a URL path pattern. It specifies which origin to use, cache TTL, allowed HTTP methods, compression, and Lambda@Edge associations.

7. **What is cache invalidation?**
   → Forcibly removing cached content from all edge locations so the next request fetches a fresh copy from the origin. First 1,000 paths/month are free.

8. **Why are versioned filenames better than invalidation?**
   → Versioned files (app.a1b2c3.js) are instant, free, and avoid stale content. Invalidation takes 60-120 seconds to propagate, costs money at scale, and doesn't clear browser caches.

9. **What is the difference between CloudFront Functions and Lambda@Edge?**
   → CloudFront Functions: lightweight JS only, sub-ms execution, runs at all 400+ edge locations, no network access, cheap. Lambda@Edge: full Lambda (Node.js/Python), up to 30s execution, runs at 13 regional edge caches, can make network calls, more expensive.

10. **What are signed URLs vs signed cookies?**
    → Signed URLs restrict access to a single file with an embedded crypto signature. Signed cookies restrict access to multiple files/paths by setting cookie headers. Use signed URLs for individual downloads, signed cookies for multi-page premium sections.

11. **What is an Origin Group?**
    → A pair of origins (primary + secondary) for automatic failover. If the primary returns 5xx errors, CloudFront automatically tries the secondary.

12. **Why must CloudFront ACM certificates be in us-east-1?**
    → CloudFront is a global service whose control plane operates in us-east-1. All configuration, including SSL certificates, must be stored there.

13. **What HTTP versions does CloudFront support?**
    → HTTP/1.1, HTTP/2 (default), and HTTP/3 (QUIC, optional). HTTP/2 is always enabled. HTTP/3 provides additional benefits on unreliable networks.

14. **How does CloudFront determine which edge location to route to?**
    → Anycast routing. CloudFront's IP addresses are announced from all edge locations. Internet routing protocols (BGP) automatically direct users to the nearest edge.

15. **What is a cache hit ratio and what is a good value?**
    → Percentage of requests served from cache (not from origin). >90% is good for static sites. <70% needs investigation — check TTLs, cache keys, and invalidation frequency.

16. **How does CloudFront handle compression?**
    → Supports automatic Gzip and Brotli compression. Must be enabled in the cache policy. Compresses files between 1KB-10MB. Can reduce transfer by 60-90%.

17. **What is the CloudFront free tier?**
    → 1 TB data transfer out + 10 million HTTP/S requests + 2 million CloudFront Functions invocations per month. Permanent, not limited to 12 months.

18. **How do you restrict content by country?**
    → Geo restriction (whitelist or blacklist countries). Uses MaxMind GeoIP database. For stricter enforcement, combine with WAF geo-match rules.

19. **What is field-level encryption?**
    → Encrypts specific form fields (credit card, SSN) at the edge using a public key you provide. Only your application server with the private key can decrypt. The ALB and other intermediaries never see the plaintext.

20. **How would you set up CloudFront for a React SPA?**
    → S3 origin with OAC, default root object `index.html`, custom error responses mapping 403/404 to `/index.html` with status 200, plus a CloudFront Function for URL rewriting. This lets client-side routing handle all paths.

---

# SECTION D: HANDS-ON LABS

## 🟢 Lab 1: BASIC — Deploy StreamFlix to CloudFront + S3 (25 minutes)

### Objective
Host the StreamFlix static site on S3, distribute it globally via CloudFront, and verify caching behavior.

### Prerequisites
- StreamFlix app files (`index.html`, `styles.css`, `app.js`, `error.html`)
- ACM certificate for your domain in **us-east-1** (from ACM lab)
- Route 53 hosted zone configured

### Step 1: Create S3 Bucket

1. Open **S3** → **Create bucket**
2. **Bucket name:** `streamflix-frontend-[YOUR-NAME]-[RANDOM]`
3. **Region:** Your preferred region (e.g., `ap-south-1`)
4. **Block Public Access:** ✅ Leave ALL blocks ON (critical!)
5. Click **Create bucket**

> [!IMPORTANT]
> **Teaching moment:** "We are NOT enabling Static Website Hosting on S3. That's the old way and requires public access. The modern pattern is: S3 stores files (private), CloudFront serves them (public). Much more secure."

### Step 2: Upload StreamFlix Files

1. Open your bucket → **Upload**
2. Add all four files: `index.html`, `styles.css`, `app.js`, `error.html`
3. Click **Upload**

### Step 3: Create CloudFront Distribution

1. Open **CloudFront** → **Create distribution**

2. **Origin:**
   - Origin domain: Select your S3 bucket from dropdown
   - Origin path: (leave blank)
   - Origin access: **Origin Access Control settings (recommended)**
   - Click **Create new OAC** → Use defaults → **Create**
   - *(Don't worry about the bucket policy warning yet)*

3. **Default cache behavior:**
   - Viewer protocol policy: **Redirect HTTP to HTTPS**
   - Allowed HTTP methods: **GET, HEAD**
   - Cache policy: **CachingOptimized** (managed policy)
   - Compress objects: **Yes** ✅

4. **WAF:**
   - Select **Enable security protections** (creates basic WAF rules automatically)

5. **Settings:**
   - Price class: **Use all edge locations** (or PriceClass_200 to save cost)
   - Alternate domain name (CNAME): `streamflix.sskdevops.in`
   - Custom SSL certificate: Select your ACM cert from us-east-1
   - Supported HTTP versions: **HTTP/2** ✅, **HTTP/3** ✅
   - Default root object: `index.html`

6. Click **Create distribution**

### Step 4: Update S3 Bucket Policy

1. CloudFront shows a yellow banner: **"S3 bucket policy needs to be updated"**
2. Click **Copy policy**
3. Go to **S3** → Your bucket → **Permissions** → **Bucket Policy** → **Edit**
4. Paste the policy → **Save changes**

### Step 5: Add Custom Error Responses

1. Back in CloudFront → Your distribution → **Error pages** tab
2. **Create custom error response:**
   - HTTP error code: `403`
   - Customize error response: Yes
   - Response page path: `/error.html`
   - HTTP response code: `404`
   - Error caching TTL: `10`
3. Create another for error code `404` with same settings

### Step 6: Create Route 53 Record

1. **Route 53** → **Hosted zones** → `sskdevops.in`
2. **Create record:**
   - Record name: `streamflix`
   - Type: A
   - Alias: **ON**
   - Route traffic to: **Alias to CloudFront distribution**
   - Select your distribution
3. **Create records**

### Step 7: Verify Everything!

```bash
# Wait for distribution to deploy (Status: Enabled)
# This takes 5-10 minutes on first creation

# Test HTTPS access
curl -sI https://streamflix.sskdevops.in/ | head -10
# HTTP/2 200
# content-type: text/html
# server: AmazonS3
# x-cache: Miss from cloudfront (first request)
# via: 1.1 abc123.cloudfront.net (CloudFront)

# Second request — should be a HIT!
curl -sI https://streamflix.sskdevops.in/ | grep x-cache
# x-cache: Hit from cloudfront  ✅

# Test HTTP → HTTPS redirect
curl -sI http://streamflix.sskdevops.in/ | head -3
# HTTP/1.1 301 Moved Permanently
# location: https://streamflix.sskdevops.in/

# Check which edge location served you
curl -sI https://streamflix.sskdevops.in/ | grep x-amz-cf-pop
# x-amz-cf-pop: BOM62-P3  (Mumbai edge location)

# Test compression
curl -sI -H "Accept-Encoding: br" https://streamflix.sskdevops.in/styles.css | grep content-encoding
# content-encoding: br  (Brotli!)

# Test direct S3 access (should FAIL)
curl -sI https://streamflix-frontend-xxx.s3.ap-south-1.amazonaws.com/index.html
# 403 Forbidden ✅ (OAC is working!)
```

> [!TIP]
> **Teaching moment:** "Look at the `x-cache` header. The first request says 'Miss' — CloudFront fetched from S3. The second request says 'Hit' — served from cache in under 5ms. Also notice `x-amz-cf-pop: BOM62-P3` — that's the Mumbai edge. BOM is Mumbai's airport code. Every edge location is named after the nearest airport."

---

## 🟡 Lab 2: INTERMEDIATE — Cache Behaviors + Mixed Origins (30 minutes)

### Objective
Configure CloudFront with multiple origins: S3 for static content and ALB for API backend. Add a CloudFront Function for security headers.

### Step 1: Add ALB as a Second Origin

1. **CloudFront** → Your distribution → **Origins** tab
2. **Create origin:**
   - Origin domain: Your ALB DNS name (`streamflix-alb-xxx.us-east-1.elb.amazonaws.com`)
   - Protocol: **HTTPS only**
   - Minimum origin SSL protocol: TLSv1.2
   - Enable Origin Shield: No (for this lab)
3. **Create origin**

### Step 2: Create Cache Behavior for /api/*

1. **Behaviors** tab → **Create behavior**
2. Settings:
   - Path pattern: `/api/*`
   - Origin: Select the ALB origin
   - Viewer protocol: **HTTPS only**
   - Allowed methods: **GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE**
   - Cache policy: **CachingDisabled** (APIs shouldn't be cached!)
   - Origin request policy: **AllViewer** (forward all headers to ALB)
3. **Create behavior**

### Step 3: Create CloudFront Function for Security Headers

1. **CloudFront** → **Functions** → **Create function**
2. Name: `streamflix-security-headers`
3. **Code:**

```javascript
function handler(event) {
    var response = event.response;
    var headers = response.headers;
    
    headers['strict-transport-security'] = { 
        value: 'max-age=31536000; includeSubdomains; preload' 
    };
    headers['x-content-type-options'] = { value: 'nosniff' };
    headers['x-frame-options'] = { value: 'DENY' };
    headers['x-xss-protection'] = { value: '1; mode=block' };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    
    return response;
}
```

4. Click **Save changes**
5. Go to **Publish** tab → **Publish function**

### Step 4: Attach Function to Default Behavior

1. **CloudFront** → Distribution → **Behaviors** → Edit default behavior
2. Scroll to **Function associations**
3. **Viewer response:** Select `streamflix-security-headers`
4. **Save changes**

### Step 5: Test Mixed Origins

```bash
# Static content → S3 origin (cached)
curl -sI https://streamflix.sskdevops.in/ | grep -E "x-cache|server"
# server: AmazonS3
# x-cache: Hit from cloudfront

# API request → ALB origin (not cached)
curl -s https://streamflix.sskdevops.in/api/health
# → Response from your ALB backend

curl -sI https://streamflix.sskdevops.in/api/health | grep x-cache
# x-cache: Miss from cloudfront (ALWAYS miss — caching disabled)

# Verify security headers
curl -sI https://streamflix.sskdevops.in/ | grep -E "strict-transport|x-frame|x-content"
# strict-transport-security: max-age=31536000; includeSubdomains; preload
# x-frame-options: DENY
# x-content-type-options: nosniff
```

> [!TIP]
> **Teaching moment:** "One domain, two origins. `/` serves your React app from S3 (cached, fast). `/api/*` goes to your ALB (never cached, always fresh). The CloudFront Function adds security headers to EVERY response without touching your application code. This is the production pattern used by major tech companies."

---

## 🔴 Lab 3: ADVANCED — Cache Invalidation + Performance Comparison (30 minutes)

### Objective
Understand caching deeply. Measure performance, demonstrate invalidation, and compare CloudFront vs direct origin performance.

### Step 1: Performance Benchmark (CloudFront vs Direct Origin)

```bash
# Measure CloudFront response time (cached)
for i in $(seq 1 5); do
  echo -n "CloudFront Request $i: "
  curl -o /dev/null -s -w "%{time_total}s\n" https://streamflix.sskdevops.in/styles.css
done

# Expected output:
# CloudFront Request 1: 0.008s (8ms — from cache!)
# CloudFront Request 2: 0.006s
# CloudFront Request 3: 0.007s
# CloudFront Request 4: 0.005s
# CloudFront Request 5: 0.006s

# Compare with direct S3 (if you had public access):
# Direct S3 from far away: 0.200s (200ms — cross-region!)
```

### Step 2: Analyze Cache Headers

```bash
# Full response headers — understand every header
curl -sI https://streamflix.sskdevops.in/styles.css

# Key headers to explain:
# x-cache: Hit from cloudfront          ← Cache status
# x-amz-cf-pop: BOM62-P3               ← Edge location (Mumbai)
# x-amz-cf-id: abc123==                ← Request ID for debugging
# age: 3456                             ← Seconds since cached
# via: 1.1 abc.cloudfront.net           ← Proxy chain
# content-encoding: br                  ← Brotli compressed
# cache-control: max-age=86400          ← Client cache 24h
# etag: "abc123"                        ← Object version
```

### Step 3: Deploy an Update and Invalidate

```bash
# 1. Modify styles.css locally (change a color)
sed -i 's/#e94560/#00d2ff/g' app/styles.css

# 2. Upload to S3
aws s3 cp app/styles.css s3://streamflix-frontend-xxx/styles.css \
  --content-type "text/css"
```

3. Visit `https://streamflix.sskdevops.in` → **Still shows OLD color!** (cached)

4. **Invalidate:**
   - CloudFront → Distribution → **Invalidations** tab
   - **Create invalidation**
   - Object paths: `/styles.css`
   - Click **Create invalidation**

5. Watch invalidation progress (Status: In Progress → Completed)

```bash
# Wait ~60 seconds, then check:
curl -sI https://streamflix.sskdevops.in/styles.css | grep -E "x-cache|age"
# x-cache: Miss from cloudfront (fresh fetch!)
# age: 0
```

6. Visit again → **New color!** ✅

### Step 4: Wildcard Invalidation vs Versioned Files

```bash
# Invalidate EVERYTHING (costs same as one path)
# CloudFront → Create invalidation → Object paths: /*

# Better approach — upload versioned file:
HASH=$(md5sum app/styles.css | cut -c1-8)
aws s3 cp app/styles.css "s3://streamflix-frontend-xxx/styles.${HASH}.css" \
  --content-type "text/css" \
  --cache-control "max-age=31536000, immutable"

# Update index.html to reference the new filename
# This is what build tools (Vite, webpack) do automatically!
```

### Step 5: Monitor Cache Hit Ratio

1. **CloudFront** → **Monitoring** tab
2. View metrics:
   - **Total requests:** How many requests CloudFront handled
   - **Cache hit rate:** What % was served from cache
   - **Error rate:** 4xx and 5xx errors
   - **Bytes transferred:** Data volume

```bash
# Or via CLI:
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=EABC123 \
  --start-time $(date -u -v-1H '+%Y-%m-%dT%H:%M:%S') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \
  --period 300 \
  --statistics Average
```

> [!IMPORTANT]
> **Key learning:** "The invalidation took about 60 seconds to propagate to all 400+ edge locations worldwide. During that window, some users see old content, some see new. This is why versioned filenames are superior — the new filename is immediately unique, zero propagation delay."

---

## Cleanup

> [!CAUTION]
> **CloudFront distributions take 15-20 minutes to disable/delete.** Start cleanup early!

```bash
# 1. Disable CloudFront distribution
#    CloudFront → Distribution → Disable
#    Wait for status: Deployed → then Delete

# 2. Delete CloudFront Function
#    CloudFront → Functions → streamflix-security-headers → Unpublish → Delete

# 3. Delete S3 objects and bucket
aws s3 rm s3://streamflix-frontend-xxx --recursive
aws s3 rb s3://streamflix-frontend-xxx

# 4. Delete Route 53 records (ALIAS to CloudFront)

# 5. Delete WAF Web ACL (if auto-created)
#    WAF → Web ACLs → Global (CloudFront) → Delete

# 6. Delete ALB, Target Groups, EC2 instances (if created for this lab)

# 7. ACM certificates can stay (they're free)
#    Only delete if you want to clean up completely
```

---

## Summary: What Each Lab Teaches

| Lab | Level | Duration | Concepts |
|-----|-------|----------|----------|
| 🟢 **Lab 1** | Basic | 25 min | S3 + CloudFront + OAC, cache HIT/MISS, HTTP→HTTPS redirect, custom error pages, compression |
| 🟡 **Lab 2** | Intermediate | 30 min | Multiple origins (S3 + ALB), path-based routing, CachingDisabled for APIs, CloudFront Functions (security headers) |
| 🔴 **Lab 3** | Advanced | 30 min | Cache deep dive, invalidation vs versioned files, performance benchmarking, CloudWatch monitoring, cache hit ratio |

---

## Timing Summary

| Section | Duration |
|---------|----------|
| **Understanding CDNs** | |
| Part 1: Why CDNs? | 15 min |
| Part 2: How CDNs Work | 15 min |
| Part 3: What is CloudFront? | 10 min |
| Part 4: Core Concepts (Distributions, Origins, Behaviors) | 20 min |
| Part 5: Cache Policies & TTL | 15 min |
| **☕ BREAK** | **10 min** |
| **Advanced Features** | |
| Part 6: Cache Invalidation | 10 min |
| Part 7: Origin Failover | 10 min |
| Part 8: CloudFront Functions & Lambda@Edge | 15 min |
| Part 9: Signed URLs & Signed Cookies | 10 min |
| Part 10: CloudFront + WAF Integration | 10 min |
| Part 11: Origin Types & Architecture Patterns | 15 min |
| Part 12: Pricing | 10 min |
| **Operations** | |
| Part 13: Compression | 5 min |
| Part 14: HTTP/2 and HTTP/3 | 5 min |
| Part 15: Logging & Monitoring | 10 min |
| Part 16: Custom Error Pages | 5 min |
| Part 17: Geo Restriction | 5 min |
| Part 18: Interview Questions | 10 min |
| 🟢 Lab 1: Basic | 25 min |
| 🟡 Lab 2: Intermediate | 30 min |
| 🔴 Lab 3: Advanced | 30 min |
| **Total** | **~4 hours** |

> **Trainer tip:** Take the break after Part 5 (Cache Policies). First half = core concepts students MUST know. Second half = advanced features and labs. The cache HIT/MISS demonstration in Lab 1 is the "wow" moment — students see 8ms vs 200ms in real time.

> **Trainer tip:** The `x-amz-cf-pop` header is a great teaching tool. Show students the airport code mapping — BOM = Mumbai, IAD = Virginia, LHR = London. It makes CDN edge locations feel real and tangible.

> **Trainer tip:** In Lab 3, the performance comparison is powerful. Have all students run `curl` timing simultaneously and compare their edge locations. Students in different cities will show different PoPs but similar latencies — that's the magic of CDN.

> **Trainer tip:** The CloudFront Functions lab (Lab 2) is deceptively important. In real production, security headers are a compliance requirement. Show students that this ONE function replaces what would otherwise require ALB configuration, nginx config, or application code changes. Edge computing is the future.
