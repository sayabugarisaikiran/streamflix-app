# CloudWatch → Auto Scaling → Load Balancer — Unified Teaching Script

> **For the trainer:** Word-for-word classroom script with ONE continuous hands-on demo that progressively builds from a single EC2 instance to a fully auto-scaling, load-balanced, monitored system. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~5 hour session with two breaks.

> **Philosophy:** Students start with ONE server and personally watch it evolve — first they MONITOR it, then they make it SCALE, then they BALANCE traffic across it. Same app, same instance, the whole way through.

---

# PRE-CLASS SETUP (Instructor Only — Do This 30 Minutes Before Class)

### What You Need Ready

| Item | Details |
|------|---------|
| **AWS Account** | With admin access, in `us-east-1` (or any region with 3+ AZs) |
| **VPC** | Default VPC is fine, or a custom VPC with 2+ public subnets in different AZs |
| **Key Pair** | An EC2 key pair (e.g., `my-class-key`) already created |
| **Your IP** | Know your public IP for SSH security group rules |
| **Email** | A real email inbox open for SNS confirmations |
| **Terminal** | A terminal visible to students (large font, dark theme) |
| **Browser tabs** | Pre-open: EC2 Console, CloudWatch Console, browser tab for testing |

### The Demo App

We'll use one simple Nginx page that shows the hostname/instance ID. Students will visually see which instance is serving their request. This is the single thread throughout the entire class.

```
PROGRESSION:
1 EC2 instance → Monitor it (CloudWatch)
                → Create AMI from it
                → Build Auto Scaling Group from AMI
                → Attach Load Balancer
                → Watch it all work together
```

---

# SECTION A: CLOUDWATCH — MONITORING YOUR FIRST SERVER

## Part 1: Why Monitoring Matters (10 minutes)

### 🗣️ Opening Hook

*"Raise your hand if you've ever had an app crash and you didn't know WHY."*

*(Wait for hands)*

*"Now, imagine this. It's 2 AM. Your phone buzzes. Your manager texts: 'Website is down. Customers are tweeting about it. Fix it NOW.' You SSH into the server. CPU looks normal. Memory seems fine. Disk... wait, the disk is 100% full. A log file grew to 50 GB overnight. The app couldn't write temp files, so it crashed."*

*"That whole investigation took 45 minutes. 45 minutes of downtime. How much revenue did you lose?"*

*"Now here's the alternative: You set up CloudWatch monitoring. At 1:50 AM — TEN minutes BEFORE the crash — CloudWatch sent you an alert: 'Disk usage on web-server-1 exceeded 90%.' You cleaned up the logs in 2 minutes. The app never went down. You slept through the night."*

*"THAT is the difference between monitoring and not monitoring. And in AWS, the monitoring tool is CloudWatch."*

### 🗣️ What is CloudWatch? (The Control Room Analogy)

*"Think of CloudWatch as the CONTROL ROOM of your AWS infrastructure."*

```
Imagine a hospital:
  📊 Heart Monitor     = CloudWatch Metrics  (CPU, memory, requests — numbers over time)
  🔔 Emergency Alarm   = CloudWatch Alarms   ("Alert when heart rate > 120 bpm")
  📋 Patient Chart     = CloudWatch Logs     (text records — what happened and when)
  📺 Nurse Station     = CloudWatch Dashboards (all monitors on one screen)
  ⚡ Auto-Defibrillator = CloudWatch Events   ("IF heart stops → shock automatically")
```

*"CloudWatch does five things — and you need to know all five:"*

| Component | Hospital Analogy | What It Does |
|-----------|-----------------|--------------|
| **Metrics** | Heart rate monitor | Numbers over time — CPU %, network bytes, request counts |
| **Alarms** | Emergency alarm on the monitor | "When CPU > 80% for 5 minutes, ALERT ME" |
| **Logs** | Patient chart / notes | Text output from your apps, system logs |
| **Dashboards** | Nurse station with all monitors | Visual graphs — your "single pane of glass" |
| **Events** (EventBridge) | Auto-defibrillator / automatic response | "When X happens, do Y automatically" |

### ❓ Ask Students:

*"Quick question — which of these five is the most IMPORTANT for a DevOps engineer? Metrics? Alarms? Logs?"*

*(Let them discuss for 30 seconds)*

*"Trick question — ALARMS are the most important. Metrics tell you what happened. Logs tell you why. But ALARMS tell you WHEN to care. Without alarms, you're just staring at graphs hoping to notice a problem. Alarms are proactive — they come to YOU."*

---

## Part 2: Metrics — The Heartbeat of Your Server (15 minutes)

### 🗣️ What is a Metric?

*"A metric is a NUMBER measured at regular intervals. That's it. A number, over time."*

```
Metric: CPUUtilization
Instance: i-0abc123def456
Time: 10:00 AM → 12%     (light load)
Time: 10:05 AM → 15%     (still fine)
Time: 10:10 AM → 35%     (getting warm)
Time: 10:15 AM → 78%     (something happening!)
Time: 10:20 AM → 95%     (🔥 ON FIRE!)
Time: 10:25 AM → 22%     (calmed down)
```

*"That pattern tells a story. At 10:10, SOMETHING happened. Maybe a traffic spike, a deployment, a cron job. The metric alone doesn't tell you WHAT — but it tells you WHEN. Then you check the logs for the WHAT."*

### 🗣️ EC2 Metrics — What AWS Gives You for Free

*"AWS automatically sends these EC2 metrics to CloudWatch — you don't install anything:"*

| Metric | What It Measures | Red Flag |
|--------|-----------------|----------|
| `CPUUtilization` | How busy the processor is | > 80% sustained |
| `NetworkIn` / `NetworkOut` | Bytes transferred | Sudden spike = possible DDoS |
| `DiskReadOps` / `DiskWriteOps` | Storage operations | Hitting EBS IOPS limits |
| `StatusCheckFailed` | Is the instance alive? | 1 = something is broken |
| `StatusCheckFailed_Instance` | OS-level failure | 1 = reboot the instance |
| `StatusCheckFailed_System` | Hardware failure | 1 = AWS migrates your instance |

### 🗣️ The Critical Gap — Memory and Disk Space

> ⚠️ **THIS IS THE #1 GOTCHA IN AWS MONITORING**

*"Notice what's MISSING from that list? MEMORY. DISK SPACE. The two most common reasons servers crash — and AWS does NOT monitor them by default!"*

*"To get memory and disk space metrics, you need the CloudWatch Agent — a small program you install on your EC2 instance. We'll set that up later. For now, just remember: CPU and network are free. Memory and disk require the agent."*

### 🗣️ Resolution — How Often AWS Checks

| Type | Frequency | Cost | When to Use |
|------|-----------|------|-------------|
| **Standard** | Every 5 minutes | Free | Dev, testing |
| **Detailed** | Every 1 minute | $2.10/month per instance | **Production** (always use this) |
| **High-Resolution** | Every 1 second | Custom metric costs | Real-time trading, gaming |

*"Why does resolution matter? Let me show you."*

### ❓ Ask Students:

*"I set an alarm: CPU > 80% for 5 minutes. Standard monitoring (5-minute intervals). My CPU spikes to 99% for 4 minutes, then drops back. Does my alarm fire?"*

*(Let someone answer)*

*"Answer: MAYBE NOT. With 5-minute intervals, that spike might fall entirely between two data points and never get recorded! The first data point was at 10:00 (25%), the spike happened from 10:01-10:04 (99%), and the next data point was at 10:05 (30%). CloudWatch literally missed the whole event."*

*"That's why production ALWAYS uses Detailed Monitoring — 1-minute intervals. Don't be cheap with monitoring. The $2.10/month is nothing compared to the cost of missing a critical spike."*

---

## Part 3: Alarms — Your Automatic Alert System (15 minutes)

### 🗣️ What is an Alarm?

*"An alarm is simple: WATCH a metric. If it crosses a THRESHOLD for long enough, DO something."*

```
Alarm: "High-CPU-Alert"
  📊 Watch:   CPUUtilization on instance i-abc123
  📏 Threshold: Greater than 80%
  ⏱️ For:      3 consecutive 1-minute periods (3 minutes total)
  🎬 Action:   Send email via SNS
```

### 🗣️ The Three Alarm States

*"An alarm is always in one of three states — like a traffic light:"*

| State | Color | Meaning |
|-------|-------|---------|
| **OK** | 🟢 Green | Everything is normal. Metric is below threshold. |
| **ALARM** | 🔴 Red | Metric breached the threshold! Action triggered! |
| **INSUFFICIENT_DATA** | 🟡 Yellow | Not enough data yet (just created, or instance is stopped) |

```
Timeline of an alarm:

10:00 → OK 🟢     (CPU: 25%)
10:01 → OK 🟢     (CPU: 30%)
10:02 → OK 🟢     (CPU: 45%)
10:03 → OK 🟢     (CPU: 82% — breached! 1 of 3)
10:04 → OK 🟢     (CPU: 88% — breached! 2 of 3)
10:05 → ALARM 🔴  (CPU: 91% — breached! 3 of 3 → EMAIL SENT!)
10:06 → ALARM 🔴  (CPU: 75% — back below, but alarm stays until all 3 are clear)
10:07 → ALARM 🔴  (CPU: 40%)
10:08 → OK 🟢     (CPU: 35% — 3 consecutive below threshold → alarm clears)
```

### 🗣️ What Can An Alarm DO?

*"When an alarm fires, it doesn't just sit there. It takes ACTION:"*

| Action | What Happens | Example |
|--------|-------------|---------|
| **Send SNS notification** | Email, SMS, Slack | "CPU is at 90% on web-server-1!" |
| **Auto Scaling action** | Add/remove instances | "Launch 2 more servers" |
| **EC2 action** | Stop/terminate/reboot/recover | "Reboot the crashed instance" |

*"Today, we'll create an alarm that sends us an EMAIL. Later, we'll connect alarms to Auto Scaling — so the system HEALS ITSELF."*

### 🗣️ The Fire Alarm Analogy

*"Think of it like a building fire alarm:"*

```
Smoke detector (CloudWatch Metric)
  → Detects smoke level > threshold
    → Triggers fire alarm (CloudWatch Alarm)
      → Sprinklers turn on automatically (Auto Scaling adds servers)
      → Fire dept is called (SNS sends email)
      → Emergency lights guide people out (Dashboard shows the problem)
```

*"The BEST systems don't just alert — they RESPOND automatically. That's what we're building today."*

### ❓ Ask Students:

*"I have an alarm: CPU > 90% for 3 evaluation periods of 1 minute. My instance CPU spikes to 95% for exactly 2 minutes, then drops to 10%. Will my alarm fire?"*

*(Let them think)*

*"Answer: NO. It needs 3 consecutive breaches but only got 2. The alarm stays in OK state. This is actually a GOOD thing — it prevents false alarms from brief spikes (like during a deployment). But if you want to catch even brief spikes, use 1 evaluation period instead of 3."*

---

## Part 4: LIVE DEMO — Launch Your First Server & Monitor It (30 minutes)

### 🗣️ Bridge to Demo

*"Enough theory. Let me show you ALL of this live. We're going to launch one EC2 instance, watch its metrics, create an alarm, and then deliberately CRASH the CPU so the alarm fires."*

---

### 🖥️ Step 1: Launch the EC2 Instance

🗣️ *"Let's launch our demo app. It's a simple web page that shows the server's hostname and instance ID. Later, when we have multiple servers, you'll see DIFFERENT instance IDs — proving the load balancer is distributing traffic."*

1. **EC2 Console** → **Launch Instance**
   - **Name:** `web-app-demo`
   - **AMI:** Amazon Linux 2023
   - **Instance type:** `t2.micro` (free tier)
   - **Key pair:** Select your key pair
   - **Network settings:**
     - VPC: Default VPC (or your VPC)
     - Subnet: Pick any public subnet (note the AZ — e.g., `us-east-1a`)
     - **Auto-assign public IP:** Enable
   - **Security Group:** Create new:
     - Name: `web-app-sg`
     - Rule 1: **SSH (22)** → Source: My IP
     - Rule 2: **HTTP (80)** → Source: Anywhere (`0.0.0.0/0`)
   - **Advanced details** → **User Data:**

```bash
#!/bin/bash
yum update -y
yum install -y nginx stress

# Get instance metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Create the demo web page
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello from $INSTANCE_ID</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
      color: #e0e0e0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .container {
      text-align: center;
      padding: 40px;
    }
    h1 {
      font-size: 52px;
      margin-bottom: 10px;
      background: linear-gradient(90deg, #00d2ff, #3a7bd5);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle {
      font-size: 18px;
      color: #aaa;
      margin-bottom: 40px;
    }
    .card {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 16px;
      padding: 20px 30px;
      margin: 12px auto;
      max-width: 500px;
      backdrop-filter: blur(10px);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .card .label {
      color: #888;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .card .value {
      font-size: 18px;
      font-weight: 600;
      color: #00d2ff;
      font-family: 'Courier New', monospace;
    }
    .hostname {
      font-size: 22px;
      color: #3a7bd5;
      font-family: 'Courier New', monospace;
      background: rgba(58, 123, 213, 0.1);
      border: 1px solid rgba(58, 123, 213, 0.3);
      padding: 10px 20px;
      border-radius: 8px;
      display: inline-block;
      margin-bottom: 30px;
    }
    .footer {
      margin-top: 40px;
      font-size: 13px;
      color: #555;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>👋 Hello from EC2!</h1>
    <p class="subtitle">This page is served by a real AWS instance</p>
    <div class="hostname">$(hostname)</div>
    <div class="card">
      <span class="label">Instance ID</span>
      <span class="value">$INSTANCE_ID</span>
    </div>
    <div class="card">
      <span class="label">Availability Zone</span>
      <span class="value">$AZ</span>
    </div>
    <div class="card">
      <span class="label">Private IP</span>
      <span class="value">$PRIVATE_IP</span>
    </div>
    <div class="card">
      <span class="label">Server Time</span>
      <span class="value">$(date '+%Y-%m-%d %H:%M:%S')</span>
    </div>
    <p class="footer">Refresh this page when behind a Load Balancer → you'll see different Instance IDs!</p>
  </div>
</body>
</html>
EOF

# Create health check endpoint
cat > /usr/share/nginx/html/health <<EOF
{"status":"healthy","instance":"$INSTANCE_ID","az":"$AZ"}
EOF

# Create /app1 page
mkdir -p /usr/share/nginx/html/app1
cat > /usr/share/nginx/html/app1/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>App 1</title>
<style>
  body { font-family: Arial; text-align: center; padding: 60px; background: #1b4332; color: #d8f3dc; }
  h1 { font-size: 48px; color: #95d5b2; }
  .badge { background: #2d6a4f; padding: 15px 30px; border-radius: 12px; display: inline-block; margin: 10px; font-size: 18px; }
</style>
</head>
<body>
  <h1>🟢 App 1 — Catalog Service</h1>
  <div class="badge">Instance: $INSTANCE_ID</div>
  <div class="badge">AZ: $AZ</div>
  <p style="margin-top:30px; color:#52b788">This is the CATALOG microservice routed via /app1</p>
</body>
</html>
EOF

# Create /app2 page
mkdir -p /usr/share/nginx/html/app2
cat > /usr/share/nginx/html/app2/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>App 2</title>
<style>
  body { font-family: Arial; text-align: center; padding: 60px; background: #1a1423; color: #e2d1f9; }
  h1 { font-size: 48px; color: #c77dff; }
  .badge { background: #3c096c; padding: 15px 30px; border-radius: 12px; display: inline-block; margin: 10px; font-size: 18px; }
</style>
</head>
<body>
  <h1>🟣 App 2 — Order Service</h1>
  <div class="badge">Instance: $INSTANCE_ID</div>
  <div class="badge">AZ: $AZ</div>
  <p style="margin-top:30px; color:#e0aaff">This is the ORDER microservice routed via /app2</p>
</body>
</html>
EOF

systemctl enable nginx
systemctl start nginx
```

2. **Launch instance**

🗣️ *"While this launches — about 1-2 minutes — let me explain what that User Data script does. It installs Nginx (a web server), installs the `stress` tool (we'll need it to fake a CPU spike), and creates a custom web page that shows the server's Instance ID and Availability Zone. It also creates two microservice pages at `/app1` and `/app2` — we'll use those for path-based routing later."*

### 🖥️ Step 2: Verify the Web App

```bash
# Get the public IP from the EC2 console
curl http://<PUBLIC-IP>/
```

🗣️ *"Open this in your browser. You should see a page that says 'Hello from EC2!' with the Instance ID, AZ, and Private IP. THIS is the app we'll monitor, scale, and load-balance throughout this entire class."*

🖥️ **Show the page in the browser. Point out the Instance ID.**

🗣️ *"Remember this Instance ID. When we have multiple instances behind a load balancer, you'll refresh the page and see a DIFFERENT Instance ID each time. That's how you'll KNOW the load balancer is working."*

### 🖥️ Step 3: Enable Detailed Monitoring

1. **EC2 Console** → Select `web-app-demo`
2. **Actions** → **Monitor and troubleshoot** → **Manage detailed monitoring**
3. Check **Enable** → **Save**

🗣️ *"We just switched from 5-minute to 1-minute monitoring. Now we'll see CPU changes within 60 seconds instead of waiting 5 minutes. Essential for the demos we're about to do."*

### 🖥️ Step 4: View Your CPU Metrics in CloudWatch

1. **CloudWatch Console** → **Metrics** → **All metrics**
2. Under **AWS namespaces** → Click **EC2**
3. Click **Per-Instance Metrics**
4. Search for your instance ID → Check **CPUUtilization**
5. The graph appears — a flat line around 1-5%

🗣️ *"THIS is your CPU usage over time. Right now it's a flat line near zero because nobody is using the server. In a few minutes, we're going to make this line SPIKE to 100%."*

🖥️ **Change the period to 1 minute. Change the time range to 1 hour.**

### ❓ Ask Students:

*"What does a FLAT LINE at 0% tell you? Is that good or bad?"*

*(Let someone answer)*

*"It's good — it means the server is idle. But a flat line at 99%? That means the server is MAXED OUT and probably struggling. We want something in the middle — maybe 30-50% — which means the server is doing useful work with room to spare."*

---

### 🖥️ Step 5: Create Your First Alarm

🗣️ *"Now let's set up the alarm. We're telling CloudWatch: 'If CPU goes above 70% for 2 minutes, send me an email.'"*

1. **CloudWatch** → **Alarms** → **All alarms** → **Create alarm**
2. **Select metric:**
   - Click **Select metric**
   - **EC2** → **Per-Instance Metrics**
   - Find `CPUUtilization` for your instance → Select it → **Select metric**
3. **Metric configuration:**
   - Statistic: **Average**
   - Period: **1 minute**
4. **Conditions:**
   - Threshold type: **Static**
   - Whenever CPUUtilization is: **Greater than** `70`
5. **Actions — In Alarm state:**
   - **Create new SNS topic**
   - Topic name: `cpu-alerts`
   - Email: `your-real-email@gmail.com`
   - **Create topic**
6. **Name:** `High-CPU-Demo-Alarm`
7. **Create alarm**

🗣️ *"CRITICAL STEP: Check your email RIGHT NOW and CONFIRM the SNS subscription. You'll see an email from AWS with a confirmation link. If you don't confirm, you won't get alert emails."*

🖥️ **Show confirming the email subscription.**

> ⏳ **Note to instructor:** The alarm will start in `INSUFFICIENT_DATA` state (yellow). It takes 1-2 minutes to get its first data point and switch to `OK` (green). Show students this transition.

---

### 🖥️ Step 6: Spike the CPU and Watch the Alarm Fire! 🔥

🗣️ *"NOW for the fun part. I'm going to SSH into this server and DELIBERATELY stress the CPU to 100%. Watch what happens in CloudWatch."*

**Open TWO windows side by side:**
- **Left:** CloudWatch Alarms page (showing `High-CPU-Demo-Alarm`)
- **Right:** Terminal

```bash
# SSH into the instance
ssh -i my-class-key.pem ec2-user@<PUBLIC-IP>

# Stress the CPU for 5 minutes (all cores at 100%)
stress --cpu 4 --timeout 300
```

🗣️ *"The `stress` command is eating all the CPU. Now let's watch CloudWatch."*

🖥️ **Switch to the CloudWatch Alarms page. Hit refresh every 30 seconds.**

**What students should observe (narrate this live):**

```
0:00  — stress starts, alarm is OK 🟢
0:30  — First data point arrives showing ~95% CPU
1:00  — Alarm still OK (needs 2 consecutive breaches)
1:30  — Second data point at ~98%
2:00  — ALARM 🔴 fires! State changes to "In alarm"
2:15  — Check your email → SNS notification arrives!
```

🗣️ *"Look at that! The alarm FIRED. Your email just got a notification. In production, this email could go to Slack, PagerDuty, or even trigger an Auto Scaling action — meaning AWS would automatically launch MORE servers. We'll set that up in the next section."*

🖥️ **Show the alarm in ALARM state. Show the email notification. Show the CPU graph spiking.**

### 🖥️ Step 7: Stop the Stress and Watch Recovery

```bash
# Stress will auto-stop after 5 minutes (--timeout 300)
# Or Ctrl+C to stop early
```

🗣️ *"I stopped the stress. Now watch the alarm..."*

**What students should observe:**

```
5:00  — stress stops, CPU drops to ~2%
6:00  — CloudWatch sees low CPU
7:00  — Alarm transitions: ALARM 🔴 → OK 🟢
```

🗣️ *"And the alarm is back to OK! Green. This is the full lifecycle: OK → ALARM → OK. In production, the ALARM state would have triggered Auto Scaling to add servers. The OK state would trigger scaling BACK down. Fully automatic."*

### ❓ Ask Students:

*"In a real production system, who's checking these alarms at 3 AM?"*

*(Let them answer)*

*"NOBODY. That's the whole point. Auto Scaling reacts to the alarm and fixes the problem. You wake up, check the dashboard, and see it handled itself. That's what we're building next."*

---

### 🖥️ Step 8: Quick Dashboard Demo (5 minutes)

🗣️ *"Before we move on, let me show you dashboards — your single screen for all metrics."*

1. **CloudWatch** → **Dashboards** → **Create dashboard**
2. Name: `Demo-Dashboard`
3. Add a **Line** widget → Select EC2 `CPUUtilization` for your instance
4. Add a **Number** widget → Same metric → Statistic: Maximum
5. **Save**

🗣️ *"This is what an operations team watches all day. In production, you'd have CPU, memory, disk, request counts, error rates — all on one screen. For now, we have one metric from one server. By the end of class, we'll have metrics from MULTIPLE auto-created servers flowing through a load balancer."*

---

## ☕ BREAK — 10 Minutes

🗣️ *"Take 10 minutes. When we come back, we're going to teach this server to CLONE ITSELF when it gets overwhelmed."*

---

# SECTION B: AUTO SCALING — YOUR SERVER LEARNS TO CLONE ITSELF

## Part 5: Why Auto Scaling? (10 minutes)

### 🗣️ The Problem — A Story

*"You own a pizza shop. On a normal day, you have 2 chefs and they handle all orders easily. Then one day, a food blogger posts about your pizza. Suddenly, you have 200 orders in an hour instead of 20."*

*"Your 2 chefs can't keep up. Orders stack up. Customers wait 90 minutes. They leave 1-star reviews. You lose business."*

*"What do you do? Option A: Buy a BIGGER oven? That's vertical scaling — there's a limit to how big an oven can get, and you can't resize it while cooking."*

*"Option B: Hire MORE chefs, and when the rush is over, send them home? THAT'S auto scaling."*

```
Normal day:          🧑‍🍳🧑‍🍳          → 2 chefs, 20 orders/hr ✅
Viral blog post:     🧑‍🍳🧑‍🍳          → 2 chefs, 200 orders/hr ❌ OVERLOADED
Auto Scaling kicks in: 🧑‍🍳🧑‍🍳🧑‍🍳🧑‍🍳🧑‍🍳🧑‍🍳  → 6 chefs, 200 orders/hr ✅
Rush ends:           🧑‍🍳🧑‍🍳          → Back to 2, stop paying the extras ✅
```

*"Auto Scaling does exactly this with your EC2 instances. When CPU goes up, it LAUNCHES more servers. When CPU drops, it TERMINATES them. You only pay for what you need, when you need it."*

### 🗣️ The Timeline in AWS

```
9:00 AM  — 500 users   — 2 instances — CPU at 30% → Normal ✅
9:10 AM  — 50,000 users — 2 instances — CPU spikes to 95%! 🔥
9:11 AM  — CloudWatch alarm fires → "CPU > 70% for 2 minutes!"
           → Auto Scaling receives the alarm
           → ASG launches 4 new instances
9:15 AM  — 6 instances running — CPU drops to 45% ✅
11:00 AM — Traffic drops — CPU at 15%
           → CloudWatch says "CPU < 30% for 10 minutes"
           → Auto Scaling terminates 4 instances
11:05 AM — Back to 2 instances → Right-sized, cost-efficient ✅
```

*"You didn't touch ANYTHING. You were sleeping. The system monitored itself (CloudWatch), detected the problem (Alarm), and fixed it (Auto Scaling). THAT is the power of these three services working together."*

---

## Part 6: Auto Scaling Concepts (15 minutes)

### 🗣️ Three Numbers You MUST Know

*"Every Auto Scaling Group has three critical numbers:"*

| Setting | Analogy | What It Means |
|---------|---------|---------------|
| **Minimum** | "We always need at least 2 chefs" | Floor — ASG will NEVER go below this |
| **Maximum** | "We can afford at most 10 chefs" | Ceiling — ASG will NEVER exceed this (cost safety!) |
| **Desired** | "Right now we need 4 chefs" | Current target — what ASG aims for RIGHT NOW |

```
                Min          Desired        Max
                 │              │             │
                 ▼              ▼             ▼
Instances: ──2───────────4──────────────10──────
                 │              │             │
           "Never fewer   "What we     "Never more
            than this"    have now"     than this"
```

*"MAXIMUM is your financial safety net. Without it, a viral spike could launch 100 servers and your AWS bill could be thousands of dollars. ALWAYS set a maximum."*

### ❓ Ask Students:

*"My ASG has Min=2, Max=10, Desired=6. Traffic drops to almost zero. How many instances will ASG keep running?"*

*(Let them answer)*

*"Answer: 2. It will scale down to the MINIMUM but never below it. Even at 3 AM with zero traffic, you'll have 2 instances running for reliability."*

### 🗣️ Launch Template — The Clone Blueprint

*"When Auto Scaling needs to create a new server, how does it know WHAT to create? It uses a Launch Template — a blueprint that says exactly how to build the instance."*

| Template Setting | What It Specifies |
|-----------------|-------------------|
| **AMI** | Which image to use (your custom AMI with your app installed) |
| **Instance type** | t2.micro, t3.medium, etc. |
| **Key pair** | SSH key |
| **Security Group** | Firewall rules |
| **User Data** | Bootstrap script (install software, start services) |
| **IAM Role** | Permissions for the instance |

*"Think of it like a cookie cutter. Every cookie (instance) comes out exactly the same shape. The Launch Template IS the cookie cutter."*

### 🗣️ Scaling Policies — WHEN to Scale

*"How does ASG know WHEN to add or remove servers? Scaling policies. The simplest and smartest one is Target Tracking:"*

**Target Tracking (Like a Thermostat)**

```
"Keep average CPU at 50%"

CPU at 30% → "Too cold" → Remove an instance
CPU at 50% → "Perfect"  → Do nothing
CPU at 70% → "Too hot"  → Add an instance
```

*"It's exactly like a thermostat. You set 72°F. If the room gets hot, the AC turns on. If it gets cold, the AC turns off. You don't manage the AC — you just set the target."*

| Other Policy Types | How They Work | When to Use |
|-------------------|---------------|-------------|
| **Step Scaling** | Different actions at different levels (CPU 50-70% → +1, CPU 70-90% → +3, CPU >90% → +5) | Fine-grained control |
| **Scheduled** | "At 9 AM, set desired to 10. At 6 PM, set to 3" | Predictable traffic patterns |
| **Simple** | One alarm → one action. Wait for cooldown. | **Don't use** (legacy) |

*"Start with Target Tracking. It handles 90% of use cases. Add Scheduled if you know when traffic changes (e.g., office hours)."*

### 🗣️ Important Delays to Know

| Delay | Duration | Why |
|-------|----------|-----|
| **CloudWatch alarm evaluation** | 1-5 minutes | Takes a few data points to confirm threshold |
| **ASG decision** | ~30 seconds | ASG processes the alarm and decides action |
| **Instance launch** | 1-3 minutes | EC2 boots, runs user data, starts services |
| **Health check grace period** | Configurable (e.g., 120s) | Wait for app to start before checking health |
| **Registration with LB** | 30-60 seconds | ALB needs to health-check before sending traffic |
| **Total time to serve traffic** | **3-8 minutes** | From alarm to serving requests |

*"This is critical. Auto Scaling is NOT instant. It takes 3-8 minutes from 'CPU is high' to 'new instances are serving traffic.' That's why you set the CPU target at 50-60%, not 90%. You need HEADROOM while new instances are launching."*

---

## Part 7: LIVE DEMO — Create AMI and Auto Scaling Group (35 minutes)

### 🗣️ Bridge to Demo

*"Now we're going to take that single web server we launched earlier and make it SCALABLE. Step 1: Create an image (AMI) of it — a snapshot. Step 2: Create a Launch Template using that image. Step 3: Create an Auto Scaling Group. Step 4: Stress it and watch new instances appear automatically."*

---

### 🖥️ Step 1: Create an AMI From Your Running Instance

🗣️ *"First, we take a snapshot of our server — an Amazon Machine Image (AMI). This captures the OS, Nginx, our demo app, the stress tool — everything. When Auto Scaling needs a new server, it'll use this snapshot to create an exact clone."*

1. **EC2 Console** → Select `web-app-demo`
2. **Actions** → **Image and templates** → **Create image**
   - Image name: `web-app-demo-ami`
   - Description: `Demo web app with Nginx and stress tool`
   - **No reboot:** ✅ Check this (keeps the instance running)
3. **Create image**

🗣️ *"This takes about 2-3 minutes. It's literally copying the entire disk. While it's creating, let me explain what happens next."*

🖥️ **Show the AMI creation in progress:** **EC2** → **AMIs** → Status: `pending`

> ⏳ **Wait for AMI status to change to `available` before proceeding.**

🗣️ *"AMI is ready! Status: available. Now any Auto Scaling Group can use this AMI to create identical copies of our server."*

---

### 🖥️ Step 2: Create a Launch Template

🗣️ *"The Launch Template is the blueprint. It says: 'When Auto Scaling needs a new server, use THIS AMI, THIS instance type, THIS security group.'"*

1. **EC2** → **Launch Templates** → **Create launch template**
   - **Name:** `web-app-lt`
   - **Description:** `Launch template for web app demo`
   - **Application and OS Images:** → **My AMIs** → Select `web-app-demo-ami`
   - **Instance type:** `t2.micro`
   - **Key pair:** Select your key
   - **Security Group:** Select `web-app-sg` (the one we created earlier with HTTP and SSH)
   - **Advanced details** → **User Data:**

```bash
#!/bin/bash
# Re-generate the page with THIS instance's metadata (since AMI has the old instance's ID baked in)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello from $INSTANCE_ID</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
      color: #e0e0e0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .container { text-align: center; padding: 40px; }
    h1 {
      font-size: 52px;
      margin-bottom: 10px;
      background: linear-gradient(90deg, #00d2ff, #3a7bd5);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle { font-size: 18px; color: #aaa; margin-bottom: 40px; }
    .card {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px;
      padding: 20px 30px;
      margin: 12px auto;
      max-width: 500px;
      backdrop-filter: blur(10px);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .card .label { color: #888; font-size: 14px; text-transform: uppercase; letter-spacing: 1px; }
    .card .value { font-size: 18px; font-weight: 600; color: #00d2ff; font-family: 'Courier New', monospace; }
    .hostname {
      font-size: 22px; color: #3a7bd5; font-family: 'Courier New', monospace;
      background: rgba(58,123,213,0.1); border: 1px solid rgba(58,123,213,0.3);
      padding: 10px 20px; border-radius: 8px; display: inline-block; margin-bottom: 30px;
    }
    .badge-asg {
      background: linear-gradient(135deg, #e94560, #c23616);
      padding: 5px 15px; border-radius: 20px; font-size: 12px; display: inline-block;
      margin-bottom: 20px; letter-spacing: 1px;
    }
    .footer { margin-top: 40px; font-size: 13px; color: #555; }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge-asg">🔄 AUTO SCALED INSTANCE</div>
    <h1>👋 Hello from EC2!</h1>
    <p class="subtitle">This instance was automatically created by Auto Scaling</p>
    <div class="hostname">\$(hostname)</div>
    <div class="card">
      <span class="label">Instance ID</span>
      <span class="value">$INSTANCE_ID</span>
    </div>
    <div class="card">
      <span class="label">Availability Zone</span>
      <span class="value">$AZ</span>
    </div>
    <div class="card">
      <span class="label">Private IP</span>
      <span class="value">$PRIVATE_IP</span>
    </div>
    <div class="card">
      <span class="label">Server Time</span>
      <span class="value">\$(date '+%Y-%m-%d %H:%M:%S')</span>
    </div>
    <p class="footer">🔄 This instance was created by ASG using Launch Template web-app-lt</p>
  </div>
</body>
</html>
EOF

# Recreate health endpoint
cat > /usr/share/nginx/html/health <<EOF
{"status":"healthy","instance":"$INSTANCE_ID","az":"$AZ"}
EOF

# Recreate app1 and app2
mkdir -p /usr/share/nginx/html/app1
cat > /usr/share/nginx/html/app1/index.html <<EOF
<!DOCTYPE html>
<html><head><title>App 1</title>
<style>body{font-family:Arial;text-align:center;padding:60px;background:#1b4332;color:#d8f3dc;}
h1{font-size:48px;color:#95d5b2;}.badge{background:#2d6a4f;padding:15px 30px;border-radius:12px;display:inline-block;margin:10px;font-size:18px;}</style>
</head><body>
<h1>🟢 App 1 — Catalog Service</h1>
<div class="badge">Instance: $INSTANCE_ID</div>
<div class="badge">AZ: $AZ</div>
<p style="margin-top:30px;color:#52b788">Routed via /app1</p>
</body></html>
EOF

mkdir -p /usr/share/nginx/html/app2
cat > /usr/share/nginx/html/app2/index.html <<EOF
<!DOCTYPE html>
<html><head><title>App 2</title>
<style>body{font-family:Arial;text-align:center;padding:60px;background:#1a1423;color:#e2d1f9;}
h1{font-size:48px;color:#c77dff;}.badge{background:#3c096c;padding:15px 30px;border-radius:12px;display:inline-block;margin:10px;font-size:18px;}</style>
</head><body>
<h1>🟣 App 2 — Order Service</h1>
<div class="badge">Instance: $INSTANCE_ID</div>
<div class="badge">AZ: $AZ</div>
<p style="margin-top:30px;color:#e0aaff">Routed via /app2</p>
</body></html>
EOF

systemctl restart nginx
```

2. **Create launch template**

🗣️ *"Notice the User Data script REGENERATES the web page with the NEW instance's metadata. Why? Because the AMI has the OLD instance's ID baked into the HTML. When Auto Scaling clones the server, the new instance needs its OWN Instance ID on the page — otherwise every clone would show the original server's ID, and we couldn't prove load balancing is working."*

---

### 🖥️ Step 3: Create the Auto Scaling Group

🗣️ *"Now we create the Auto Scaling Group itself. This is where we say: 'Keep 2 servers running at all times. If CPU goes above 50%, add more. Maximum 6.'"*

1. **EC2** → **Auto Scaling Groups** → **Create Auto Scaling group**

**Page 1 — Choose launch template:**
   - Name: `web-app-asg`
   - Launch template: `web-app-lt` (Version: Latest)
   - **Next**

**Page 2 — Choose instance launch options:**
   - VPC: Your VPC
   - Availability Zones and subnets: Select **at least 2** public subnets in different AZs (e.g., `us-east-1a` and `us-east-1b`)
   - **Next**

**Page 3 — Configure advanced options:**
   - Load balancing: **No load balancer** ← We'll add this later!
   - Health checks: EC2 (for now, we'll switch to ELB later)
   - **Next**

**Page 4 — Configure group size and scaling:**
   - **Desired capacity:** `2`
   - **Minimum capacity:** `2`
   - **Maximum capacity:** `6`
   - **Scaling policies:** Select **Target tracking scaling policy**
     - Policy name: `cpu-target-50`
     - Metric type: **Average CPU utilization**
     - Target value: `50`
     - Instance warmup: `120` seconds
   - **Next**

**Page 5 — Add notifications (optional):**
   - **Add notification**
   - SNS topic: `cpu-alerts` (the one we created earlier)
   - Event types: ✅ Launch, ✅ Terminate, ✅ Fail to launch
   - **Next**

**Page 6 — Add tags:**
   - Key: `Name`, Value: `web-app-asg-instance`
   - **Next**

**Page 7 — Review → Create Auto Scaling group**

🗣️ *"ASG is created! It will now launch 2 instances to meet the desired capacity. Watch them appear..."*

### 🖥️ Step 4: Watch Instances Launch

🗣️ *"Go to EC2 → Instances. You should see 2 new instances launching — they'll be named `web-app-asg-instance` from our tag."*

🖥️ **Show the two new instances appearing in EC2 console.** Wait for them to reach `running` state.

```bash
# Verify from CLI
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names web-app-asg \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].{Id:InstanceId,State:LifecycleState,AZ:AvailabilityZone}}'
```

🗣️ *"See? 2 instances, in InService state, spread across different AZs. ASG automatically distributed them across AZs for high availability."*

```bash
# Test that each ASG instance serves the web page
curl http://<ASG-INSTANCE-1-PUBLIC-IP>/
curl http://<ASG-INSTANCE-2-PUBLIC-IP>/
```

🗣️ *"Both clones are working! They show 'AUTO SCALED INSTANCE' and different Instance IDs. These are exact copies of our original server, created automatically."*

> 💡 **Instructor note:** You can now TERMINATE `web-app-demo` (the original instance) if you want to keep things clean. The ASG instances are independent.

---

### 🖥️ Step 5: Stress Test — Watch Auto Scaling Create New Instances! 🔥

🗣️ *"This is the moment of truth. I'm going to stress BOTH ASG instances and watch what happens. If our setup is correct, CloudWatch will detect the high CPU, the scaling policy will trigger, and Auto Scaling will launch new instances — ALL automatically."*

**Open THREE windows:**
- **Window 1:** CloudWatch Alarm page
- **Window 2:** EC2 Instances list
- **Window 3:** Terminal (SSH)

```bash
# SSH into ASG instance 1
ssh -i my-class-key.pem ec2-user@<ASG-INSTANCE-1-PUBLIC-IP>
stress --cpu 4 --timeout 600

# In a second terminal, SSH into ASG instance 2
ssh -i my-class-key.pem ec2-user@<ASG-INSTANCE-2-PUBLIC-IP>
stress --cpu 4 --timeout 600
```

🗣️ *"Both instances are now at 100% CPU. Average CPU across the ASG is ~100%. Our target is 50%. CloudWatch will detect this and the Auto Scaling target tracking policy will react."*

**Narrate this timeline as it happens (keep refreshing the console):**

```
0:00   — Stress starts on both instances
         CPU CloudWatch: ~100%
         ASG Desired: 2 | Running: 2

~1:30  — CloudWatch alarms (auto-created by target tracking) fire
         🟢→🔴 "TargetTracking-web-app-asg-AlarmHigh" enters ALARM

~2:00  — ASG increases desired capacity: 2 → 4
         Activity History shows: "Launching new EC2 instance"
         
~2:30  — 2 new instances appear in EC2 console (state: pending)

~4:00  — New instances reach "InService" state
         ASG Desired: 4 | Running: 4

~5:00  — Average CPU drops to ~50% (load distributed across 4 instances)
         → Target tracking is satisfied
```

🗣️ *"LOOK! Two new instances just appeared! Check the EC2 console — we went from 2 to 4 instances. AutoScaling detected the high CPU and automatically launched two more. We didn't touch anything."*

🖥️ **Show the Activity History tab in the ASG:** This shows a record of every scaling action.

🖥️ **Show CloudWatch metrics page:** CPU dropping from 100% to ~50% as new instances absorb load.

### 🖥️ Step 6: Stop the Stress — Watch Scale-In

```bash
# Ctrl+C on both SSH sessions to stop stress
# Or wait for --timeout 600 (10 minutes)
```

🗣️ *"Now that the stress is over, CPU drops near 0%. But ASG won't IMMEDIATELY remove instances — watch."*

**What happens next (narrate):**

```
6:00   — Stress stops, CPU drops to ~2%
         ASG Desired: 4 | Running: 4

~15:00 — Scale-in alarm fires (target tracking waits longer before scaling in!)
         "TargetTracking-web-app-asg-AlarmLow" enters ALARM

~16:00 — ASG decreases desired capacity: 4 → 2
         Activity History: "Terminating EC2 instance i-xxx"

~17:00 — 2 instances terminated
         ASG Desired: 2 | Running: 2 ← Back to normal!
```

🗣️ *"Scale-in takes longer than scale-out — about 15 minutes. This is BY DESIGN. AWS scales OUT aggressively (your users are suffering!) but scales IN conservatively (making sure the load really did drop, not just a brief dip). Smart."*

### ❓ Ask Students:

*"Why does scale-in take longer than scale-out?"*

*(Let them think)*

*"Because removing servers prematurely is WORSE than adding too many. If you remove a server too fast and traffic comes back, you're back to square one with overloaded servers and another 5-minute scale-out. Better to wait and be sure the traffic truly dropped."*

---

# ☕ BREAK — 10 Minutes

🗣️ *"Take 10 minutes. When we come back, we're going to add a LOAD BALANCER so traffic doesn't have to go to individual server IPs. One URL, traffic distributed automatically."*

---

# SECTION C: LOAD BALANCER — ONE DOOR, MANY SERVERS

## Part 8: Why Load Balancing? (10 minutes)

### 🗣️ The Problem We Just Created

*"We now have Auto Scaling. When traffic spikes, new servers appear. Great! But there's a problem..."*

*"How do your USERS know about the new servers? Right now, you're connecting directly to each EC2's public IP. If Auto Scaling launches 2 new servers, your users don't know their IPs. And when servers are terminated, their IPs disappear."*

```
Without Load Balancer:
  User → http://54.23.45.67/     (server 1 — hard-coded IP)
                                  What if this server is terminated?
                                  What about the other 3 servers? Users don't know about them!

With Load Balancer:
  User → http://my-alb-12345.us-east-1.elb.amazonaws.com/
         → Load Balancer distributes to all healthy servers
         → New servers auto-registered ✅
         → Dead servers auto-removed ✅
         → Users use ONE URL forever
```

### 🗣️ The Restaurant Analogy

*"Imagine a restaurant with many waiters but NO host at the entrance. Every customer walks in and randomly picks a waiter. One waiter has 20 tables, another has 2. Chaos."*

*"Now put a HOST at the entrance. The host seats each customer with the waiter who has the fewest tables. Everyone gets served quickly. THAT host is your Load Balancer."*

```
Customers arrive at the door
         │
         ▼
┌─────────────────┐
│   HOST/HOSTESS  │  ← Load Balancer (ONE fixed URL)
│  (routes guests) │
└────────┬────────┘
         │
   ┌─────┼──────────┐
   │     │          │
   ▼     ▼          ▼
  🧑‍🍳    🧑‍🍳        🧑‍🍳
Waiter  Waiter    Waiter     ← EC2 Instances
 (8)    (7)       (5)        (current tables)
         │
   Next customer → Waiter 3 (fewest tables)
```

### ❓ Ask Students:

*"If we have an Auto Scaling Group that creates and destroys instances dynamically, why CAN'T we just give users the instance IPs?"*

*(Let them answer)*

*"Three reasons: 1) IPs change every time an instance is created/terminated. 2) Users would need a different URL for each instance. 3) There's no automatic failover — if one server dies, the user sees an error. A Load Balancer solves ALL THREE problems with one stable URL."*

---

## Part 9: Types of Load Balancers (15 minutes)

### 🗣️ AWS Has Four Load Balancers

*"AWS offers four types. You'll use one 99% of the time (ALB), but you need to know all four for interviews and real-world decisions."*

| Type | Abbreviation | Layer | Protocol | One-Line Summary |
|------|-------------|-------|----------|-----------------|
| **Application Load Balancer** | ALB | Layer 7 (HTTP) | HTTP/HTTPS/gRPC | *The web app load balancer — can route by URL path, hostname, headers* |
| **Network Load Balancer** | NLB | Layer 4 (TCP) | TCP/UDP/TLS | *The speed demon — ultra-low latency, static IPs, for non-HTTP traffic* |
| **Gateway Load Balancer** | GWLB | Layer 3 (IP) | GENEVE | *The security inspector — for inline firewalls/IDS* |
| **Classic Load Balancer** | CLB | Layer 4/7 | TCP/HTTP | *⚠️ DEPRECATED — don't use for new projects* |

### 🗣️ ALB — The One You'll Use Most (with Analogy)

*"ALB is like a SMART receptionist at a doctor's office. You walk in and say 'I have a headache.' The receptionist reads your symptom (HTTP header), checks the URL path, and routes you to the RIGHT doctor."*

```
Patient: "I need /cardiology"    → Cardiology wing (Target Group 1)
Patient: "I need /dermatology"   → Dermatology wing (Target Group 2)
Patient: "I need /emergency"     → ER (Target Group 3)
Default: (just a checkup)        → General practitioner (Default Target Group)
```

*"That's PATH-BASED ROUTING. The ALB reads the URL and sends traffic to different sets of servers based on the path. We'll do this live in our demo."*

**What makes ALB special:**

| Feature | What It Means |
|---------|--------------|
| **Path-based routing** | `/api/*` → API servers, `/images/*` → image servers |
| **Host-based routing** | `api.example.com` → API servers, `admin.example.com` → admin servers |
| **SSL termination** | ALB handles HTTPS decryption so your servers don't have to |
| **Health checks** | ALB checks if each server is alive (e.g., hits `/health`) |
| **Auto-deregistration** | Dead servers automatically removed from rotation |
| **WAF integration** | Attach a Web Application Firewall for security |

### 🗣️ NLB — The Speed Demon (with Analogy)

*"NLB is like a HIGHWAY TOLL BOOTH. It doesn't read what's inside the car (HTTP content). It just counts vehicles (TCP packets) and directs them to lanes. Ultra-fast because it doesn't inspect anything."*

| When to Use NLB | Why |
|-----------------|-----|
| TCP/UDP protocols (not HTTP) | Gaming servers, database proxies, IoT |
| Need static IP addresses | Firewall whitelisting requires fixed IPs |
| Ultra-low latency (<1ms) | Financial trading, real-time bidding |
| Millions of connections per second | IoT with millions of devices |

### 🗣️ CLB — The Old One (with Analogy)

*"CLB is like a rotary phone — it still works, but nobody buys a new one. AWS launched it in 2009. It was their first load balancer. It can't do path-based routing, host-based routing, or most modern features."*

*"If you see a CLB in a company, it's legacy. Migrate it to ALB. For new projects, NEVER use CLB."*

### 🗣️ GWLB — The Security Guard (with Analogy)

*"GWLB is like an AIRPORT SECURITY SCANNER. ALL traffic passes through the scanner (firewall appliance) for inspection, then continues to the gate (your app). Your app doesn't even know the scanner exists."*

```
Internet → GWLB Endpoint → GWLB → 🔍 Firewall Appliance → GWLB → Your App
                                   (Palo Alto, Fortinet, etc.)
```

*"99% of you will never set this up. It's for banks, governments, and security-heavy organizations that need inline traffic inspection. Just know it exists."*

### 🗣️ ALB vs NLB — The Decision Flowchart

```
Is your traffic HTTP or HTTPS?
  ├── YES → Do you need path-based routing? → ALB
  ├── YES → Do you need WAF? → ALB
  └── NO (TCP/UDP) → NLB

Do you need a static IP?
  └── YES → NLB (or ALB + Global Accelerator)

Is latency under 1ms critical?
  └── YES → NLB

Default for web applications?
  └── ALB ✅
```

### ❓ Ask Students:

*"I have a microservices app: `/api/users` goes to User Service, `/api/orders` goes to Order Service, `/api/payments` goes to Payment Service. ALB or NLB?"*

*(Let them answer)*

*"ALB. You need path-based routing. NLB doesn't understand URLs — it only sees TCP packets."*

---

## Part 10: ALB Architecture Deep Dive (10 minutes)

### 🗣️ The Four Components of an ALB

*"An ALB has four components. Think of it as a company mail room:"*

```
┌────────────────────────────────────────────────────────────┐
│                  APPLICATION LOAD BALANCER                   │
│                                                             │
│  📬 LISTENER (Port 80: HTTP)                                │
│    │                                                        │
│    ├── 📋 Rule 1: IF path = /app1/*  → Forward to: app1-tg │
│    ├── 📋 Rule 2: IF path = /app2/*  → Forward to: app2-tg │
│    └── 📋 Default rule              → Forward to: main-tg  │
│                                                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼
    ┌───────────┐  ┌───────────┐  ┌───────────┐
    │ 🎯 app1-tg │  │ 🎯 app2-tg │  │ 🎯 main-tg │
    │  EC2-1    │  │  EC2-3    │  │  EC2-5    │
    │  EC2-2    │  │  EC2-4    │  │  EC2-6    │
    └───────────┘  └───────────┘  └───────────┘
```

| Component | Mail Room Analogy | What It Does |
|-----------|-------------------|--------------|
| **Listener** | The mailbox slot | "I accept mail on port 80 (HTTP) and port 443 (HTTPS)" |
| **Rules** | The sorting labels | "If the package says /api, send to the API team" |
| **Target Group** | A team's mail bin | Collection of servers that receive traffic |
| **Health Check** | Checking if someone is at their desk | "Ping each server every 10 sec — if no response, stop sending mail" |

### 🗣️ Health Checks — How ALB Knows Who's Alive

```
Every 10 seconds:
  ALB → GET /health → EC2-1 → 200 OK ✅ (healthy → send traffic)
  ALB → GET /health → EC2-2 → 200 OK ✅ (healthy → send traffic)
  ALB → GET /health → EC2-3 → timeout ❌ (unhealthy → STOP sending traffic!)
  ALB → GET /health → EC2-4 → 200 OK ✅ (healthy → send traffic)

EC2-3 is removed from rotation. Traffic goes to EC2-1, 2, and 4 only.
When EC2-3 recovers → ALB detects → adds it back automatically.
```

*"This is how ALB provides HIGH AVAILABILITY. If a server crashes, traffic instantly routes around it. No manual intervention."*

---

## Part 11: LIVE DEMO — Create ALB + Target Groups + Path-Based Routing (40 minutes)

### 🗣️ Bridge to Demo

*"We're going to create an Application Load Balancer, point it at our Auto Scaling Group, and then set up path-based routing so `/app1` goes to one target group and `/app2` goes to another. All live."*

---

### 🖥️ Step 1: Create the Main Target Group

🗣️ *"A Target Group is a collection of servers that receive traffic. Our ASG instances will be registered in this group."*

1. **EC2** → **Target Groups** → **Create target group**
   - **Target type:** Instances
   - **Target group name:** `main-tg`
   - **Protocol:** HTTP
   - **Port:** 80
   - **VPC:** Your VPC
   - **Health check protocol:** HTTP
   - **Health check path:** `/health`
   - **Advanced health check settings:**
     - Healthy threshold: `2`
     - Unhealthy threshold: `2`
     - Interval: `10` seconds
     - Timeout: `5` seconds
   - **Next**
2. **Register targets:** **DON'T register any targets manually** — the ASG will do this automatically.
3. **Create target group**

🗣️ *"Notice I left the target group EMPTY. We'll connect the ASG to this target group, and ASG will automatically register and deregister instances as it scales."*

---

### 🖥️ Step 2: Create the ALB

🗣️ *"Now let's create the load balancer itself — the single door that users will walk through."*

1. **EC2** → **Load Balancers** → **Create Load Balancer**
2. Select **Application Load Balancer** → **Create**
   - **Name:** `web-app-alb`
   - **Scheme:** Internet-facing (publicly accessible)
   - **IP address type:** IPv4
   - **Network mapping:**
     - **VPC:** Your VPC
     - **Mappings:** Select **at least 2 AZs** (same ones your ASG uses)
     - Select the **public subnets** in those AZs
   - **Security group:** Create new:
     - Name: `alb-sg`
     - Inbound rules:
       - HTTP (80) → `0.0.0.0/0`
       - HTTPS (443) → `0.0.0.0/0`
   - **Listeners and routing:**
     - **Listener:** HTTP : 80
     - **Default action:** Forward to → `main-tg`
3. **Create load balancer**

🗣️ *"ALB is creating. This takes about 2-3 minutes to go from 'provisioning' to 'active'. While we wait, let me grab the DNS name..."*

🖥️ **Copy the ALB DNS name** — it looks like `web-app-alb-XXXXXXXX.us-east-1.elb.amazonaws.com`

> ⏳ **Wait for ALB state to change to `Active` before testing.**

---

### 🖥️ Step 3: Connect ASG to the ALB Target Group

🗣️ *"Now the critical step — we need to tell the Auto Scaling Group to register its instances with our ALB's target group. This means every time ASG launches a new instance, it automatically gets added to the ALB. When ASG terminates an instance, it automatically gets removed."*

1. **EC2** → **Auto Scaling Groups** → Select `web-app-asg`
2. **Details** tab → **Load balancing** section → **Edit**
3. Check: **Application, Network or Gateway Load Balancer target groups**
4. Select: `main-tg` (the target group we created)
5. **Update**

🗣️ *"One more critical setting..."*

6. Still on `web-app-asg` → **Details** tab → **Health checks** → **Edit**
7. Check: **Turn on Elastic Load Balancing health checks** ✅
8. Health check grace period: `120` seconds
9. **Update**

🗣️ *"This is CRITICAL. We switched the health check from EC2 to ELB. Why? EC2 health checks only verify the instance is RUNNING. ELB health checks verify the APPLICATION is responding. If Nginx crashes but the instance is running, EC2 check says 'healthy' but ELB check says 'unhealthy.' ELB check catches more failures."*

---

### 🖥️ Step 4: Test Load Balancing! 🎉

🗣️ *"Now the moment of truth. Let's hit the ALB URL and see what happens."*

```bash
ALB_URL="http://web-app-alb-XXXXXXXX.us-east-1.elb.amazonaws.com"

# Hit the ALB 10 times — watch the Instance ID change!
for i in $(seq 1 10); do
  echo "--- Request $i ---"
  curl -s "$ALB_URL" | grep -oP 'Instance ID.*?</span>' | head -1
  sleep 1
done
```

**Expected output:**
```
--- Request 1 ---
Instance ID</span><span class="value">i-0abc111111111
--- Request 2 ---
Instance ID</span><span class="value">i-0def222222222
--- Request 3 ---
Instance ID</span><span class="value">i-0abc111111111
--- Request 4 ---
Instance ID</span><span class="value">i-0def222222222
```

🗣️ *"LOOK AT THAT! The Instance ID is ALTERNATING between two servers! That's round-robin load balancing. One URL, but each request goes to a DIFFERENT server. Students — open this URL in YOUR browsers and keep refreshing. You'll see the Instance ID and AZ changing every time you refresh!"*

🖥️ **Open the ALB URL in a browser. Refresh several times. Show the Instance ID changing.**

### ❓ Ask Students:

*"Open the ALB URL in your browser and refresh 10 times. How many different Instance IDs do you see?"*

*(Should be 2, matching the number of ASG instances)*

---

### 🖥️ Step 5: Health Check Demo — Kill One Server

🗣️ *"Now let's see what happens when a server DIES. I'm going to stop Nginx on one of the instances. The ALB should detect it within 20 seconds and stop sending traffic there."*

```bash
# SSH into one of the ASG instances
ssh -i my-class-key.pem ec2-user@<ASG-INSTANCE-1-IP>

# Kill Nginx
sudo systemctl stop nginx
```

🗣️ *"Nginx is stopped on instance 1. The ALB health check (/health) will get no response. Watch the Target Group..."*

🖥️ **EC2** → **Target Groups** → `main-tg` → **Targets** tab

```
After ~20 seconds (2 health check intervals × 10 seconds):
  i-0abc111111111 → unhealthy 🔴 (health check failed)
  i-0def222222222 → healthy 🟢
```

```bash
# Now hit the ALB — ALL traffic goes to the healthy instance
for i in $(seq 1 5); do
  echo -n "Request $i: "
  curl -s "$ALB_URL" | grep -oP 'Instance ID.*?</span>' | head -1
done
```

**Expected:** ALL requests return the SAME Instance ID (the healthy one).

🗣️ *"100% of traffic automatically routed to the healthy instance! The user doesn't see any error. They don't even know a server went down. THIS is high availability."*

```bash
# Restart Nginx
sudo systemctl start nginx
```

🗣️ *"After ~20 seconds, the ALB health check will succeed again and the instance goes back to healthy. Traffic is distributed again."*

---

### 🖥️ Step 6: Path-Based Routing Demo

🗣️ *"Now let me show you path-based routing — the killer feature of ALB. We'll set up rules so that `/app1` goes to one target group and `/app2` goes to a different target group."*

**Step 6a: Create Target Group for App1**

1. **EC2** → **Target Groups** → **Create target group**
   - Name: `app1-tg`
   - Type: Instances
   - Protocol: HTTP, Port: 80
   - VPC: Your VPC
   - Health check path: `/app1/`
   - **Next** → Register your **ASG instance 1** only → **Create**

**Step 6b: Create Target Group for App2**

1. **EC2** → **Target Groups** → **Create target group**
   - Name: `app2-tg`
   - Type: Instances
   - Protocol: HTTP, Port: 80
   - VPC: Your VPC
   - Health check path: `/app2/`
   - **Next** → Register your **ASG instance 2** only → **Create**

🗣️ *"Now we have 3 target groups: `main-tg` (both instances), `app1-tg` (instance 1 only), `app2-tg` (instance 2 only). Next, we create RULES on the ALB listener to route by path."*

**Step 6c: Add Listener Rules**

1. **EC2** → **Load Balancers** → `web-app-alb` → **Listeners and rules** tab
2. Click on **HTTP:80** listener → **Manage rules** → **Add rule**

**Rule 1 — Route /app1 to app1-tg:**
3. **Name:** `app1-routing`
4. **Add condition** → **Path** → Value: `/app1*`
5. **Add action** → **Forward to target group** → `app1-tg`
6. **Priority:** `1`
7. **Create**

**Rule 2 — Route /app2 to app2-tg:**
8. Same steps → **Add rule**
9. **Name:** `app2-routing`
10. **Add condition** → **Path** → Value: `/app2*`
11. **Add action** → **Forward to target group** → `app2-tg`
12. **Priority:** `2`
13. **Create**

🗣️ *"Done! Now the ALB has three rules:"*

```
Rule 1 (Priority 1): IF path = /app1*  → Send to app1-tg (Instance 1)
Rule 2 (Priority 2): IF path = /app2*  → Send to app2-tg (Instance 2)
Default rule:         Everything else   → Send to main-tg (Both instances)
```

**Step 6d: Test Path-Based Routing**

```bash
ALB_URL="http://web-app-alb-XXXXXXXX.us-east-1.elb.amazonaws.com"

# Test root — goes to main-tg (alternates between instances)
echo "=== Testing / (main-tg) ==="
for i in $(seq 1 4); do
  curl -s "$ALB_URL/" | grep -o 'Instance:.*' | head -1
done

echo ""

# Test /app1 — should ALWAYS go to instance 1
echo "=== Testing /app1 (app1-tg) ==="
for i in $(seq 1 4); do
  curl -s "$ALB_URL/app1/" | grep -o 'Instance:.*' | head -1
done

echo ""

# Test /app2 — should ALWAYS go to instance 2
echo "=== Testing /app2 (app2-tg) ==="
for i in $(seq 1 4); do
  curl -s "$ALB_URL/app2/" | grep -o 'Instance:.*' | head -1
done
```

**Expected Output:**
```
=== Testing / (main-tg) ===
Instance: i-0abc111111111     ← alternates
Instance: i-0def222222222     ← alternates
Instance: i-0abc111111111
Instance: i-0def222222222

=== Testing /app1 (app1-tg) ===
Instance: i-0abc111111111     ← ALWAYS instance 1
Instance: i-0abc111111111
Instance: i-0abc111111111
Instance: i-0abc111111111

=== Testing /app2 (app2-tg) ===
Instance: i-0def222222222     ← ALWAYS instance 2
Instance: i-0def222222222
Instance: i-0def222222222
Instance: i-0def222222222
```

🗣️ *"THERE IT IS! `/app1` ALWAYS goes to Instance 1 (green Catalog page). `/app2` ALWAYS goes to Instance 2 (purple Order page). The root `/` alternates between both. ONE load balancer, THREE different routing behaviors based on the URL path."*

🖥️ **Open all three URLs in browser tabs to show the different colored pages:**
1. `http://ALB-URL/` → Blue gradient "Hello from EC2" page (alternates)
2. `http://ALB-URL/app1/` → Green "App 1 — Catalog Service" page (always instance 1)
3. `http://ALB-URL/app2/` → Purple "App 2 — Order Service" page (always instance 2)

🗣️ *"This is how companies run MICROSERVICES on one load balancer. Netflix, Uber, Amazon — they all do path-based routing. `/api/users` goes to the user service, `/api/orders` goes to the order service. One ALB, dozens of services."*

### ❓ Ask Students:

*"Why is this better than running a separate ALB for each microservice?"*

*(Let them answer)*

*"Cost. Each ALB costs ~$16/month just for running. If you have 10 microservices on 10 ALBs, that's $160/month in ALB costs alone. With path-based routing on ONE ALB, it's $16/month total. One ALB, many services."*

---

# SECTION D: THE GRAND FINALE — ALL THREE WORKING TOGETHER

## Part 12: Combined Demo — CloudWatch + Auto Scaling + Load Balancer (25 minutes)

### 🗣️ Setting the Stage

*"This is the finale. We're going to simulate a REAL traffic spike on a production system and watch CloudWatch, Auto Scaling, and the Load Balancer work together — automatically — with ZERO manual intervention."*

*"Here's what SHOULD happen:"*

```
┌─────────────┐    ┌─────────────┐    ┌──────────────────┐    ┌───────────────┐
│   STRESS     │    │  CLOUDWATCH  │    │  AUTO SCALING     │    │ LOAD BALANCER │
│   (CPU load) │ →  │  (detects    │ →  │  (launches new    │ →  │ (distributes  │
│              │    │   high CPU)  │    │   instances)      │    │  traffic to   │
│              │    │  (fires      │    │  (registers with  │    │  NEW servers) │
│              │    │   alarm)     │    │   ALB)            │    │               │
└─────────────┘    └─────────────┘    └──────────────────┘    └───────────────┘
```

*"Let's see it in action."*

---

### 🖥️ Step 1: Prepare Your Views

🗣️ *"I'm going to set up my screen so you can see everything at once."*

**Arrange these 4 views (use multiple monitors or browser tabs):**

| View | What to Watch |
|------|---------------|
| **Tab 1:** CloudWatch Alarms | Watch for `TargetTracking-web-app-asg-AlarmHigh` |
| **Tab 2:** EC2 Instances | Count of running instances |
| **Tab 3:** Target Group | `main-tg` → Targets tab → healthy count |
| **Tab 4:** Terminal | Running the stress test + curl loop |

---

### 🖥️ Step 2: Start the Stress Test

🗣️ *"I'm going to SSH into BOTH ASG instances and max out their CPUs."*

```bash
# Terminal 1: Stress instance 1
ssh -i my-class-key.pem ec2-user@<ASG-INSTANCE-1-IP>
stress --cpu 4 --timeout 600

# Terminal 2: Stress instance 2
ssh -i my-class-key.pem ec2-user@<ASG-INSTANCE-2-IP>
stress --cpu 4 --timeout 600
```

🗣️ *"Both instances are now at 100% CPU. Average CPU across the group: ~100%. Our target tracking policy target is 50%. The system needs to double the capacity to bring CPU back to target."*

---

### 🖥️ Step 3: Narrate the Automatic Response (Real-Time Commentary)

🗣️ *"Now we wait and watch. I'm going to narrate what happens as it happens."*

**Live Timeline (update these timings based on what you observe):**

```
⏱️ 0:00 — STRESS STARTS
   CloudWatch: All alarms OK 🟢
   EC2: 2 instances running
   Target Group: 2 healthy targets
   ALB test: 2 different Instance IDs rotating

⏱️ ~1:00 — CloudWatch detects high CPU
   🗣️ "CloudWatch just got the first data point — CPU at 98%.
   It needs at least 2 consecutive breaches to be sure."

⏱️ ~2:00 — CloudWatch Alarm FIRES 🔴
   🗣️ "ALARM! The target tracking alarm just turned RED.
   Look at Tab 1 — 'TargetTracking-web-app-asg-AlarmHigh' is in ALARM state.
   This alarm was auto-created by the target tracking policy."

⏱️ ~2:30 — Auto Scaling REACTS
   🗣️ "Auto Scaling received the alarm. Check the ASG Activity History...
   There it is: 'Launching a new EC2 instance.' It's launching 2 more
   to bring average CPU from 100% toward 50%."

⏱️ ~3:00 — New instances appear in EC2 console
   🗣️ "Check Tab 2 — EC2 Instances. TWO new instances just appeared!
   State: 'pending'. They're booting up, running the user data script,
   installing Nginx, generating the web page..."

⏱️ ~4:00 — New instances reach 'running' state
   🗣️ "Instances are running. The ASG is registering them with the
   load balancer's target group. Check Tab 3..."

⏱️ ~4:30 — New instances appear in Target Group
   🗣️ "Look at the Target Group! We now have 4 targets.
   The 2 new ones show 'initial' status — ALB is health-checking them.
   It hits /health on each one and waits for 2 consecutive 200 responses."

⏱️ ~5:00 — New instances become HEALTHY in Target Group
   🗣️ "Now ALL FOUR targets are healthy! 🟢🟢🟢🟢
   The ALB is distributing traffic across all 4 instances."
```

---

### 🖥️ Step 4: Prove the Load Balancer is Using New Instances

```bash
ALB_URL="http://web-app-alb-XXXXXXXX.us-east-1.elb.amazonaws.com"

echo "=== After Auto Scaling — hitting ALB 8 times ==="
for i in $(seq 1 8); do
  echo -n "Request $i: "
  curl -s "$ALB_URL" | grep -oP 'value">i-[a-z0-9]+' | head -1
  sleep 1
done
```

**Expected Output: FOUR different Instance IDs now!**
```
Request 1: value">i-0aaa111111111
Request 2: value">i-0bbb222222222
Request 3: value">i-0ccc333333333     ← NEW instance!
Request 4: value">i-0ddd444444444     ← NEW instance!
Request 5: value">i-0aaa111111111
Request 6: value">i-0bbb222222222
Request 7: value">i-0ccc333333333
Request 8: value">i-0ddd444444444
```

🗣️ *"FOUR different Instance IDs! Before the stress test, we had 2. Now we have 4. Auto Scaling created 2 new instances, registered them with the Load Balancer, and the Load Balancer is distributing traffic across all 4. WE DIDN'T TOUCH ANYTHING. The system healed itself."*

🖥️ **Open the ALB URL in a browser and refresh rapidly. Show 4 different Instance IDs appearing.**

### ❓ Ask Students (The Big Question):

*"What just happened? Walk me through the chain of events, step by step."*

*(Guide them to say):*
1. *"We stressed the CPU to 100%"*
2. *"CloudWatch detected the high CPU metric"*
3. *"The target tracking alarm fired because CPU was above 50%"*
4. *"Auto Scaling received the alarm and launched new instances"*
5. *"The new instances were automatically registered with the ALB target group"*
6. *"ALB health-checked them and started sending traffic to them"*
7. *"CPU dropped because the load was distributed across more instances"*

🗣️ *"THAT is the complete cycle. Monitor → Alert → Scale → Balance. Three AWS services working in perfect harmony. This is how Netflix handles 250 million subscribers. This is how Amazon survives Prime Day. And you just built it."*

---

### 🖥️ Step 5: Stop the Stress and Watch Scale-In

```bash
# Ctrl+C on both SSH sessions
# Or wait for --timeout to expire
```

🗣️ *"Stress stopped. CPU drops to near zero. Now watch what happens over the next 15 minutes..."*

**What students should observe:**

```
⏱️ ~6:00  — Stress stops, CPU drops
⏱️ ~15:00 — Target tracking scale-in alarm fires
            "TargetTracking-web-app-asg-AlarmLow" enters ALARM
⏱️ ~16:00 — ASG reduces desired capacity: 4 → 2
⏱️ ~17:00 — 2 instances show "Terminating" in EC2 console
            ALB drains connections (300 sec default) then deregisters them
⏱️ ~18:00 — Back to 2 instances, 2 healthy targets in ALB
```

🗣️ *"And we're back to 2 instances. The system scaled up when it needed to and scaled back down to save money. Fully automatic. Monday through Sunday, 24/7, without a human touching anything."*

---

## Part 13: Common Mistakes & Troubleshooting (10 minutes)

### 🗣️ Top 10 Mistakes Students Make

| # | Mistake | What Happens | Fix |
|---|---------|-------------|-----|
| 1 | **Forgot to enable public IP** on ASG instances | Instances can't reach the internet for updates | Add `Auto-assign public IP: Enable` in Launch Template network settings |
| 2 | **Security group on ALB doesn't allow HTTP** | Users can't reach the ALB | Add Inbound Rule: HTTP(80) from 0.0.0.0/0 |
| 3 | **Security group on EC2 doesn't allow traffic from ALB** | ALB health checks fail, all targets unhealthy | Add Inbound Rule: HTTP(80) from ALB security group |
| 4 | **Wrong health check path** | ALB gets 404 → marks targets unhealthy | Set health check to `/health` (or `/` if no health endpoint) |
| 5 | **ASG health check type is EC2, not ELB** | ASG doesn't know when your app crashes (only hardware) | Switch to ELB health check type |
| 6 | **Forgot to confirm SNS email** | Alarm fires but you never get the email | Check spam folder, confirm subscription |
| 7 | **ASG instances in private subnet without NAT** | User data fails (can't download packages) | Use public subnets or add a NAT Gateway |
| 8 | **Setting CPU target too high (90%)** | Not enough time to scale before servers crash | Set target to 50-60% — leave headroom |
| 9 | **ALB in wrong subnets** | ALB can't reach EC2 instances in other subnets | ALB subnets must match (or be routable to) EC2 subnets |
| 10 | **Not waiting long enough** | "It's not working!" → It's just slow | Remember: alarm eval (1-2 min) + instance launch (2-3 min) + health check (1 min) = ~5 min total |

### 🗣️ The #1 Troubleshooting Tool

*"When something isn't working, check these IN ORDER:"*

```
1. Target Group → Targets tab
   → Are targets healthy 🟢 or unhealthy 🔴?
   → If unhealthy → Security group? Health check path? Port?

2. ASG → Activity tab
   → Any "Failed to launch" errors?
   → AMI still exists? Launch Template valid?

3. CloudWatch → Alarms
   → Is the alarm in ALARM state but nothing happened?
   → Check alarm actions — is SNS/Auto Scaling attached?

4. Security Groups
   → Can ALB reach EC2? (ALB-SG → EC2-SG on port 80)
   → Can users reach ALB? (0.0.0.0/0 → ALB-SG on port 80)
```

### ❓ Ask Students:

*"You created an ALB and all targets show 'unhealthy'. The web page works fine when you directly visit the EC2 public IP. What's wrong?"*

*(Guide them through the troubleshooting checklist)*

*"Answer: Most likely the SECURITY GROUP. The EC2 security group allows HTTP from 0.0.0.0/0 (so you can access it directly), but the ALB health check comes from the ALB's private IP. You need to add a rule allowing HTTP from the ALB's security group."*

---

## Part 14: Real-World Architecture Summary (5 minutes)

### 🗣️ What We Built Today

```
                    INTERNET
                       │
                       ▼
            ┌─────────────────┐
            │   Route 53      │  (DNS: app.example.com → ALB)
            │   (optional)    │
            └────────┬────────┘
                     │
                     ▼
            ┌─────────────────────────────────────────┐
            │        APPLICATION LOAD BALANCER         │
            │                                         │
            │  Listener: HTTP:80                       │
            │    Rule 1: /app1* → app1-tg              │
            │    Rule 2: /app2* → app2-tg              │
            │    Default: → main-tg                    │
            │                                         │
            │  Health check: /health every 10s         │
            └─────────────────┬───────────────────────┘
                              │
                              ▼
            ┌─────────────────────────────────────────┐
            │          AUTO SCALING GROUP               │
            │                                          │
            │  Min: 2 | Desired: 2-6 | Max: 6          │
            │  Launch Template: web-app-lt              │
            │  Scaling Policy: CPU Target 50%           │
            │                                          │
            │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐    │
            │  │ EC2  │ │ EC2  │ │ EC2  │ │ EC2  │    │
            │  │ AZ-a │ │ AZ-b │ │ AZ-a │ │ AZ-b │    │
            │  └──────┘ └──────┘ └──────┘ └──────┘    │
            │  (always 2)       (scale-out, temp)      │
            └─────────────────────────────────────────┘
                              │
                              ▼
            ┌─────────────────────────────────────────┐
            │           CLOUDWATCH                      │
            │                                          │
            │  📊 Metrics: CPUUtilization per instance  │
            │  🔔 Alarms:                               │
            │     - High CPU > target (scale out)       │
            │     - Low CPU < target (scale in)         │
            │  📺 Dashboard: Live monitoring             │
            │  📩 SNS: Email alerts on scaling events    │
            └─────────────────────────────────────────┘
```

🗣️ *"THIS is a production-ready, auto-scaling, load-balanced, monitored web application. Add an SSL certificate with ACM, point Route 53 to the ALB, put CloudFront in front for caching — and you've got what Fortune 500 companies run."*

---

## Part 15: Recap Questions — Test Understanding (10 minutes)

### ❓ Rapid-Fire Questions (Ask the class)

**CloudWatch:**

1. *"What's the default EC2 metric interval?"*
   → 5 minutes (Detailed Monitoring = 1 minute)

2. *"Does CloudWatch monitor memory usage by default?"*
   → NO. You need the CloudWatch Agent.

3. *"What are the three alarm states?"*
   → OK, ALARM, INSUFFICIENT_DATA

4. *"What happens when an alarm fires?"*
   → Triggers actions: SNS notification, Auto Scaling, EC2 action

**Auto Scaling:**

5. *"What are the three capacity numbers in ASG?"*
   → Minimum, Maximum, Desired

6. *"What is a Launch Template?"*
   → Blueprint for new instances (AMI, instance type, security group, user data)

7. *"What scaling policy should I use first?"*
   → Target Tracking (simplest, smartest — like a thermostat)

8. *"How long does auto scaling take from alarm to serving traffic?"*
   → 3-8 minutes (alarm + launch + boot + health check)

9. *"Why set CPU target at 50% and not 90%?"*
   → Need headroom while new instances are launching

**Load Balancer:**

10. *"ALB vs NLB — when to use which?"*
    → ALB for HTTP/path routing/WAF. NLB for TCP/UDP/static IP/ultra-low latency.

11. *"What is path-based routing?"*
    → ALB sends /app1 to Target Group 1, /app2 to Target Group 2

12. *"What happens when a server fails its health check?"*
    → ALB removes it from rotation. Traffic goes to healthy servers only.

**Combined:**

13. *"Walk me through the flow: CPU spikes → what happens?"*
    → CloudWatch detects → Alarm fires → ASG launches instances → ALB registers them → Traffic distributed

14. *"Should ASG health check be EC2 or ELB?"*
    → ELB. Catches app-level failures, not just hardware.

15. *"Why does scale-in take longer than scale-out?"*
    → Safety. Removing servers prematurely could cause another spike.

---

## Cleanup — Delete All Resources

🗣️ *"Let's clean up everything to avoid charges."*

### Order matters! Delete in this sequence:

```bash
# 1. Delete ASG first (this terminates all ASG instances)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name web-app-asg \
  --min-size 0 --max-size 0 --desired-capacity 0

# Wait 2 minutes for instances to terminate, then:
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name web-app-asg \
  --force-delete

# 2. Delete the ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names web-app-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"

# 3. Delete Target Groups (wait ~30s after ALB deletion)
for TG_NAME in main-tg app1-tg app2-tg; do
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$TG_NAME" \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
  if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
    echo "Deleted $TG_NAME"
  fi
done

# 4. Delete Launch Template
aws ec2 delete-launch-template --launch-template-name web-app-lt

# 5. Deregister and delete AMI
AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=web-app-demo-ami" \
  --query 'Images[0].ImageId' --output text)
aws ec2 deregister-image --image-id "$AMI_ID"
# Also delete the backing snapshot
SNAP_ID=$(aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=description,Values=*$AMI_ID*" \
  --query 'Snapshots[0].SnapshotId' --output text)
aws ec2 delete-snapshot --snapshot-id "$SNAP_ID"

# 6. Terminate the original instance (if still running)
# EC2 Console → Select web-app-demo → Terminate

# 7. Delete CloudWatch Alarm
aws cloudwatch delete-alarms --alarm-names "High-CPU-Demo-Alarm"

# 8. Delete CloudWatch Dashboard
aws cloudwatch delete-dashboards --dashboard-names "Demo-Dashboard"

# 9. Delete SNS Topic
SNS_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn,'cpu-alerts')].TopicArn" --output text)
aws sns delete-topic --topic-arn "$SNS_ARN"

# 10. Delete Security Groups (after instances are terminated)
# EC2 Console → Security Groups → Delete 'web-app-sg' and 'alb-sg'
# (Cannot delete if still in use — wait for all instances to terminate)
```

🗣️ *"Always clean up after a demo. These resources cost money even when idle. The ALB alone is $0.02/hour = $16/month."*

---

## Timing Summary

| Section | Topic | Duration |
|---------|-------|----------|
| **SECTION A: CloudWatch** | | |
| Part 1 | Why Monitoring Matters | 10 min |
| Part 2 | Metrics Deep Dive | 15 min |
| Part 3 | Alarms | 15 min |
| Part 4 | **LIVE DEMO: Launch EC2 + CloudWatch + Alarm + CPU Stress** | 30 min |
| | **Dashboard quick demo** | 5 min |
| **☕ BREAK** | | **10 min** |
| **SECTION B: Auto Scaling** | | |
| Part 5 | Why Auto Scaling (Pizza Shop Analogy) | 10 min |
| Part 6 | ASG Concepts (Min/Max/Desired, Launch Template, Policies) | 15 min |
| Part 7 | **LIVE DEMO: Create AMI + Launch Template + ASG + Stress Test** | 35 min |
| **☕ BREAK** | | **10 min** |
| **SECTION C: Load Balancer** | | |
| Part 8 | Why Load Balancing (Restaurant Analogy) | 10 min |
| Part 9 | Types of Load Balancers (ALB/NLB/CLB/GWLB) | 15 min |
| Part 10 | ALB Architecture Deep Dive | 10 min |
| Part 11 | **LIVE DEMO: Create ALB + Target Groups + Path-Based Routing** | 40 min |
| **SECTION D: Grand Finale** | | |
| Part 12 | **COMBINED DEMO: Stress → CloudWatch → ASG → ALB in action** | 25 min |
| Part 13 | Troubleshooting & Common Mistakes | 10 min |
| Part 14 | Architecture Summary | 5 min |
| Part 15 | Recap Questions | 10 min |
| | Cleanup | 5 min |
| **Total** | | **~5 hours** |

---

## Key Teaching Tips

> **Trainer tip: The WOW moments.** There are three moments where students go "WOW":
> 1. **CloudWatch alarm fires and they get the email** (Section A)
> 2. **New instances appear automatically during stress test** (Section B)
> 3. **ALB URL shows FOUR different Instance IDs after scale-out** (Section D)
>
> Build up to each of these moments. Slow down. Make them look at their screens. Let the wow sink in.

> **Trainer tip: The URL refresh trick.** In Section C, have ALL students open the ALB URL in their browsers. Tell them to refresh rapidly. They'll see different Instance IDs and different AZs. This visceral experience — "I'm seeing DIFFERENT SERVERS!" — is worth 10 minutes of explanation.

> **Trainer tip: Expected delays.** Tell students BEFORE each demo: "This will take about X minutes." Students get anxious when things don't happen instantly. Managing expectations prevents "is it broken?" anxiety.

> **Trainer tip: The security group gotcha.** The most common lab failure is security groups. If ALB targets are unhealthy, 90% of the time it's because the EC2 security group doesn't allow traffic from the ALB security group. Always verify this FIRST.

> **Trainer tip: Keep the original instance running** through Section B (for comparison). Students can see the difference between the original manually-launched instance and the ASG-created clones.

> **Trainer tip: Scale-in patience.** Scale-in takes 10-15 minutes. If you're running short on time, TELL students what will happen ("these 2 extra instances will terminate in about 15 minutes") and move on to the Load Balancer section instead of waiting. You can check back later and confirm it happened.

> **Trainer tip: Path-based routing is the interview answer.** Nearly every AWS Solutions Architect interview asks about ALB routing. Make sure students can explain path-based routing confidently. The demo with `/app1` and `/app2` showing different colored pages is powerful visual evidence of understanding.
