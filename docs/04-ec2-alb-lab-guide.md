# StreamFlix EC2 + ALB + Route 53 — Complete Lab Guide

## Prerequisites

Before starting this lab, ensure you have:
- An AWS account with EC2, ALB, and Route 53 permissions
- An SSH key pair created in AWS (EC2 → Key Pairs → Create)
- A registered domain in Route 53 (optional but recommended — $3-12 for `.click` or `.com`)
- AWS CLI configured (`aws configure`)
- Terraform installed (for automated path)

> [!IMPORTANT]
> **Estimated Cost:** ~$2/hour while running. **DESTROY everything after the lab!**
> - ALB: $0.0225/hour + traffic
> - 2x t2.micro EC2: Free tier or $0.0116/hour each
> - Route 53: $0.50/month per hosted zone

---

## Lab Architecture

```
                                                ┌──────────────┐
                                           ┌───►│  EC2-Web-1   │
                                           │    │  AZ: us-e-1a │
┌──────┐     ┌──────────┐     ┌────────┐   │    │  i-abc123    │
│ User │────►│ Route 53 │────►│  ALB   │───┤    └──────────────┘
└──────┘     │ (ALIAS)  │     │ :80    │   │
             └──────────┘     └────────┘   │    ┌──────────────┐
                                           └───►│  EC2-Web-2   │
                                                │  AZ: us-e-1b │
                                                │  i-def456    │
                                                └──────────────┘
```

---

## Part 1: Launch EC2 Instance (Manual — AWS Console)

### Step 1: Create a Security Group

1. Go to **EC2 Console** → **Security Groups** → **Create**
2. Name: `streamflix-ec2-sg`
3. VPC: Default VPC (or your lab VPC)
4. **Inbound Rules:**

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | My IP | SSH access |
| HTTP | 80 | 0.0.0.0/0 | Web traffic |

5. Click **Create Security Group**

### Step 2: Launch Instance 1

1. Go to **EC2** → **Launch Instance**
2. Settings:
   - **Name:** `StreamFlix-Web-1`
   - **AMI:** Amazon Linux 2023
   - **Instance type:** `t2.micro` (free tier)
   - **Key pair:** Select your key
   - **Network:** Default VPC, public subnet
   - **Auto-assign public IP:** Enable
   - **Security group:** `streamflix-ec2-sg`
3. **Advanced Details → User Data:** Paste this script:

```bash
#!/bin/bash
yum update -y
yum install -y nginx
systemctl enable nginx
systemctl start nginx

# Get instance metadata
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

cat > /usr/share/nginx/html/metadata.json <<EOF
{
    "instance_id": "$INSTANCE_ID",
    "availability_zone": "$AZ",
    "private_ip": "$PRIVATE_IP",
    "public_ip": "$PUBLIC_IP",
    "ami_id": "$AMI_ID",
    "instance_type": "$INSTANCE_TYPE",
    "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

cat > /etc/nginx/conf.d/health.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location /health {
        access_log off;
        return 200 '{"status":"healthy"}';
        add_header Content-Type application/json;
    }

    location /metadata.json {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

rm -f /etc/nginx/conf.d/default.conf
nginx -t && systemctl restart nginx
```

4. Click **Launch Instance**
5. Wait 2-3 minutes for instance to initialize

### Step 3: Deploy the StreamFlix App

```bash
# Get the public IP from EC2 console, then:
chmod +x terraform/ec2/deploy_to_ec2.sh
./terraform/ec2/deploy_to_ec2.sh ~/.ssh/your-key.pem <INSTANCE-1-PUBLIC-IP>
```

### Step 4: Verify Instance 1

```bash
# Open in browser
open http://<INSTANCE-1-PUBLIC-IP>

# You should see:
#   🖥️ Served by EC2  |  i-abc123  |  AZ: us-east-1a  |  IP: 10.0.1.x

# Check health endpoint
curl http://<INSTANCE-1-PUBLIC-IP>/health
# → {"status":"healthy"}

# Check metadata
curl http://<INSTANCE-1-PUBLIC-IP>/metadata.json
```

> [!TIP]
> **Teaching moment:** "This is your server running on a public IP. Anyone with this IP can access it. But who's going to remember `54.230.10.42`? Nobody. That's why we need DNS."

---

## Part 2: Map IP to DNS Name (A Record)

> [!IMPORTANT]
> You need a domain registered in Route 53 for this part.

### Step 1: Create an A Record

1. Go to **Route 53** → **Hosted Zones** → Click your domain
2. Click **Create Record**
3. Settings:
   - **Record name:** `server1`
   - **Record type:** `A`
   - **Value:** `<INSTANCE-1-PUBLIC-IP>` (e.g., `54.230.10.42`)
   - **TTL:** `60` seconds
   - **Routing policy:** Simple
4. Click **Create Records**

### Step 2: Verify DNS Resolution

```bash
# Wait 30-60 seconds for DNS propagation, then:
dig server1.yourdomain.com A +short
# → 54.230.10.42

# Open in browser
open http://server1.yourdomain.com

# Same StreamFlix page, but now accessible via a DOMAIN NAME!
```

> [!TIP]
> **Teaching moment:** "You just mapped an IP address to a human-readable name. This is the most basic DNS operation — an **A Record**. Every website in the world starts with this."

---

## Part 3: Create AMI and Launch Instance 2

### Step 1: Create AMI from Instance 1

1. Go to **EC2** → **Instances** → Select `StreamFlix-Web-1`
2. **Actions** → **Image and templates** → **Create image**
3. Settings:
   - **Image name:** `StreamFlix-Web-AMI`
   - **Description:** `StreamFlix app with nginx configured`
   - **No reboot:** ✅ (check this to avoid downtime during demo)
4. Click **Create image**
5. Go to **AMIs** → Wait for status to change to `available` (2-5 minutes)

> [!TIP]
> **Teaching moment:** "An AMI is like a snapshot/template of your entire server — OS, apps, config, everything. You can launch 100 identical servers from one AMI. This is how Netflix scales."

### Step 2: Launch Instance 2 from AMI

1. Go to **AMIs** → Select `StreamFlix-Web-AMI` → **Launch instance from AMI**
2. Settings:
   - **Name:** `StreamFlix-Web-2`
   - **Instance type:** `t2.micro`
   - **Key pair:** Same key
   - **Subnet:** Pick a **DIFFERENT Availability Zone** (e.g., `us-east-1b`)
   - **Security group:** Same `streamflix-ec2-sg`
3. Click **Launch Instance**

### Step 3: Deploy app to Instance 2 and Verify

```bash
# Deploy the app (will regenerate metadata.json with new instance ID)
./terraform/ec2/deploy_to_ec2.sh ~/.ssh/your-key.pem <INSTANCE-2-PUBLIC-IP>

# Verify — should show DIFFERENT instance ID and AZ!
open http://<INSTANCE-2-PUBLIC-IP>
```

> [!IMPORTANT]
> **Key observation for students:** "Both servers run identical code, but the green banner shows **different instance IDs** and **different AZs**. This is the foundation of high availability — same app, multiple servers, multiple data centers."

---

## Part 4: Create Application Load Balancer

### Step 1: Create ALB Security Group

1. **EC2** → **Security Groups** → **Create**
2. Name: `streamflix-alb-sg`
3. **Inbound Rules:**

| Type | Port | Source |
|------|------|--------|
| HTTP | 80 | 0.0.0.0/0 |
| HTTPS | 443 | 0.0.0.0/0 |

### Step 2: Create Target Group

1. Go to **EC2** → **Target Groups** → **Create**
2. Settings:
   - **Target type:** Instances
   - **Name:** `streamflix-web-tg`
   - **Protocol/Port:** HTTP / 80
   - **VPC:** Your VPC
   - **Health check path:** `/health`
   - **Healthy threshold:** 2
   - **Interval:** 10 seconds
3. Click **Next** → Select BOTH instances → **Include as pending** → **Create**

### Step 3: Create ALB

1. Go to **EC2** → **Load Balancers** → **Create** → **Application Load Balancer**
2. Settings:
   - **Name:** `streamflix-lab-alb`
   - **Scheme:** Internet-facing
   - **IP type:** IPv4
   - **Mappings:** Select at least 2 AZs (the ones your instances are in)
   - **Security group:** `streamflix-alb-sg`
   - **Listener:** HTTP:80 → Forward to `streamflix-web-tg`
3. Click **Create load balancer**
4. Wait 2-3 minutes for ALB to become `active`

### Step 4: Test Load Balancing

```bash
# Get ALB DNS name from the console, then:
ALB_DNS="streamflix-lab-alb-1234567890.us-east-1.elb.amazonaws.com"

# Hit it multiple times — watch the instance ID change!
for i in {1..10}; do
    echo "Request $i:"
    curl -s http://$ALB_DNS/metadata.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Instance: {d[\"instance_id\"]}  AZ: {d[\"availability_zone\"]}')"
done
```

Expected output:
```
Request 1:  Instance: i-abc123  AZ: us-east-1a
Request 2:  Instance: i-def456  AZ: us-east-1b
Request 3:  Instance: i-abc123  AZ: us-east-1a
Request 4:  Instance: i-def456  AZ: us-east-1b
...
```

> [!TIP]
> **Teaching moment:** "Open the browser and hit the ALB URL. Refresh. Refresh again. See the Instance ID changing in the green banner? That's load balancing! The ALB is distributing your requests across both servers."

### Step 5: Show Health Check in Action

1. **Stop** Instance 2 (EC2 → Select → Instance State → Stop)
2. Go to **Target Groups** → `streamflix-web-tg` → **Targets** tab
3. Watch Instance 2 status change: `healthy` → `draining` → `unhealthy`
4. Now ALL traffic goes to Instance 1!
5. **Start** Instance 2 again → watch it become `healthy`

---

## Part 5: Map DNS to ALB (ALIAS Record)

### Step 1: Create ALIAS Record

1. Go to **Route 53** → **Hosted Zones** → Your domain
2. **Create Record:**
   - **Record name:** `app`
   - **Record type:** `A`
   - **Alias:** Toggle ON ✅
   - **Route traffic to:** Application Load Balancer → your region → select your ALB
   - **Evaluate target health:** Yes
3. Click **Create Records**

### Step 2: Create CNAME Record (DNS → DNS)

1. **Create Record:**
   - **Record name:** `www`
   - **Record type:** `CNAME`
   - **Value:** `app.yourdomain.com`
   - **TTL:** 300
2. Click **Create Records**

### Step 3: Verify All DNS Records

```bash
# A Record (IP to DNS)
dig server1.yourdomain.com A +short
# → 54.230.10.42

# ALIAS Record (DNS to ALB)
dig app.yourdomain.com A +short
# → 10.0.1.x, 10.0.2.x (ALB IPs — these change!)

# CNAME Record (DNS to DNS)
dig www.yourdomain.com CNAME +short
# → app.yourdomain.com

# Now visit all three in the browser!
open http://server1.yourdomain.com    # Always goes to Instance 1
open http://app.yourdomain.com         # Load balanced! Instance ID changes
open http://www.yourdomain.com         # Same as app (via CNAME → ALIAS → ALB)
```

> [!IMPORTANT]
> **The key comparison for students:**
> - `server1.yourdomain.com` → A Record → Static IP → Always same server
> - `app.yourdomain.com` → ALIAS → ALB → Load balanced → Different servers each time
> - `www.yourdomain.com` → CNAME → points to `app.yourdomain.com` → Same load balancing

---

## Part 6: Terraform Automated Path

If you prefer to deploy everything with one command:

```bash
cd terraform/ec2

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
key_pair_name = "your-key-pair-name"
domain_name   = "yourdomain.com"    # Leave "" to skip DNS
aws_region    = "us-east-1"
EOF

# Deploy
terraform init
terraform plan
terraform apply

# After Terraform completes, deploy the app files:
IP1=$(terraform output -raw ec2_instance_1_public_ip)
IP2=$(terraform output -raw ec2_instance_2_public_ip)
./deploy_to_ec2.sh ~/.ssh/your-key.pem $IP1 $IP2

# See the lab instructions
terraform output lab_instructions
```

---

## Cleanup — DESTROY EVERYTHING!

> [!CAUTION]
> **Run this after every lab session!** ALB costs ~$16/month even when idle.

### Terraform:
```bash
cd terraform/ec2
terraform destroy -auto-approve
```

### Manual:
1. Delete Route 53 records (A, ALIAS, CNAME)
2. Delete ALB
3. Delete Target Group
4. Terminate both EC2 instances
5. Delete AMI + associated snapshot
6. Delete Security Groups
7. Delete VPC (if you created one)
