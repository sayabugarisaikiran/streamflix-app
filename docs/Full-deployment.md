# StreamFlix — Complete End-to-End Deployment Guide

> **What this is:** A single, continuous, step-by-step walkthrough that deploys the StreamFlix application from scratch using the AWS Console. By the end, you'll have a production-grade architecture with EC2, ALB, Auto Scaling, ACM, Route 53, S3, CloudFront, WAF, API Gateway, and Lambda — all working together.

> **Time:** 3–4 hours (instructor-led) or 5–6 hours (self-paced)

> **Cost:** ~$3–5 total if destroyed within the same day. **DESTROY EVERYTHING AFTER!**

---

## Final Architecture

```
                           ┌──────────────────────────────────────────────┐
                           │                                              │
                           │        streamflix.sskdevops.in                │
                           │                                              │
                           │  ┌──────────┐     ┌──────────────────┐       │
            ┌──── DNS ────►│  │ Route 53  │────►│ CloudFront CDN   │       │
            │              │  └──────────┘     │ + ACM (us-east-1)│       │
            │              │                   │ + WAF             │       │
  ┌──────┐  │              │                   └───────┬──────────┘       │
  │ User │──┤              │                     ┌─────┴──────┐           │
  └──────┘  │              │                     │            │           │
            │              │              ┌──────▼──┐   ┌─────▼────┐     │
            │              │              │  S3      │   │ ALB      │     │
            │              │              │ (static) │   │ + ACM    │     │
            │              │              │ + OAC    │   │ (HTTPS)  │     │
            │              │              └─────────┘   └────┬─────┘     │
            │              │                                 │           │
            │              │                    ┌────────────┼────┐      │
            │              │                    │            │    │      │
            │              │               ┌────▼───┐  ┌────▼───┐│      │
            │              │               │ EC2-1  │  │ EC2-2  ││      │
            │              │               │ AZ-a   │  │ AZ-b   ││      │
            │              │               │ nginx  │  │ nginx  ││      │
            │              │               └────────┘  └────────┘│      │
            │              │                    Auto Scaling Group│      │
            │              │                                     │      │
            │              │                                              │
            └──── API ────►│  api.sskdevops.in                            │
                           │    Route 53 → API Gateway → Lambda           │
                           └──────────────────────────────────────────────┘
```

---

## Prerequisites

Before you begin, ensure you have:

| Requirement | Details |
|-------------|---------|
| AWS Account | With admin access (or IAM user with EC2, S3, CloudFront, WAF, ACM, Route 53, Lambda, API GW permissions) |
| Domain Name | Registered in Route 53 (e.g., `sskdevops.in`). Cost: $3–12/year. |
| SSH Key Pair | Created in EC2 → Key Pairs (in the region you'll deploy to) |
| StreamFlix App Files | `index.html`, `styles.css`, `app.js`, `error.html` from the `app/` directory |
| AWS CLI | Installed and configured (`aws configure`) |
| Browser | Chrome or Firefox (for console access) |

> [!IMPORTANT]
> **Region Strategy:**
> - **Primary region:** `us-east-1` (N. Virginia) — we'll use this for everything since CloudFront certs MUST be here
> - This simplifies the lab. In production, you'd use separate regions for CloudFront cert vs ALB cert.

---

# PHASE 1: NETWORKING FOUNDATION

*"Before we deploy anything, we need the VPC and security groups that will house our infrastructure."*

## Step 1.1: Create the VPC (or Use Default)

> [!TIP]
> For this lab, the **Default VPC** works fine. If it was deleted, create one:
> VPC Console → **Your VPCs** → **Actions** → **Create default VPC**

1. Go to **VPC Console**
2. Verify your **Default VPC** exists with subnets in at least **2 Availability Zones**
3. Note down:
   - VPC ID: `vpc-xxxxxxxx`
   - Public Subnet AZ-a: `subnet-aaaa` (e.g., `us-east-1a`)
   - Public Subnet AZ-b: `subnet-bbbb` (e.g., `us-east-1b`)

## Step 1.2: Create Security Group for EC2 Instances

1. **VPC Console** → **Security Groups** → **Create security group**
2. Settings:
   - **Name:** `streamflix-ec2-sg`
   - **Description:** `Security group for StreamFlix web servers`
   - **VPC:** Default VPC

3. **Inbound Rules:**

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | My IP | Your SSH access |
| HTTP | 80 | Custom: `streamflix-alb-sg` (create ALB SG first, or use `0.0.0.0/0` temporarily) | ALB health checks + traffic |

4. Click **Create security group**

## Step 1.3: Create Security Group for ALB

1. **Create security group:**
   - **Name:** `streamflix-alb-sg`
   - **Description:** `Security group for StreamFlix ALB`
   - **VPC:** Default VPC

2. **Inbound Rules:**

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| HTTP | 80 | `0.0.0.0/0` | Public web traffic |
| HTTPS | 443 | `0.0.0.0/0` | Secure web traffic |

3. Click **Create security group**

4. **Go back to `streamflix-ec2-sg`** → Edit inbound rules → Change the HTTP source from `0.0.0.0/0` to the ALB security group: `streamflix-alb-sg`

> [!IMPORTANT]
> **Why this matters:** EC2 instances should ONLY accept traffic from the ALB, not from the internet directly. This is a security best practice — the ALB is the only entry point.

---

# PHASE 2: DEPLOY EC2 WEB SERVERS

*"Now we'll launch two web servers running the StreamFlix app in different Availability Zones."*

## Step 2.1: Launch EC2 Instance 1

1. **EC2 Console** → **Launch Instance**
2. Settings:

| Setting | Value |
|---------|-------|
| **Name** | `StreamFlix-Web-1` |
| **AMI** | Amazon Linux 2023 |
| **Instance type** | `t2.micro` (free tier) |
| **Key pair** | Select your key pair |
| **Network** | Default VPC |
| **Subnet** | Select subnet in **AZ-a** (e.g., `us-east-1a`) |
| **Auto-assign public IP** | **Enable** |
| **Security group** | Select `streamflix-ec2-sg` |

3. **Advanced Details → User Data:** Paste this script:

```bash
#!/bin/bash
yum update -y
yum install -y nginx

# Get instance metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/public-ipv4 || echo "none")
AMI_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/ami-id)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-type)

# Create metadata JSON for load balancing demo
cat > /usr/share/nginx/html/metadata.json <<EOF
{
    "instance_id": "$INSTANCE_ID",
    "availability_zone": "$AZ",
    "private_ip": "$PRIVATE_IP",
    "public_ip": "$PUBLIC_IP",
    "ami_id": "$AMI_ID",
    "instance_type": "$INSTANCE_TYPE",
    "server_name": "StreamFlix-Web-1",
    "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Create StreamFlix themed page (simple version for EC2 demo)
cat > /usr/share/nginx/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>StreamFlix — EC2 Backend</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, #0a0a1a 0%, #1a1a3e 50%, #0f0f2d 100%);
            color: #e0e0e0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .banner {
            background: linear-gradient(90deg, #00d2ff, #3a7bd5, #00d2ff);
            background-size: 200% 100%;
            animation: shimmer 3s linear infinite;
            color: #fff;
            padding: 12px 30px;
            border-radius: 50px;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 30px;
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
            justify-content: center;
        }
        @keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
        h1 { font-size: 56px; font-weight: 900; margin-bottom: 10px; }
        h1 span { background: linear-gradient(90deg, #00d2ff, #7b2ff7); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .subtitle { font-size: 18px; color: #888; margin-bottom: 40px; }
        .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; max-width: 900px; width: 100%; }
        .card {
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 16px;
            padding: 24px;
            text-align: center;
            backdrop-filter: blur(10px);
            transition: transform 0.3s, border-color 0.3s;
        }
        .card:hover { transform: translateY(-5px); border-color: #00d2ff; }
        .card-icon { font-size: 36px; margin-bottom: 12px; }
        .card h3 { font-size: 14px; color: #00d2ff; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 1px; }
        .card p { font-size: 18px; font-weight: 700; word-break: break-all; }
        .refresh-hint {
            margin-top: 40px;
            padding: 16px 24px;
            background: rgba(0,210,255,0.1);
            border: 1px dashed #00d2ff;
            border-radius: 12px;
            font-size: 14px;
            color: #00d2ff;
        }
        .health { color: #4caf50; font-weight: 700; }
    </style>
</head>
<body>
    <div class="banner" id="banner">Loading instance metadata...</div>
    <h1>🎬 Stream<span>Flix</span></h1>
    <p class="subtitle">EC2 Backend Server — Load Balancing Demo</p>
    <div class="cards" id="cards"></div>
    <div class="refresh-hint">
        💡 <strong>Refresh the page</strong> when behind an ALB — watch the Instance ID and AZ change!
    </div>
    <script>
        fetch('/metadata.json')
            .then(r => r.json())
            .then(data => {
                document.getElementById('banner').innerHTML =
                    `🖥️ Served by <strong>${data.server_name}</strong> &nbsp;|&nbsp; ` +
                    `${data.instance_id} &nbsp;|&nbsp; AZ: ${data.availability_zone} &nbsp;|&nbsp; IP: ${data.private_ip}`;
                document.getElementById('cards').innerHTML = `
                    <div class="card"><div class="card-icon">🏷️</div><h3>Instance ID</h3><p>${data.instance_id}</p></div>
                    <div class="card"><div class="card-icon">🌍</div><h3>Availability Zone</h3><p>${data.availability_zone}</p></div>
                    <div class="card"><div class="card-icon">🔒</div><h3>Private IP</h3><p>${data.private_ip}</p></div>
                    <div class="card"><div class="card-icon">📦</div><h3>AMI ID</h3><p>${data.ami_id}</p></div>
                    <div class="card"><div class="card-icon">⚙️</div><h3>Instance Type</h3><p>${data.instance_type}</p></div>
                    <div class="card"><div class="card-icon">🕐</div><h3>Deployed At</h3><p>${data.deployed_at}</p></div>
                    <div class="card"><div class="card-icon">❤️</div><h3>Health</h3><p class="health">✅ HEALTHY</p></div>
                    <div class="card"><div class="card-icon">🏠</div><h3>Server Name</h3><p>${data.server_name}</p></div>
                `;
            })
            .catch(() => {
                document.getElementById('banner').textContent = '⚠️ Not running on EC2 (metadata unavailable)';
            });
    </script>
</body>
</html>
HTMLEOF

# Nginx configuration
cat > /etc/nginx/conf.d/streamflix.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location /health {
        access_log off;
        return 200 '{"status":"healthy","server":"StreamFlix-Web-1"}';
        add_header Content-Type application/json;
    }

    location /metadata.json {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Access-Control-Allow-Origin *;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

rm -f /etc/nginx/conf.d/default.conf
nginx -t && systemctl enable nginx && systemctl start nginx
```

4. Click **Launch Instance**

## Step 2.2: Launch EC2 Instance 2

1. Repeat **Step 2.1** with these changes:

| Setting | Change |
|---------|--------|
| **Name** | `StreamFlix-Web-2` |
| **Subnet** | Pick **AZ-b** (e.g., `us-east-1b`) — **DIFFERENT AZ!** |
| **User Data** | Same script BUT change `StreamFlix-Web-1` → `StreamFlix-Web-2` (two occurrences in the script) |

2. Click **Launch Instance**

## Step 2.3: Verify Both Instances

Wait 2–3 minutes for instances to initialize, then:

```bash
# Get public IPs from EC2 console
EC2_1_IP="<Instance-1-Public-IP>"
EC2_2_IP="<Instance-2-Public-IP>"

# Test Instance 1
curl -s http://$EC2_1_IP/metadata.json | python3 -m json.tool
# Should show: "server_name": "StreamFlix-Web-1", AZ: us-east-1a

# Test Instance 2
curl -s http://$EC2_2_IP/metadata.json | python3 -m json.tool
# Should show: "server_name": "StreamFlix-Web-2", AZ: us-east-1b

# Test health endpoints
curl -s http://$EC2_1_IP/health
# {"status":"healthy","server":"StreamFlix-Web-1"}

curl -s http://$EC2_2_IP/health
# {"status":"healthy","server":"StreamFlix-Web-2"}
```

> [!TIP]
> Open both IPs in your browser. You should see the StreamFlix dark UI with **different Instance IDs** and **different AZs** in the blue banner. This proves you have two independent servers.

✅ **Checkpoint:** Two EC2 instances running StreamFlix in different AZs.

---

# PHASE 3: APPLICATION LOAD BALANCER

*"Now we'll put a load balancer in front of our two servers so traffic is distributed automatically."*

## Step 3.1: Create Target Group

1. **EC2 Console** → **Target Groups** → **Create target group**
2. Settings:

| Setting | Value |
|---------|-------|
| Target type | **Instances** |
| Name | `streamflix-web-tg` |
| Protocol / Port | HTTP / 80 |
| VPC | Default VPC |
| Health check protocol | HTTP |
| Health check path | `/health` |
| Healthy threshold | `2` |
| Unhealthy threshold | `2` |
| Interval | `10` seconds |
| Timeout | `5` seconds |
| Success codes | `200` |

3. Click **Next**
4. **Register targets:** Select BOTH `StreamFlix-Web-1` and `StreamFlix-Web-2` → Click **Include as pending below**
5. Click **Create target group**

## Step 3.2: Create the ALB

1. **EC2 Console** → **Load Balancers** → **Create** → **Application Load Balancer**
2. Settings:

| Setting | Value |
|---------|-------|
| Name | `streamflix-alb` |
| Scheme | **Internet-facing** |
| IP address type | IPv4 |
| VPC | Default VPC |
| Mappings | Select **both AZs** (us-east-1a AND us-east-1b) |
| Security group | `streamflix-alb-sg` |

3. **Listeners:**
   - Protocol: **HTTP**, Port: **80**
   - Default action: Forward to → `streamflix-web-tg`

4. Click **Create load balancer**
5. Wait 2–3 minutes for state to become **Active**

## Step 3.3: Test Load Balancing

```bash
# Get ALB DNS name from console
ALB_DNS="streamflix-alb-XXXXX.us-east-1.elb.amazonaws.com"

# Hit it 10 times — watch the server name alternate!
for i in $(seq 1 10); do
    echo -n "Request $i: "
    curl -s "http://$ALB_DNS/metadata.json" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"server_name\"]}  |  {d[\"instance_id\"]}  |  AZ: {d[\"availability_zone\"]}')"
done
```

**Expected output:**
```
Request 1:  StreamFlix-Web-1  |  i-abc123  |  AZ: us-east-1a
Request 2:  StreamFlix-Web-2  |  i-def456  |  AZ: us-east-1b
Request 3:  StreamFlix-Web-1  |  i-abc123  |  AZ: us-east-1a
Request 4:  StreamFlix-Web-2  |  i-def456  |  AZ: us-east-1b
...
```

## Step 3.4: Demonstrate Health Check Failover

1. **Stop** `StreamFlix-Web-1` (EC2 → Select → Instance State → **Stop**)
2. Go to **Target Groups** → `streamflix-web-tg` → **Targets** tab
3. Watch `StreamFlix-Web-1` status: `healthy` → `draining` → `unhealthy`
4. Hit the ALB again — **ALL traffic goes to StreamFlix-Web-2!**
5. **Start** `StreamFlix-Web-1` again → wait for it to become `healthy` → traffic splits again

✅ **Checkpoint:** ALB distributing traffic across two healthy EC2 instances. Failover works.

---

# PHASE 4: SSL/TLS WITH ACM

*"Our site works on HTTP, but it's not secure. Let's add HTTPS with a free ACM certificate."*

## Step 4.1: Request ACM Certificate

1. ⚠️ **Make sure you're in `us-east-1` (N. Virginia)!**
2. **Certificate Manager** → **Request a certificate** → **Request a public certificate** → Next
3. **Domain names:**
   - Primary: `sskdevops.in`
   - Click **Add another name**: `*.sskdevops.in` (wildcard — covers all subdomains)
4. **Validation method:** DNS validation
5. **Key algorithm:** RSA 2048
6. Click **Request**

## Step 4.2: DNS Validation

1. Click into the new certificate (Status: **Pending validation**)
2. In the **Domains** section, click **Create records in Route 53**
3. Confirm by clicking **Create records**
4. Wait 3–5 minutes → Status changes to **Issued** ✅

```bash
# Verify validation record exists
dig _xxxxxxxxx.sskdevops.in CNAME +short
# → _yyyyyyyy.acm-validations.aws.
```

> [!WARNING]
> If status stays "Pending" after 10 minutes: check Route 53 → Hosted zones → verify the CNAME validation record was created in the correct (public) hosted zone. Also ensure your domain's NS records point to the Route 53 nameservers.

## Step 4.3: Add HTTPS Listener to ALB

1. **EC2** → **Load Balancers** → `streamflix-alb` → **Listeners** tab
2. Click **Add listener**
3. Settings:

| Setting | Value |
|---------|-------|
| Protocol | HTTPS |
| Port | 443 |
| Default action | Forward to `streamflix-web-tg` |
| Security policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| Default SSL certificate | Select your ACM cert (`sskdevops.in`) |

4. Click **Add**

## Step 4.4: HTTP → HTTPS Redirect

1. Select the **HTTP:80** listener → **Manage rules** → **Edit rules**
2. **Delete** the existing forward action
3. **Add action:** Redirect to → HTTPS, Port 443, Status code: 301
4. **Save changes**

## Step 4.5: Create Route 53 Record for ALB

1. **Route 53** → **Hosted zones** → `sskdevops.in`
2. **Create record:**

| Setting | Value |
|---------|-------|
| Record name | `app` |
| Record type | A |
| Alias | ✅ ON |
| Route traffic to | **Application Load Balancer** → `us-east-1` → `streamflix-alb` |
| Evaluate target health | Yes |

3. Click **Create records**

## Step 4.6: Test HTTPS

```bash
# Wait 30-60 seconds for DNS propagation

# HTTPS works!
curl -sI https://app.sskdevops.in/ | head -5
# HTTP/2 200

# HTTP redirects to HTTPS!
curl -sI http://app.sskdevops.in/ | grep -i location
# location: https://app.sskdevops.in/

# Check certificate
echo | openssl s_client -connect app.sskdevops.in:443 -servername app.sskdevops.in 2>/dev/null | openssl x509 -noout -subject -issuer -dates
# subject=CN = sskdevops.in
# issuer=O = Amazon, CN = Amazon RSA 2048 M03
# notBefore=...
# notAfter=...
```

Open `https://app.sskdevops.in` in the browser — **see the padlock!** 🔒

✅ **Checkpoint:** ALB serving HTTPS with a free ACM certificate. HTTP redirects to HTTPS.

---

# PHASE 5: SERVERLESS BACKEND (API Gateway + Lambda)

*"The StreamFlix frontend has a 'Test Live API' button. Let's create the backend so it actually works."*

## Step 5.1: Create Lambda Function

1. **Lambda Console** → **Create function**
2. Settings:

| Setting | Value |
|---------|-------|
| Function name | `streamflix-backend` |
| Runtime | Python 3.13 |
| Architecture | x86_64 |

3. Click **Create function**
4. In the **Code** tab, replace the default code with:

```python
import json
import datetime

def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "🎬 StreamFlix API is live!",
            "service": "streamflix-backend",
            "region": "us-east-1",
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "powered_by": "AWS Lambda + API Gateway"
        })
    }
```

5. Click **Deploy**
6. Click **Test** → Create test event → **Test** → Verify it returns 200

## Step 5.2: Create API Gateway (HTTP API)

1. **API Gateway Console** → Scroll to **HTTP API** → **Build**
2. **Integrations:** Click **Add integration**
   - Integration type: **Lambda**
   - Lambda function: `streamflix-backend`
3. **API name:** `streamflix-api`
4. Click **Next**

5. **Configure routes:**
   - Method: `GET`
   - Resource path: `/hello`
   - Integration target: `streamflix-backend`
6. Click **Next**

7. **Stages:** Keep `$default` stage with auto-deploy ON
8. Click **Next** → **Create**

## Step 5.3: Enable CORS

1. In the API Gateway console, click your `streamflix-api`
2. Left menu → **CORS**
3. Click **Configure**:

| Setting | Value |
|---------|-------|
| Access-Control-Allow-Origins | `*` (or your specific domain) |
| Access-Control-Allow-Methods | `GET`, `OPTIONS` |
| Access-Control-Allow-Headers | `*` |

4. **Save**

## Step 5.4: Test the API

```bash
# Copy the Invoke URL from API Gateway console
API_URL="https://abc123xyz.execute-api.us-east-1.amazonaws.com"

curl -s "$API_URL/hello" | python3 -m json.tool
# {
#     "message": "🎬 StreamFlix API is live!",
#     "service": "streamflix-backend",
#     "region": "us-east-1",
#     "timestamp": "2026-04-18T10:30:00.000Z",
#     "powered_by": "AWS Lambda + API Gateway"
# }
```

> [!TIP]
> **Note the API URL.** You'll need it when deploying the full frontend to S3 in Phase 6. The StreamFlix `app.js` file has a `const API_GATEWAY_URL` at the top that needs to be updated.

✅ **Checkpoint:** Lambda backend responding through API Gateway.

---

# PHASE 6: STATIC FRONTEND ON S3 + CLOUDFRONT

*"Now we'll deploy the full StreamFlix frontend (the beautiful Netflix-style UI) to S3 and put CloudFront in front of it."*

## Step 6.1: Create S3 Bucket

1. **S3 Console** → **Create bucket**

| Setting | Value |
|---------|-------|
| Bucket name | `streamflix-frontend-<YOUR-NAME>-<RANDOM>` (must be globally unique) |
| Region | `us-east-1` |
| Object Ownership | ACLs disabled |
| Block Public Access | ✅ **Block ALL public access** (leave ALL checkboxes checked!) |

2. Click **Create bucket**

> [!IMPORTANT]
> Do NOT enable "Static Website Hosting." We don't need it — CloudFront with OAC is the modern, secure pattern.

## Step 6.2: Update and Upload Frontend Files

1. **Update `app/app.js`:** Open the file and find `const API_GATEWAY_URL` near the top. Replace the placeholder with your actual API Gateway URL + `/hello`:

```javascript
const API_GATEWAY_URL = 'https://abc123xyz.execute-api.us-east-1.amazonaws.com/hello';
```

2. **Upload all files to S3:**

```bash
# Navigate to your project directory
cd /path/to/aws-class

# Upload with correct content types
aws s3 cp app/index.html s3://streamflix-frontend-xxx/index.html --content-type "text/html"
aws s3 cp app/styles.css s3://streamflix-frontend-xxx/styles.css --content-type "text/css"
aws s3 cp app/app.js s3://streamflix-frontend-xxx/app.js --content-type "application/javascript"
aws s3 cp app/error.html s3://streamflix-frontend-xxx/error.html --content-type "text/html"
```

Or via the console: **Open bucket → Upload → Add files → Select all 4 files → Upload**

## Step 6.3: Create CloudFront Distribution

1. **CloudFront Console** → **Create distribution**

### Origin Settings:

| Setting | Value |
|---------|-------|
| Origin domain | Select your S3 bucket from dropdown |
| Origin path | (leave blank) |
| Origin access | **Origin Access Control settings (recommended)** |

2. Click **Create new OAC** → Accept defaults → **Create**

### Default Cache Behavior:

| Setting | Value |
|---------|-------|
| Viewer protocol policy | **Redirect HTTP to HTTPS** |
| Allowed HTTP methods | **GET, HEAD** |
| Cache policy | **CachingOptimized** (managed) |
| Compress objects automatically | **Yes** ✅ |

### WAF (we'll configure separately in Phase 7):

- Select **Do not enable security protections** (we'll add WAF manually with custom rules)

### Settings:

| Setting | Value |
|---------|-------|
| Price class | Use all edge locations (or PriceClass_200 to save) |
| Alternate domain name (CNAME) | `streamflix.sskdevops.in` |
| Custom SSL certificate | Select your ACM cert (`sskdevops.in` / `*.sskdevops.in`) |
| Supported HTTP versions | HTTP/2 ✅, HTTP/3 ✅ |
| Default root object | `index.html` |

3. Click **Create distribution**

## Step 6.4: Update S3 Bucket Policy

1. CloudFront shows a **yellow banner**: "S3 bucket policy needs to be updated"
2. Click **Copy policy**
3. Go to **S3** → Your bucket → **Permissions** → **Bucket policy** → **Edit**
4. Paste the policy → **Save changes**

## Step 6.5: Add Custom Error Pages

1. CloudFront → Your distribution → **Error pages** tab
2. **Create custom error response:**

| Error Code | Response Page Path | Response Code | Error Caching TTL |
|------------|-------------------|---------------|-------------------|
| 403 | `/error.html` | 404 | 10 seconds |
| 404 | `/error.html` | 404 | 10 seconds |

## Step 6.6: Create Route 53 Record for CloudFront

1. **Route 53** → **Hosted zones** → `sskdevops.in`
2. **Create record:**

| Setting | Value |
|---------|-------|
| Record name | `streamflix` |
| Record type | A |
| Alias | ✅ ON |
| Route traffic to | **Alias to CloudFront distribution** → select your distribution |

3. **Create records**

## Step 6.7: Test CloudFront + S3

```bash
# Wait 5-10 minutes for CloudFront distribution to deploy (Status: Enabled)

# Test HTTPS access
curl -sI https://streamflix.sskdevops.in/ | head -10
# HTTP/2 200
# content-type: text/html
# server: AmazonS3
# x-cache: Miss from cloudfront (first request)

# Second request — CACHE HIT!
curl -sI https://streamflix.sskdevops.in/ | grep x-cache
# x-cache: Hit from cloudfront

# Check edge location
curl -sI https://streamflix.sskdevops.in/ | grep x-amz-cf-pop
# x-amz-cf-pop: IAD89-C2 (Virginia edge) or BOM62-P3 (Mumbai edge)

# Verify direct S3 access is BLOCKED
curl -sI "https://streamflix-frontend-xxx.s3.us-east-1.amazonaws.com/index.html"
# 403 Forbidden ✅

# Test compression
curl -sI -H "Accept-Encoding: br" https://streamflix.sskdevops.in/styles.css | grep content-encoding
# content-encoding: br (Brotli compression!)
```

Open `https://streamflix.sskdevops.in` in the browser — you should see the full StreamFlix UI with particles, architecture diagram, service cards, and all interactive sections! 🎬

✅ **Checkpoint:** Full StreamFlix frontend served globally via CloudFront. S3 is private. HTTPS works.

---

# PHASE 7: WAF PROTECTION

*"Our site is public and accessible. Now let's protect it from attacks."*

## Step 7.1: Create WAF Web ACL

1. ⚠️ **Make sure you're in `us-east-1`!** WAF for CloudFront must be in N. Virginia.
2. **WAF & Shield Console** → **Web ACLs** → **Create web ACL**
3. Settings:

| Setting | Value |
|---------|-------|
| Name | `streamflix-waf` |
| Description | `WAF for StreamFlix: Rate limiting + OWASP rules` |
| Resource type | **CloudFront distributions** |
| Associated resources | Click **Add AWS resources** → Select your CloudFront distribution |

4. Click **Next**

## Step 7.2: Add WAF Rules

### Rule 1: Rate Limiting

1. **Add rules** → **Add my own rules** → **Rule builder**
2. Settings:

| Setting | Value |
|---------|-------|
| Name | `RateLimitRule` |
| Type | **Rate-based rule** |
| Rate limit | `100` (requests per 5-minute window) |
| IP address to use | **Source IP address** |
| Action | **Block** |

3. Click **Add rule**

### Rule 2: AWS Managed Common Rule Set (OWASP Top 10)

1. **Add rules** → **Add managed rule groups**
2. Expand **AWS managed rule groups**
3. Toggle ON: **Core rule set** (AWSManagedRulesCommonRuleSet)
4. Toggle ON: **Known bad inputs** (AWSManagedRulesKnownBadInputsRuleSet)
5. Toggle ON: **SQL database** (AWSManagedRulesSQLiRuleSet)

### Set Rule Priorities

| Priority | Rule |
|----------|------|
| 1 | RateLimitRule |
| 2 | AWSManagedRulesCommonRuleSet |
| 3 | AWSManagedRulesKnownBadInputsRuleSet |
| 4 | AWSManagedRulesSQLiRuleSet |

5. **Default action:** Allow (block only known threats)
6. Click **Next** through remaining steps → **Create web ACL**

## Step 7.3: Test WAF Protection

```bash
# Normal request — should work
curl -sI https://streamflix.sskdevops.in/ | head -3
# HTTP/2 200

# SQL injection attempt — should be blocked by WAF
curl -sI "https://streamflix.sskdevops.in/?id=1'%20OR%20'1'='1"
# HTTP/2 403 (BLOCKED by WAF!)

# XSS attempt — should be blocked
curl -sI "https://streamflix.sskdevops.in/?q=<script>alert('xss')</script>"
# HTTP/2 403 (BLOCKED by WAF!)
```

> [!TIP]
> Check WAF metrics: **WAF Console** → `streamflix-waf` → **Overview** tab. You'll see counters for allowed vs blocked requests and which rules triggered.

✅ **Checkpoint:** WAF protecting CloudFront. SQL injection and XSS blocked. Rate limiting active.

---

# PHASE 8: AUTO SCALING GROUP

*"Right now we have two manually created EC2 instances. Let's convert this to an Auto Scaling Group that automatically adds/removes servers based on demand."*

## Step 8.1: Create AMI from Existing Instance

1. **EC2** → **Instances** → Select `StreamFlix-Web-1`
2. **Actions** → **Image and templates** → **Create image**

| Setting | Value |
|---------|-------|
| Image name | `StreamFlix-Web-AMI` |
| Description | `StreamFlix app with nginx configured` |
| No reboot | ✅ Check this |

3. Click **Create image**
4. Wait for AMI to become **available** (2–5 minutes): **EC2** → **AMIs**

## Step 8.2: Create Launch Template

1. **EC2** → **Launch Templates** → **Create launch template**

| Setting | Value |
|---------|-------|
| Name | `streamflix-lt` |
| Template version description | `v1 - initial StreamFlix deployment` |
| AMI | Select `StreamFlix-Web-AMI` (your custom AMI) |
| Instance type | `t2.micro` |
| Key pair | Your key pair |
| Security group | `streamflix-ec2-sg` |

2. **Advanced details → User Data:** (simplified — AMI already has nginx + app)

```bash
#!/bin/bash
# Update metadata for this specific instance
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4)

cat > /usr/share/nginx/html/metadata.json <<EOF
{
    "instance_id": "$INSTANCE_ID",
    "availability_zone": "$AZ",
    "private_ip": "$PRIVATE_IP",
    "server_name": "StreamFlix-ASG-$INSTANCE_ID",
    "launch_template": "v1",
    "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

systemctl restart nginx
```

3. Click **Create launch template**

## Step 8.3: Create Auto Scaling Group

1. **EC2** → **Auto Scaling Groups** → **Create Auto Scaling group**
2. Settings:

| Setting | Value |
|---------|-------|
| Name | `streamflix-asg` |
| Launch template | `streamflix-lt` (Latest) |

3. **Network:**
   - VPC: Default VPC
   - Subnets: Select **both AZs** (same as your ALB)

4. **Load balancing:**
   - ✅ **Attach to an existing load balancer**
   - Select: **Choose from your load balancer target groups**
   - Target group: `streamflix-web-tg`
   - Health check type: **ELB** ← CRITICAL!
   - Health check grace period: `120` seconds

5. **Group size:**

| Setting | Value |
|---------|-------|
| Desired capacity | 2 |
| Minimum capacity | 2 |
| Maximum capacity | 6 |

6. **Scaling policies:**
   - ✅ **Target tracking scaling policy**
   - Policy name: `CPU-Target-50`
   - Metric: **Average CPU utilization**
   - Target value: `50`
   - Instance warmup: `120` seconds

7. **Notifications (optional):**
   - Add SNS topic for Launch, Terminate, and Fail events

8. Click **Create Auto Scaling group**

## Step 8.4: Clean Up Manual Instances

1. The ASG will launch 2 fresh instances automatically
2. Once they're **InService** and **healthy** in the target group:
   - **Terminate** the original `StreamFlix-Web-1` and `StreamFlix-Web-2` (they're not managed by the ASG)

## Step 8.5: Verify ASG

```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names streamflix-asg \
    --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].{Id:InstanceId,Status:LifecycleState,Health:HealthStatus}}'

# Hit the ALB — should see ASG instances
for i in $(seq 1 6); do
    echo -n "Request $i: "
    curl -s "https://app.sskdevops.in/metadata.json" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"server_name\"]}  |  AZ: {d[\"availability_zone\"]}')"
done
```

✅ **Checkpoint:** Auto Scaling Group managing EC2 instances behind the ALB. Auto-healing and auto-scaling active.

---

# PHASE 9: DATA FLOW SUMMARY

*"Let's trace a complete request through our architecture to understand how everything connects."*

## Step 9.1: The Full Request Journey

```
User types: https://streamflix.sskdevops.in

1. DNS Resolution (Route 53):
   streamflix.sskdevops.in → ALIAS → d3abc.cloudfront.net → Anycast IP

2. TLS Handshake (ACM):
   CloudFront presents ACM certificate for *.sskdevops.in
   Browser verifies: Amazon CA ✅, not expired ✅, domain match ✅

3. WAF Inspection:
   streamflix-waf checks: SQLi? No. XSS? No. Rate limit? OK.
   → ALLOW

4. CloudFront Edge:
   Cache check for /index.html
   HIT? → Return cached copy (8ms)
   MISS? → Fetch from S3 via OAC → Cache → Return

5. User sees the StreamFlix UI. Clicks "Test Live API":
   Browser: GET https://abc123.execute-api.us-east-1.amazonaws.com/hello

6. API Gateway → Lambda → Response:
   {"message": "🎬 StreamFlix API is live!"}

7. User goes to https://app.sskdevops.in (ALB path):
   Route 53 → ALB → ASG instances → One of the EC2s responds
   Refresh → Different EC2 responds (load balanced!)
```

## Step 9.2: Verify the Complete Stack

```bash
echo "=== 1. CloudFront Frontend ==="
curl -sI https://streamflix.sskdevops.in/ | grep -E "HTTP|x-cache|x-amz-cf-pop|server"

echo ""
echo "=== 2. HTTPS + Certificate ==="
echo | openssl s_client -connect streamflix.sskdevops.in:443 -servername streamflix.sskdevops.in 2>/dev/null | openssl x509 -noout -subject -issuer

echo ""
echo "=== 3. HTTP → HTTPS Redirect ==="
curl -sI http://streamflix.sskdevops.in/ | grep -i location

echo ""
echo "=== 4. WAF Block (SQLi) ==="
curl -sI "https://streamflix.sskdevops.in/?id=1'%20OR%20'1'='1" | grep HTTP

echo ""
echo "=== 5. ALB + Load Balancing ==="
for i in 1 2 3 4; do
    echo -n "  Request $i: "
    curl -s "https://app.sskdevops.in/metadata.json" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d.get(\"server_name\",\"?\")} | AZ: {d.get(\"availability_zone\",\"?\")}')" 2>/dev/null || echo "N/A"
done

echo ""
echo "=== 6. API Gateway + Lambda ==="
curl -s "https://abc123.execute-api.us-east-1.amazonaws.com/hello" | python3 -m json.tool

echo ""
echo "=== 7. S3 Direct Access (Should FAIL) ==="
curl -sI "https://streamflix-frontend-xxx.s3.us-east-1.amazonaws.com/index.html" | grep HTTP
```

**Expected results:**
```
=== 1. CloudFront Frontend ===
HTTP/2 200
x-cache: Hit from cloudfront
x-amz-cf-pop: IAD89-C2
server: AmazonS3

=== 2. HTTPS + Certificate ===
subject=CN = sskdevops.in
issuer=O = Amazon, CN = Amazon RSA 2048 M03

=== 3. HTTP → HTTPS Redirect ===
location: https://streamflix.sskdevops.in/

=== 4. WAF Block (SQLi) ===
HTTP/2 403

=== 5. ALB + Load Balancing ===
  Request 1: StreamFlix-ASG-i-abc | AZ: us-east-1a
  Request 2: StreamFlix-ASG-i-def | AZ: us-east-1b
  Request 3: StreamFlix-ASG-i-abc | AZ: us-east-1a
  Request 4: StreamFlix-ASG-i-def | AZ: us-east-1b

=== 6. API Gateway + Lambda ===
{
    "message": "🎬 StreamFlix API is live!",
    ...
}

=== 7. S3 Direct Access (Should FAIL) ===
HTTP/1.1 403 Forbidden
```

✅ **ALL 8 services working together!**

---

# PHASE 10: DNS RECORD SUMMARY

At this point, your Route 53 hosted zone should have these records:

| Record Name | Type | Alias/Value | Purpose |
|-------------|------|-------------|---------|
| `sskdevops.in` | NS | (auto-created) | Nameservers |
| `sskdevops.in` | SOA | (auto-created) | Zone authority |
| `streamflix.sskdevops.in` | A (ALIAS) | → CloudFront distribution | Frontend via CDN |
| `app.sskdevops.in` | A (ALIAS) | → ALB | Backend via load balancer |
| `_xxxx.sskdevops.in` | CNAME | → `_yyyy.acm-validations.aws` | ACM cert validation |
| `_xxxx.*.sskdevops.in` | CNAME | → `_yyyy.acm-validations.aws` | ACM wildcard validation |

---

# 🧹 CLEANUP — DESTROY EVERYTHING!

> [!CAUTION]
> **Run this after every lab session!** ALB: ~$16/month. CloudFront: per-request. WAF: $5/month per Web ACL. EC2: $0.0116/hour each. These add up fast if forgotten!

### Order matters — delete in this sequence:

```bash
echo "🧹 Step 1: Delete Auto Scaling Group (terminates EC2 instances)"
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name streamflix-asg \
    --force-delete

echo "🧹 Step 2: Delete Launch Template"
aws ec2 delete-launch-template --launch-template-name streamflix-lt

echo "🧹 Step 3: Wait for ASG instances to terminate (30 seconds)"
sleep 30

echo "🧹 Step 4: Delete ALB"
ALB_ARN=$(aws elbv2 describe-load-balancers --names streamflix-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"

echo "🧹 Step 5: Delete Target Group"
TG_ARN=$(aws elbv2 describe-target-groups --names streamflix-web-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 delete-target-group --target-group-arn "$TG_ARN"

echo "🧹 Step 6: Delete any remaining manual EC2 instances"
# Check EC2 console and terminate StreamFlix-Web-1, StreamFlix-Web-2 if still running

echo "🧹 Step 7: Disable and delete CloudFront distribution"
# Console: CloudFront → Distribution → Disable → Wait 15 min → Delete

echo "🧹 Step 8: Delete WAF Web ACL"
# Console: WAF → Web ACLs → Global (CloudFront) → streamflix-waf
# First remove CloudFront association, then delete the Web ACL

echo "🧹 Step 9: Empty and delete S3 bucket"
aws s3 rm s3://streamflix-frontend-xxx --recursive
aws s3 rb s3://streamflix-frontend-xxx

echo "🧹 Step 10: Delete API Gateway"
# Console: API Gateway → streamflix-api → Delete

echo "🧹 Step 11: Delete Lambda function"
aws lambda delete-function --function-name streamflix-backend

echo "🧹 Step 12: Delete Route 53 records"
# Console: Route 53 → Hosted zone → Delete A/ALIAS records for streamflix and app
# ⚠️ KEEP the ACM validation CNAMEs if you want the cert to auto-renew
# ⚠️ DO NOT delete NS or SOA records!

echo "🧹 Step 13: Delete ACM certificates (optional)"
# Console: ACM → Select → Delete
# Only if you won't be using them again

echo "🧹 Step 14: Delete Security Groups"
# Console: VPC → Security Groups → Delete streamflix-alb-sg and streamflix-ec2-sg
# (Can't delete if still attached to resources — clean up EC2/ALB first)

echo "🧹 Step 15: Delete AMI + Snapshot"
# Console: EC2 → AMIs → Deregister StreamFlix-Web-AMI
# Console: EC2 → Snapshots → Delete the associated snapshot

echo "✅ Cleanup complete!"
```

### Manual Cleanup Checklist (Console):

- [ ] Auto Scaling Group deleted
- [ ] Launch Template deleted
- [ ] ALL EC2 instances terminated
- [ ] ALB deleted
- [ ] Target Groups deleted
- [ ] CloudFront distribution disabled → deleted
- [ ] WAF Web ACL deleted
- [ ] S3 bucket emptied → deleted
- [ ] API Gateway deleted
- [ ] Lambda function deleted
- [ ] Route 53 custom records deleted (keep NS, SOA, ACM validation CNAMEs)
- [ ] ACM certificates deleted (optional)
- [ ] Security Groups deleted
- [ ] AMI deregistered + snapshot deleted
- [ ] CloudWatch log groups deleted (`/aws/apigateway/streamflix-api`)
- [ ] IAM roles deleted (`streamflix-lambda-role`) if auto-created

---

## Architecture vs Service Summary

| Service | What It Does in This Lab | Phase |
|---------|-------------------------|-------|
| **VPC + Security Groups** | Network isolation. ALB SG allows 80/443 from internet. EC2 SG allows 80 only from ALB. | 1 |
| **EC2** | Runs nginx serving the StreamFlix backend UI with instance metadata | 2 |
| **ALB** | Distributes traffic 50/50 across EC2s. Health checks. HTTPS termination. | 3 |
| **ACM** | Free SSL/TLS certificate. Attached to ALB (HTTPS listener) and CloudFront. Auto-renews. | 4 |
| **Lambda** | Serverless API backend. Returns JSON from `/hello`. Zero servers to manage. | 5 |
| **API Gateway** | HTTP API routing `GET /hello` to Lambda. CORS enabled. Auto-deploy. | 5 |
| **S3** | Stores static frontend files (HTML/CSS/JS). All public access blocked. | 6 |
| **CloudFront** | CDN distributing S3 content globally. OAC for secure S3 access. Compression. | 6 |
| **WAF** | Firewall at CloudFront edge. Blocks SQLi, XSS, rate limits. OWASP rules. | 7 |
| **Route 53** | DNS routing. `streamflix.` → CloudFront. `app.` → ALB. ACM validation CNAMEs. | 4, 6 |
| **Auto Scaling** | Automatically maintains 2–6 EC2 instances based on CPU. Self-healing. | 8 |

---

## Quick Reference: URLs After Deployment

| URL | What It Serves | AWS Path |
|-----|---------------|----------|
| `https://streamflix.sskdevops.in/` | Full StreamFlix UI (static) | Route 53 → CloudFront → S3 |
| `https://app.sskdevops.in/` | Load balanced backend UI | Route 53 → ALB → EC2 (ASG) |
| `https://app.sskdevops.in/health` | Health check endpoint | Route 53 → ALB → EC2 |
| `https://app.sskdevops.in/metadata.json` | Instance metadata (shows load balancing) | Route 53 → ALB → EC2 |
| `https://abc123.execute-api.../hello` | Serverless API response | API Gateway → Lambda |
