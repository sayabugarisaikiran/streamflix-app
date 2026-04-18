# AWS CloudWatch — Complete Teaching Script

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~3.5 hour session with break.

---

## Part 1: Why Monitoring Matters (10 minutes)

### 🗣️ Opening Hook

*"Quick scenario. It's 2 AM. Your phone rings. An angry VP says: 'The website is down. Customers are complaining on Twitter. How long has it been down? What's causing it?'"*

*"You SSH into your servers. They seem fine. CPU is normal. Memory looks okay. But the site is still down. You start checking the load balancer... the database... the network. 45 minutes later, you find it — the disk was full on one database slave. A log file grew unchecked."*

*"Now here's the alternative. You have CloudWatch configured. At 1:50 AM — TEN MINUTES BEFORE the crash — you got an automatic alert: 'Disk usage on db-slave-2 exceeded 90%.' An auto-scaling policy kicked in and attached a new replica. The site never went down. You slept through it."*

*"THAT is why monitoring matters. And in AWS, monitoring = CloudWatch."*

---

### 🗣️ What is CloudWatch?

*"CloudWatch is AWS's monitoring and observability service. It does FIVE things:"*

```
CloudWatch
  │
  ├── 📊 Metrics      — Numbers over time (CPU, memory, requests)
  ├── 🔔 Alarms       — "Alert me when X crosses Y threshold"
  ├── 📋 Logs          — Text output from applications and services
  ├── 📺 Dashboards    — Visual graphs on a single screen
  └── ⚡ Events/EB     — "When X happens, trigger Y" (now called EventBridge)
```

*"Think of it as: Metrics = the thermometer. Alarms = the fire alarm. Logs = the security camera footage. Dashboards = the control room monitors. Events = the automatic sprinkler system."*

---

## Part 2: CloudWatch Metrics — The Foundation (20 minutes)

### 🗣️ What is a Metric?

*"A metric is a TIME-SERIES data point. It's a number measured at regular intervals."*

```
Metric: CPUUtilization
Instance: i-abc123
Time: 10:00 → 23%
Time: 10:05 → 45%
Time: 10:10 → 87%    ← Something is happening!
Time: 10:15 → 92%    ← Alert! Alert!
Time: 10:20 → 34%    ← It calmed down
```

### 🗣️ Metric Anatomy

*"Every metric has these components:"*

| Component | What It Is | Example |
|-----------|-----------|---------|
| **Namespace** | Category/service | `AWS/EC2`, `AWS/RDS`, `AWS/ALB` |
| **Metric Name** | The measurement | `CPUUtilization`, `NetworkIn` |
| **Dimensions** | Filters | `InstanceId=i-abc123` |
| **Timestamp** | When it was recorded | `2024-04-18T10:05:00Z` |
| **Value** | The number | `45.2` |
| **Unit** | Unit of measurement | `Percent`, `Bytes`, `Count` |

*"So `AWS/EC2` → `CPUUtilization` → `InstanceId=i-abc123` → `45.2%` at `10:05 AM` is one data point."*

### 🗣️ Resolution: Standard vs High-Resolution

| Type | Interval | Cost | Use Case |
|------|----------|------|----------|
| **Standard** | 5 minutes | Free (for AWS services) | Normal monitoring |
| **Detailed** | 1 minute | $2.10/month per instance | Production EC2 |
| **High-Resolution** | 1 second | Custom metric cost | Trading platforms, real-time systems |

*"By default, EC2 sends metrics every 5 minutes. If you enable Detailed Monitoring, it sends every 1 minute. For custom metrics, you can go down to 1 second."*

### ❓ Ask Students:

*"EC2 sends CPU metrics every 5 minutes by default. Your alarm threshold is 'CPU > 80% for 5 minutes.' How long before you get alerted after a spike begins?"*

*"Answer: Worst case, 10 minutes! 5 minutes for the first data point to arrive + 5 minutes evaluation period. That's why production uses 1-minute Detailed Monitoring."*

---

### 🗣️ Built-In Metrics by Service

*"AWS services automatically send metrics to CloudWatch. You don't install anything."*

#### EC2 Metrics (Most Common)

| Metric | What It Measures | Watch Out For |
|--------|-----------------|---------------|
| `CPUUtilization` | % CPU used | > 80% sustained = scale up |
| `NetworkIn` / `NetworkOut` | Bytes transferred | Sudden spike = possible attack |
| `DiskReadOps` / `DiskWriteOps` | IOPS | Hitting EBS limits? |
| `StatusCheckFailed` | Instance health | 1 = hardware/software failure |
| `StatusCheckFailed_Instance` | OS-level check | 1 = reboot needed |
| `StatusCheckFailed_System` | Hardware check | 1 = AWS needs to migrate your instance |

> ⚠️ **CRITICAL: EC2 does NOT send memory metrics or disk space metrics by default!**

*"This catches EVERYONE. CPU, network, disk I/O — yes. But RAM usage and disk space? No. You need the CloudWatch Agent for those. We'll cover that."*

#### ALB Metrics

| Metric | What It Measures | Alert When |
|--------|-----------------|------------|
| `RequestCount` | Total requests | Sudden drop = outage |
| `HTTPCode_Target_2XX_Count` | Successful responses | Drop = application error |
| `HTTPCode_Target_5XX_Count` | Server errors | > 0 = investigate |
| `HTTPCode_ELB_5XX_Count` | ALB itself erroring | > 0 = ALB issue |
| `TargetResponseTime` | Average response time | > 2 seconds = slow |
| `HealthyHostCount` | Healthy targets | < expected = failover |
| `UnHealthyHostCount` | Unhealthy targets | > 0 = server down |
| `ActiveConnectionCount` | Current connections | Spike = traffic surge |

#### RDS Metrics

| Metric | What It Measures | Alert When |
|--------|-----------------|------------|
| `CPUUtilization` | Database CPU | > 80% = need bigger instance |
| `DatabaseConnections` | Active connections | Near `max_connections` limit |
| `FreeableMemory` | Available RAM | < 200MB = danger |
| `FreeStorageSpace` | Disk space left | < 20% = expand storage |
| `ReadIOPS` / `WriteIOPS` | Disk operations | Hitting provisioned IOPS limit |
| `ReadLatency` / `WriteLatency` | Disk response time | > 10ms = storage bottleneck |
| `ReplicaLag` | Read replica delay | > 30 seconds = replica falling behind |

#### Lambda Metrics

| Metric | What It Measures | Alert When |
|--------|-----------------|------------|
| `Invocations` | Times function ran | Sudden drop/spike |
| `Duration` | Execution time (ms) | Approaching timeout limit |
| `Errors` | Failed executions | > 0 = code bug |
| `Throttles` | Rejected (concurrency limit) | > 0 = increase limit |
| `ConcurrentExecutions` | Parallel runs | Near account limit (1000) |
| `IteratorAge` | Stream processing lag | > 0 for Kinesis/DynamoDB triggers |

#### S3 Metrics (Request Metrics — must be enabled)

| Metric | What It Measures |
|--------|-----------------|
| `NumberOfObjects` | Total objects in bucket |
| `BucketSizeBytes` | Total bucket size |
| `AllRequests` | Total API calls |
| `4xxErrors` | Client errors (forbidden, not found) |
| `5xxErrors` | Server errors |
| `FirstByteLatency` | Time to first byte |

---

## Part 3: Statistics and Periods (10 minutes)

### 🗣️ What are Statistics?

*"Raw metric data is just individual data points. Statistics AGGREGATE those data points over a time period."*

| Statistic | What It Does | Use Case |
|-----------|-------------|----------|
| **Average** | Mean of all values in the period | CPU utilization over 5 min |
| **Sum** | Total of all values | Total requests in 5 min |
| **Minimum** | Lowest value | Best response time |
| **Maximum** | Highest value | Peak CPU spike |
| **SampleCount** | Number of data points | How many readings in the period |
| **pNN.NN** (Percentile) | Value below which NN% of data falls | p99 latency (99th percentile) |

### 🗣️ Percentiles — The Pro Metric

*"Average is DANGEROUS for response time. Here's why:"*

```
100 requests:
  99 requests: 50ms
  1 request:   5,000ms (5 seconds!)

Average: (99×50 + 1×5000) / 100 = 99.5ms
→ "Looks fine!" But 1% of users waited 5 SECONDS.

p99: 5,000ms
→ "1% of users are having a terrible experience!"
```

*"Always use p99 or p95 for latency monitoring, not average. Amazon's internal rule: p99 latency must be under 200ms."*

### 🗣️ Periods

*"A period is the time window for aggregating data points."*

| Period | What It Means |
|--------|-------------|
| 60 seconds | Fine-grained (use with detailed monitoring) |
| 300 seconds (5 min) | Default, good for most alarms |
| 3600 seconds (1 hour) | Dashboard overview |
| 86400 seconds (1 day) | Cost and trend analysis |

*"Shorter period = more granular but more data points = higher cost for custom metrics."*

---

## Part 4: CloudWatch Alarms (20 minutes)

### 🗣️ What is an Alarm?

*"An alarm watches a metric and takes action when it crosses a threshold."*

```
Alarm: "High-CPU-Alert"
  Metric: AWS/EC2 → CPUUtilization → i-abc123
  Threshold: > 80%
  Period: 5 minutes
  Evaluation periods: 3 consecutive
  → "If CPU is above 80% for THREE consecutive 5-minute checks (15 min total), ALARM!"
```

### 🗣️ Alarm States

| State | Meaning | Color |
|-------|---------|-------|
| **OK** | Metric is within threshold | 🟢 Green |
| **ALARM** | Metric breached threshold | 🔴 Red |
| **INSUFFICIENT_DATA** | Not enough data to evaluate | 🟡 Yellow |

### 🗣️ Alarm Components

| Component | What It Is | Example |
|-----------|-----------|---------|
| **Metric** | What to watch | CPUUtilization |
| **Threshold** | The trigger value | > 80% |
| **Period** | Evaluation window | 300 seconds (5 min) |
| **Evaluation Periods** | How many consecutive periods | 3 |
| **Datapoints to Alarm** | How many must breach | 3 out of 3 |
| **Action** | What happens when triggered | SNS notification, Auto Scaling, EC2 action |

### 🗣️ Alarm Actions

*"When an alarm triggers, it can do these things:"*

| Action Type | What It Does | Example |
|-------------|-------------|---------|
| **SNS Notification** | Send alert | Email, SMS, Slack, PagerDuty |
| **Auto Scaling** | Scale up/down | Add 2 EC2 instances |
| **EC2 Action** | Stop/terminate/reboot/recover | Auto-recover failed instance |
| **Systems Manager** | Run automation | Execute runbook |
| **Lambda** | Run function | Custom remediation logic |

### 🗣️ M out of N Alarms

*"You don't have to alarm on every single breach. Use 'M out of N':"*

```
"3 out of 5 evaluation periods"

Period 1: 85% → BREACH  (1/5)
Period 2: 75% → OK      (1/5)
Period 3: 90% → BREACH  (2/5)
Period 4: 82% → BREACH  (3/5) → ALARM! (3 out of 5 reached)
Period 5: (not needed, already alarmed)
```

*"This prevents false alarms from single CPU spikes. Maybe a deployment caused a 1-minute spike — that's normal. But 3 spikes in 5 checks? Real problem."*

### 🗣️ Composite Alarms

*"A composite alarm combines MULTIPLE alarms with AND / OR logic."*

```
Composite Alarm: "Application-Critical"
  Condition: 
    "High-CPU" = ALARM
    AND
    "High-5xx-Errors" = ALARM
  
  → Only triggers if BOTH CPU is high AND errors are happening
  → Prevents noise from CPU spikes during normal deployments (which have no errors)
```

*"Use composite alarms in production to reduce alert fatigue. Engineers ignore alerts if they fire too often."*

### ❓ Ask Students:

*"I set an alarm: CPU > 90% for 1 evaluation period of 5 minutes. My instance CPU spikes to 95% for 30 seconds then drops back. Will the alarm fire?"*

*"Answer: Maybe not! The 5-minute AVERAGE might still be under 90% because 30 seconds of 95% averaged over 300 seconds could be low. Use Maximum statistic instead of Average if you want to catch brief spikes."*

---

## Part 5: CloudWatch Logs (20 minutes)

### 🗣️ What are CloudWatch Logs?

*"CloudWatch Logs is a centralized logging service. Instead of SSH-ing into each server to read log files, ALL your logs go to one place."*

### 🗣️ Log Architecture

```
Log Group:    /application/streamflix
  │
  ├── Log Stream: i-abc123 (EC2 instance 1)
  │     ├── [2024-04-18 10:00:01] INFO  User login: user@email.com
  │     ├── [2024-04-18 10:00:02] INFO  GET /api/movies 200 45ms
  │     └── [2024-04-18 10:00:03] ERROR Database connection timeout
  │
  ├── Log Stream: i-def456 (EC2 instance 2)
  │     ├── [2024-04-18 10:00:01] INFO  GET /api/movies 200 52ms
  │     └── [2024-04-18 10:00:02] INFO  GET /health 200 2ms
  │
  └── Log Stream: i-ghi789 (EC2 instance 3)
        └── [2024-04-18 10:00:01] WARN  Slow query: 2340ms
```

| Component | What It Is | Example |
|-----------|-----------|---------|
| **Log Group** | Container for related log streams | `/app/streamflix`, `/aws/lambda/my-function` |
| **Log Stream** | Sequence of events from one source | One per EC2 instance, Lambda invocation |
| **Log Event** | A single log line | `ERROR Database connection timeout` |
| **Retention** | How long to keep logs | 1 day to 10 years (or never expire) |

### 🗣️ What Sends Logs to CloudWatch?

| Source | How | Automatic? |
|--------|-----|-----------|
| **Lambda** | Built-in — just `print()` or `console.log()` | ✅ Yes |
| **API Gateway** | Enable access logging in stage settings | Manual |
| **EC2** | Install CloudWatch Agent | Manual |
| **ECS/Fargate** | `awslogs` log driver | Semi-auto |
| **CloudTrail** | Send API audit logs to CloudWatch | Manual |
| **RDS** | Enable log exports | Manual |
| **VPC Flow Logs** | Configure to send to CloudWatch | Manual |
| **Route 53** | Query logging | Manual |
| **WAF** | Enable logging | Manual |

### 🗣️ Log Retention & Cost

*"Logs cost money to store. Set retention policies!"*

| Retention | Use Case |
|-----------|----------|
| 1 day | Dev/test — don't care about old logs |
| 7 days | Staging — keep a week for debugging |
| 30 days | Production — default recommendation |
| 90 days | Compliance (PCI, HIPAA) |
| 365 days | Audit requirements |
| Never expire | Legal hold — ⚠️ costs will grow forever |

```
Pricing:
  Ingestion:  $0.50 per GB
  Storage:    $0.03 per GB/month

  If your app generates 10 GB/day of logs:
    Ingestion: 10 × 30 × $0.50 = $150/month
    Storage:   10 × 30 × $0.03 = $9/month (with 30-day retention)
    Total:     ~$159/month
```

*"Log ingestion is the expensive part, not storage. Optimize your logging — don't log every HTTP 200."*

---

### 🗣️ Metric Filters — Turn Logs into Metrics

*"This is a powerful feature. You can CREATE metrics from log patterns."*

```
Log Group: /app/streamflix
Filter Pattern: "ERROR"
Metric Name: ErrorCount
Metric Value: 1

→ Every time the word "ERROR" appears in any log line,
   CloudWatch increments the ErrorCount metric by 1.
→ Now you can create an ALARM on ErrorCount > 10 in 5 minutes!
```

**Common Metric Filter Patterns:**

| Pattern | What It Matches |
|---------|----------------|
| `"ERROR"` | Any line containing ERROR |
| `"ERROR" - "ErrorBoundary"` | ERROR but NOT ErrorBoundary |
| `{ $.statusCode = 500 }` | JSON logs where statusCode is 500 |
| `{ $.latency > 5000 }` | JSON logs where latency exceeds 5 seconds |
| `"OutOfMemoryError"` | Java OOM crashes |
| `"FATAL"` | Fatal errors |
| `[ip, user, timestamp, request, status_code = 5*, bytes]` | Space-delimited logs with 5xx status |

### 🗣️ Log Insights — Query Your Logs

*"CloudWatch Logs Insights lets you run SQL-like queries across your logs:"*

```sql
-- Find the top 10 most common errors in the last hour
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as errorCount by @message
| sort errorCount desc
| limit 10
```

```sql
-- Average response time per API endpoint
fields @timestamp, @message
| parse @message "* * * * *ms" as method, path, status, latency
| filter method = "GET"
| stats avg(latency) as avgLatency by path
| sort avgLatency desc
```

```sql
-- Find all requests from a specific IP
fields @timestamp, @message
| filter @message like /203.0.113.50/
| sort @timestamp desc
| limit 50
```

*"Logs Insights is fast — it scans GB of logs in seconds. Charges: $0.005 per GB scanned."*

---

## Part 6: CloudWatch Agent (15 minutes)

### 🗣️ Why Do You Need the Agent?

*"Remember: EC2 does NOT send memory or disk metrics by default. The CloudWatch Agent fills this gap."*

| Without Agent | With Agent |
|---------------|------------|
| CPU ✅ | CPU ✅ |
| Network ✅ | Network ✅ |
| Disk I/O ✅ | Disk I/O ✅ |
| Memory ❌ | Memory ✅ |
| Disk space ❌ | Disk space ✅ |
| Process count ❌ | Process count ✅ |
| Application logs ❌ | Application logs ✅ |
| Swap usage ❌ | Swap usage ✅ |

### 🗣️ How to Install

```bash
# On Amazon Linux 2023 / AL2:
sudo yum install -y amazon-cloudwatch-agent

# On Ubuntu:
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

### 🗣️ Agent Configuration

*"The agent uses a JSON config file. You can generate it with a wizard or write it by hand:"*

```bash
# Interactive wizard (easiest for beginners):
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

*"Or create the config manually:"*

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "StreamFlix/EC2",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent", "mem_total", "mem_available"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent", "disk_free"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": ["swap_used_percent"]
      },
      "processes": {
        "measurement": ["running", "sleeping", "dead", "zombies", "total"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/streamflix/nginx/access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/streamflix/nginx/error",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
          }
        ]
      }
    }
  }
}
```

*"Save this as `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`, then:"*

```bash
# Start the agent with your config
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Check status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
```

### 🗣️ IAM Role Required

*"The agent needs permission to send metrics and logs to CloudWatch. Attach this IAM policy to your EC2 instance role:"*

| Policy | What It Allows |
|--------|---------------|
| `CloudWatchAgentServerPolicy` | Send metrics + logs to CloudWatch |
| `AmazonSSMManagedInstanceCore` | (Optional) Manage agent via SSM |

---

## Part 7: Custom Metrics (10 minutes)

### 🗣️ What are Custom Metrics?

*"AWS services send built-in metrics. But what about YOUR application-specific numbers?"*

| Custom Metric Example | Why |
|----------------------|-----|
| `ActiveUsers` | How many users are logged in right now |
| `OrdersPlaced` | Orders per minute |
| `PaymentFailures` | Failed payment attempts |
| `QueueDepth` | Items waiting to be processed |
| `CacheHitRate` | % of requests served from cache |

### 🗣️ How to Send Custom Metrics

**Method 1: AWS CLI**
```bash
aws cloudwatch put-metric-data \
  --namespace "StreamFlix" \
  --metric-name "ActiveUsers" \
  --value 142 \
  --unit Count \
  --dimensions Environment=Production,Service=WebApp
```

**Method 2: SDK (Python)**
```python
import boto3

cloudwatch = boto3.client('cloudwatch')
cloudwatch.put_metric_data(
    Namespace='StreamFlix',
    MetricData=[{
        'MetricName': 'ActiveUsers',
        'Value': 142,
        'Unit': 'Count',
        'Dimensions': [
            {'Name': 'Environment', 'Value': 'Production'},
            {'Name': 'Service', 'Value': 'WebApp'}
        ]
    }]
)
```

**Method 3: Embedded Metric Format (in logs)**
```json
{
  "_aws": {
    "Timestamp": 1681234567890,
    "CloudWatchMetrics": [{
      "Namespace": "StreamFlix",
      "Dimensions": [["Service"]],
      "Metrics": [{"Name": "ResponseTime", "Unit": "Milliseconds"}]
    }]
  },
  "Service": "WebApp",
  "ResponseTime": 45
}
```
*"Print this JSON to stdout in Lambda. CloudWatch automatically extracts the metric — no API calls needed!"*

### 🗣️ Pricing

```
Custom metrics: $0.30/metric/month (first 10,000)
API calls:     $0.01 per 1,000 PutMetricData calls

10 custom metrics: $3/month
100 custom metrics: $30/month
```

---

## Part 8: CloudWatch Dashboards (10 minutes)

### 🗣️ What are Dashboards?

*"A dashboard is a single screen with multiple graphs showing your metrics. It's your control room."*

### 🗣️ Dashboard Features

| Feature | What It Does |
|---------|-------------|
| **Line chart** | Time-series data (CPU over time) |
| **Stacked area** | Multiple metrics stacked (requests by endpoint) |
| **Number widget** | Single value (current error count) |
| **Gauge** | Dial showing value vs threshold |
| **Bar chart** | Comparison (requests per AZ) |
| **Text widget** | Markdown notes, links, headers |
| **Alarm status** | Red/green indicators for all alarms |
| **Log widget** | Recent log entries inline |
| **Explorer** | Dynamic graphs based on tags |

### 🗣️ Dashboard Best Practices

1. **One dashboard per application** — "StreamFlix Production"
2. **Top row: Alarms** — red/green status at a glance
3. **Second row: Business metrics** — orders, revenue, active users
4. **Third row: Infrastructure** — CPU, memory, disk, network
5. **Bottom row: Errors** — 5xx count, error logs
6. **Use auto-refresh** — 1 minute or 10 seconds
7. **Share with stakeholders** — public URL or cross-account sharing

### 🗣️ Pricing

```
First 3 dashboards: FREE
Additional: $3/month per dashboard
Each dashboard: up to 500 widgets
```

---

## Part 9: EventBridge (CloudWatch Events) (15 minutes)

### 🗣️ What is EventBridge?

*"EventBridge (formerly CloudWatch Events) is an event bus. When something HAPPENS in AWS, EventBridge can automatically REACT."*

```
EVENT: EC2 instance state changed to "stopped"
  │
  ├── Rule: Match this event pattern
  │
  └── Target: Send SNS notification "Instance i-abc123 stopped!"
             OR invoke Lambda to restart it
             OR send to Slack via webhook
```

### 🗣️ Event Sources

| Source | Example Events |
|--------|---------------|
| **EC2** | Instance started, stopped, terminated |
| **ECS** | Task started, task succeeded, task failed |
| **Auto Scaling** | Launch, terminate, failed launch |
| **CodePipeline** | Pipeline started, stage succeeded, stage failed |
| **GuardDuty** | Security threat detected |
| **Health** | AWS service outage affecting your resources |
| **S3** | Object created, object deleted |
| **IAM** | User login, policy changed |
| **CloudTrail** | Any API call in your account |
| **Scheduled** | Cron expressions (run every 5 minutes) |

### 🗣️ Event Pattern vs Schedule

**Event Pattern (reactive):**
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped", "terminated"]
  }
}
```
*"Fires whenever any EC2 instance stops or terminates."*

**Schedule (proactive):**
```
rate(5 minutes)              → Every 5 minutes
rate(1 hour)                 → Every hour
cron(0 8 * * ? *)            → Every day at 8:00 AM UTC
cron(0 18 ? * MON-FRI *)     → Weekdays at 6:00 PM UTC
```
*"Use schedules for periodic tasks: cleanup, reports, health checks."*

### 🗣️ Event Targets

| Target | Use Case |
|--------|----------|
| **Lambda** | Run custom code in response to event |
| **SNS** | Send notification (email, SMS, Slack) |
| **SQS** | Queue event for processing |
| **Step Functions** | Start a workflow |
| **ECS Task** | Run a container |
| **CodePipeline** | Trigger a deployment |
| **SSM Automation** | Run a runbook |
| **CloudWatch Log Group** | Log the event |
| **Another EventBridge bus** | Forward to another account/region |

### 🗣️ Real-World EventBridge Examples

**1. Auto-tag EC2 instances at launch:**
```
Event: EC2 instance launched
Target: Lambda → reads instance ID → adds Name tag based on launch template
```

**2. Slack notification when deployment fails:**
```
Event: CodePipeline stage failed
Target: Lambda → formats message → sends to Slack webhook
```

**3. Stop dev instances at night:**
```
Schedule: cron(0 19 ? * MON-FRI *)  (7 PM weekdays)
Target: Lambda → stops all instances tagged Environment=Dev
```

**4. Security alert on root login:**
```
Event: CloudTrail → ConsoleLogin → root user
Target: SNS → email to security team
        Lambda → create Jira ticket
```

---

## Part 10: CloudWatch Pricing Summary (5 minutes)

### 🗣️ The Full Pricing Picture

| Feature | Free Tier | Paid |
|---------|-----------|------|
| **Basic metrics** | ✅ (5-min, AWS services) | — |
| **Detailed monitoring** | ❌ | $2.10/instance/month (1-min EC2) |
| **Custom metrics** | 10 free | $0.30/metric/month |
| **Alarms** | 10 free | $0.10/alarm/month |
| **Dashboards** | 3 free | $3/dashboard/month |
| **Log ingestion** | 5 GB free | $0.50/GB |
| **Log storage** | 5 GB free | $0.03/GB/month |
| **Log Insights** | — | $0.005/GB scanned |
| **API calls** | 1M free | $0.01/1,000 calls |
| **Contributor Insights** | — | $0.02/rule/metric/month |
| **Synthetics (Canaries)** | — | $0.0012/run |

### 🗣️ Typical Monthly Cost

```
Small production app (5 EC2, 1 RDS, 1 ALB):
  Detailed monitoring:  5 × $2.10      = $10.50
  Custom metrics (20):  20 × $0.30     = $6.00
  Alarms (15):          15 × $0.10     = $1.50
  Dashboards (2):       2 × $3.00      = $6.00
  Log ingestion (50GB): 50 × $0.50     = $25.00
  Log storage (30d):    50 × $0.03     = $1.50
  ──────────────────────────────────────
  Total:                                 ~$50/month
```

*"$50/month for complete observability of your application. That's nothing compared to the cost of a 2-hour outage."*

---

## Part 11: Interview Questions (10 minutes)

### 🗣️ Top 20 CloudWatch Interview Questions

1. **What is CloudWatch?**
   → AWS's monitoring and observability service. It collects metrics, logs, and events, and triggers actions based on conditions.

2. **What's the default EC2 metric interval?**
   → 5 minutes (standard). Enable Detailed Monitoring for 1 minute.

3. **Does EC2 report memory metrics by default?**
   → No! You need the CloudWatch Agent for memory and disk space metrics.

4. **What are the three alarm states?**
   → OK, ALARM, INSUFFICIENT_DATA.

5. **What's the difference between a metric and a log?**
   → Metric: a number over time (CPU=45%). Log: a text record (ERROR: database timeout).

6. **What is a Metric Filter?**
   → A pattern that scans log events and creates a numeric metric. Example: count occurrences of "ERROR" in logs.

7. **What statistics are available for metrics?**
   → Average, Sum, Minimum, Maximum, SampleCount, and Percentiles (p50, p95, p99).

8. **Why use p99 instead of Average for latency?**
   → Average hides outliers. p99 shows the worst 1% experience. If p99 latency is 5 seconds, 1 in 100 users waits 5 seconds — but the average might look fine at 100ms.

9. **What is a composite alarm?**
   → An alarm that triggers based on multiple other alarms combined with AND/OR logic. Reduces false positives.

10. **How do you get application logs from EC2 to CloudWatch?**
    → Install the CloudWatch Agent. Configure it to tail your log files and send them to a CloudWatch Log Group.

11. **What IAM policy does the CloudWatch Agent need?**
    → `CloudWatchAgentServerPolicy` — allows PutMetricData and PutLogEvents.

12. **What is CloudWatch Logs Insights?**
    → A query language for searching and analyzing logs. SQL-like syntax: `fields`, `filter`, `stats`, `sort`.

13. **What is EventBridge?**
    → An event bus that routes events from AWS services to targets (Lambda, SNS, SQS). Formerly called CloudWatch Events.

14. **Can you create alarms on custom metrics?**
    → Yes. Publish your metric with `PutMetricData`, then create an alarm on it — exactly like built-in metrics.

15. **What is the Embedded Metric Format?**
    → A JSON format you print to stdout (especially in Lambda). CloudWatch automatically extracts metrics from the logs — no API calls needed.

16. **How long does CloudWatch keep metrics?**
    → Data points with period < 60s: 3 hours. 1-min: 15 days. 5-min: 63 days. 1-hour: 455 days (15 months).

17. **What is CloudWatch Synthetics?**
    → Automated scripts (canaries) that run on a schedule to test your endpoints. Like a robot user checking if your website is working every 5 minutes.

18. **What is CloudWatch Contributor Insights?**
    → Identifies the top contributors to a metric. Example: "Which IP addresses are generating the most 5xx errors?"

19. **Can CloudWatch monitor on-premises servers?**
    → Yes. Install the CloudWatch Agent on any server (Linux/Windows). It sends metrics and logs to CloudWatch.

20. **What is a CloudWatch Anomaly Detection?**
    → Machine learning that creates a "normal band" for your metric. If the metric goes outside the band, it's anomalous. No need to set static thresholds.

---

# SECTION: HANDS-ON LABS

## 🟢 Lab 1: BASIC — EC2 Monitoring + First Alarm (20 minutes)

### Step 1: Enable Detailed Monitoring on EC2

1. **EC2 Console** → Select your StreamFlix instance
2. **Actions** → **Monitor and troubleshoot** → **Manage detailed monitoring**
3. Check **Enable** → **Save**

*"Now metrics arrive every 1 minute instead of 5."*

### Step 2: View Built-In Metrics

1. **CloudWatch Console** → **Metrics** → **All metrics**
2. Select **EC2** → **Per-Instance Metrics**
3. Search for your instance ID
4. Check `CPUUtilization` → See the graph appear

*"This is your CPU over time. Notice the 5-minute gaps before detailed monitoring and 1-minute resolution after."*

### Step 3: Create Your First Alarm

1. **CloudWatch** → **Alarms** → **Create alarm**
2. **Select metric:**
   - EC2 → Per-Instance Metrics
   - Find `CPUUtilization` for your instance → **Select**
3. **Conditions:**
   - Statistic: **Average**
   - Period: **1 minute**
   - Threshold type: **Static**
   - Whenever CPUUtilization is: **Greater than** `80`
4. **Actions:**
   - In Alarm: → **Create new SNS topic**
   - Topic name: `streamflix-alerts`
   - Email: your email address
   - **Create topic**
5. **Name:** `StreamFlix-High-CPU`
6. **Create alarm**

7. **CHECK YOUR EMAIL** → Confirm the SNS subscription!

### Step 4: Trigger the Alarm

SSH into your EC2 and stress the CPU:

```bash
# Install stress tool
sudo yum install -y stress

# Stress CPU for 3 minutes (4 CPUs at 100%)
stress --cpu 4 --timeout 180
```

### Step 5: Watch the Alarm Fire

1. Go to **CloudWatch** → **Alarms**
2. Watch `StreamFlix-High-CPU` change: `OK` → `INSUFFICIENT_DATA` → `ALARM` 🔴
3. Check your email — you should receive the SNS notification!
4. After `stress` ends, watch the alarm return to `OK` 🟢

```bash
# Verify from CLI
aws cloudwatch describe-alarms --alarm-names "StreamFlix-High-CPU" \
  --query 'MetricAlarms[0].StateValue'
# → "ALARM" (while stress is running)
# → "OK" (after stress ends)
```

---

## 🟡 Lab 2: INTERMEDIATE — CloudWatch Agent + Logs + Metric Filter (30 minutes)

### Step 1: Install CloudWatch Agent

SSH into EC2:

```bash
# Install
sudo yum install -y amazon-cloudwatch-agent

# Verify
amazon-cloudwatch-agent-ctl -a status
```

### Step 2: Create IAM Role (if not already done)

1. **IAM** → **Roles** → **Create role**
2. Trusted entity: **EC2**
3. Attach policies:
   - `CloudWatchAgentServerPolicy`
   - `AmazonSSMManagedInstanceCore`
4. Name: `EC2-CloudWatch-Role`
5. Attach to your EC2: **EC2** → Select instance → **Actions** → **Security** → **Modify IAM role** → Select `EC2-CloudWatch-Role`

### Step 3: Configure the Agent

```bash
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "StreamFlix/Custom",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/streamflix/nginx/access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/streamflix/nginx/error",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
EOF
```

### Step 4: Start the Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Verify it's running
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
# → Should show "status": "running"
```

### Step 5: See Memory and Disk Metrics

1. **CloudWatch** → **Metrics** → **All metrics**
2. Look for namespace **StreamFlix/Custom**
3. You'll see `mem_used_percent` and `disk_used_percent`!

*"These metrics NEVER existed before. Without the agent, CloudWatch had no idea what your memory usage was."*

### Step 6: View Nginx Logs in CloudWatch

1. **CloudWatch** → **Logs** → **Log groups**
2. Click `/streamflix/nginx/access`
3. Click the log stream (your instance ID)
4. You'll see nginx access logs streaming in real-time:

```
10.0.1.1 - - [18/Apr/2024:10:30:45 +0000] "GET / HTTP/1.1" 200 54151 "-" "Mozilla/5.0..."
10.0.1.1 - - [18/Apr/2024:10:30:46 +0000] "GET /styles.css HTTP/1.1" 200 32440 ...
```

### Step 7: Create a Metric Filter (Count 404 Errors)

1. **CloudWatch** → **Logs** → **Log groups** → `/streamflix/nginx/access`
2. Click **Metric filters** tab → **Create metric filter**
3. **Filter pattern:** `[ip, dash, user, timestamp, request, status_code = 404, size]`
4. **Test:** Click "Test pattern" to verify it matches 404 lines
5. **Assign metric:**
   - Filter name: `404-Errors`
   - Namespace: `StreamFlix/Nginx`
   - Metric name: `404ErrorCount`
   - Metric value: `1`
   - Default value: `0`
6. **Create metric filter**

### Step 8: Create Alarm on 404 Metric

1. **CloudWatch** → **Alarms** → **Create alarm**
2. Select metric: `StreamFlix/Nginx` → `404ErrorCount`
3. Threshold: **Sum > 20** in **5 minutes**
4. Action: SNS → `streamflix-alerts`
5. Name: `StreamFlix-Too-Many-404s`
6. Create alarm

### Step 9: Generate 404s to Trigger

```bash
# Hit non-existent pages
for i in $(seq 1 25); do
  curl -s -o /dev/null "http://app.sskdevops.in/nonexistent-page-$i"
done
echo "Sent 25 requests to non-existent pages — check alarm in 5 minutes"
```

---

## 🔴 Lab 3: ADVANCED — Full Observability Dashboard + Anomaly Detection + EventBridge (40 minutes)

### Step 1: Create a Production Dashboard

1. **CloudWatch** → **Dashboards** → **Create dashboard**
2. Name: `StreamFlix-Production`

### Step 2: Add Widgets (Build this exact layout)

**Row 1: Alarm Status**
1. Add widget → **Alarm status** → Select all your alarms → Create

**Row 2: Infrastructure**
2. Add widget → **Line chart** → EC2 `CPUUtilization` → Period: 1 min
3. Add widget → **Line chart** → `StreamFlix/Custom` → `mem_used_percent`
4. Add widget → **Line chart** → `StreamFlix/Custom` → `disk_used_percent`

**Row 3: Application (if ALB exists)**
5. Add widget → **Number** → ALB `RequestCount` → Statistic: Sum
6. Add widget → **Line chart** → ALB `TargetResponseTime` → Statistic: p99
7. Add widget → **Line chart** → ALB `HTTPCode_Target_5XX_Count`

**Row 4: Errors**
8. Add widget → **Line chart** → `StreamFlix/Nginx` → `404ErrorCount`
9. Add widget → **Log** → Log group: `/streamflix/nginx/error` → Recent entries

10. **Save dashboard**

### Step 3: Enable Anomaly Detection

1. **CloudWatch** → **Metrics** → EC2 → `CPUUtilization`
2. Click the **graphed metric** tab
3. Under "Actions" column → Click the **anomaly detection icon** (bell with graph)
4. CloudWatch trains a model on 2 weeks of historical data
5. A **gray band** appears on the graph showing the "normal" range
6. Create an alarm: **Outside of the band** → SNS notification

*"If your CPU is normally 20-40% and suddenly jumps to 70%, CloudWatch knows that's abnormal — even though 70% is below a static 80% threshold. Anomaly detection catches unusual PATTERNS, not just high values."*

### Step 4: Create EventBridge Rule — Alert on Instance Stop

1. **EventBridge** → **Rules** → **Create rule**
2. Name: `EC2-Stopped-Alert`
3. Event bus: `default`
4. Rule type: **Rule with an event pattern**

5. **Event pattern:**
   - AWS service: **EC2**
   - Event type: **EC2 Instance State-change Notification**
   - Specific state(s): `stopped`, `terminated`

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped", "terminated"]
  }
}
```

6. **Target:**
   - SNS topic → `streamflix-alerts`
   - (Or Lambda if you want custom formatting)

7. **Create rule**

### Step 5: Create EventBridge Rule — Scheduled Cleanup

1. **EventBridge** → **Rules** → **Create rule**
2. Name: `Nightly-Dev-Shutdown`
3. Rule type: **Schedule**
4. Schedule expression: `cron(30 13 ? * MON-FRI *)` (7 PM IST = 1:30 PM UTC)

5. **Target:** Lambda function (create a simple one):

```python
import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    
    # Find all running instances tagged Environment=Dev
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Environment', 'Values': ['Dev']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    
    instance_ids = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])
    
    if instance_ids:
        ec2.stop_instances(InstanceIds=instance_ids)
        return f"Stopped {len(instance_ids)} Dev instances: {instance_ids}"
    
    return "No Dev instances running"
```

6. **Create rule**

*"Every weekday at 7 PM IST, this automatically stops all Dev instances. Saves money without anyone remembering to do it."*

### Step 6: Logs Insights Queries

1. **CloudWatch** → **Logs Insights**
2. Select log group: `/streamflix/nginx/access`
3. Run these queries:

```sql
-- Top 10 most visited pages
fields @timestamp, @message
| parse @message '* - - * "* * *" * *' as ip, time, method, path, protocol, status, size
| stats count(*) as hits by path
| sort hits desc
| limit 10
```

```sql
-- Requests per minute over time
fields @timestamp
| stats count(*) as requestCount by bin(1m)
| sort @timestamp asc
```

```sql
-- All 5xx errors with full details
fields @timestamp, @message
| parse @message '* - - * "* * *" * *' as ip, time, method, path, protocol, status, size
| filter status like /5\d\d/
| sort @timestamp desc
| limit 20
```

```sql
-- Top IPs by request count (find potential abuse)
fields @timestamp, @message
| parse @message '* - - *' as ip, rest
| stats count(*) as requests by ip
| sort requests desc
| limit 10
```

---

## Cleanup

### Delete Resources to Stop Charges:

```bash
# 1. Stop CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop

# 2. Delete alarms
aws cloudwatch delete-alarms --alarm-names \
  "StreamFlix-High-CPU" \
  "StreamFlix-Too-Many-404s"

# 3. Delete dashboard
aws cloudwatch delete-dashboards --dashboard-names "StreamFlix-Production"

# 4. Delete log groups
aws logs delete-log-group --log-group-name "/streamflix/nginx/access"
aws logs delete-log-group --log-group-name "/streamflix/nginx/error"

# 5. Delete EventBridge rules
# Console: EventBridge → Rules → Select → Delete

# 6. Delete SNS topic
# Console: SNS → Topics → streamflix-alerts → Delete
```

---

## Summary: What Each Lab Teaches

| Lab | Level | Duration | Concepts |
|-----|-------|----------|----------|
| 🟢 **Lab 1** | Basic | 20 min | Detailed monitoring, view metrics, first alarm, SNS notification, stress test |
| 🟡 **Lab 2** | Intermediate | 30 min | CW Agent install, memory/disk metrics, log shipping, metric filters, alarm on log patterns |
| 🔴 **Lab 3** | Advanced | 40 min | Dashboard design, anomaly detection, EventBridge rules (event + schedule), Logs Insights queries, auto-shutdown Lambda |

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1: Why Monitoring | 10 min |
| Part 2: Metrics | 20 min |
| Part 3: Statistics & Periods | 10 min |
| Part 4: Alarms | 20 min |
| Part 5: Logs | 20 min |
| **☕ BREAK** | **10 min** |
| Part 6: CloudWatch Agent | 15 min |
| Part 7: Custom Metrics | 10 min |
| Part 8: Dashboards | 10 min |
| Part 9: EventBridge | 15 min |
| Part 10: Pricing | 5 min |
| Part 11: Interview Qs | 10 min |
| 🟢 Lab 1: Basic | 20 min |
| 🟡 Lab 2: Intermediate | 30 min |
| 🔴 Lab 3: Advanced | 40 min |
| **Total** | **~3.5 hours** |

> **Trainer tip:** Take the break after Logs (Part 5). The first half is "watching" (metrics, alarms, logs). The second half is "acting" (agent, custom metrics, dashboards, events). Labs are the exciting part — save energy for them.

> **Trainer tip:** Lab 1 is the "wow moment" — students see the alarm fire and receive the email. Make sure every student has confirmed their SNS email subscription BEFORE running the stress test. If they don't confirm, they won't get the email and the demo falls flat.
