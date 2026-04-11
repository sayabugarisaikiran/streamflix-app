# AWS Systems Manager (SSM) — Complete Teaching Script

> **For the trainer:** This is your word-for-word classroom script. Sections marked 🗣️ are what you SAY. Sections marked 🖥️ are what you DO on screen. Sections marked ❓ are questions to ask students.

---

## Pre-Lab Setup (Do This BEFORE Class)

> **Trainer prep:** Launch 2 EC2 instances (Amazon Linux 2023) in the default VPC. One will be your "web server," the other your "app server." **Do NOT assign key pairs.** This is intentional — you'll show students they can access instances WITHOUT SSH keys using SSM. Ensure both instances have a public subnet with internet access (or a VPC endpoint for SSM — covered later). Attach the `AmazonSSMManagedInstanceCore` IAM role.

### Quick Setup Checklist

```bash
# 1. Create an IAM Role for EC2 with SSM access
#    Trust policy: ec2.amazonaws.com
#    Attached policy: AmazonSSMManagedInstanceCore

# 2. Launch EC2 instances (Amazon Linux 2023)
#    - Instance 1: Name = "web-server"
#    - Instance 2: Name = "app-server"
#    - IAM Role: the role you just created
#    - Key pair: NONE (this is intentional!)
#    - Security Group: NO inbound SSH (port 22) rule needed!

# 3. Wait 2-3 minutes for SSM agent to register
```

---

## Transition from Previous Topic

### 🗣️ Bridge

*"Alright, so far we've been launching EC2 instances, connecting to them using SSH and key pairs. Let me ask you something — how many of you have lost a key pair file? Or forgotten which key pair goes with which instance? Or struggled to SSH into a private subnet instance?"*

*"Now imagine you're managing 200 servers. You need to install a security patch on ALL of them. Are you going to SSH into each one, one by one? That's 200 terminals, 200 key pair files, 200 manual commands. You'd be done next week."*

*"This is the problem AWS Systems Manager solves. And I'm going to blow your mind today."*

---

## Part 1: What Problem Does SSM Solve? (15 minutes)

### 🗣️ Opening — The Hospital Analogy

*"Imagine you're the chief doctor of a hospital with 200 patients. Each patient needs daily check-ups, medications, and sometimes surgery. How would you manage this?"*

- *"Option A: Visit each patient individually, check their chart, give them medicine manually. Time? 200 × 15 minutes = 50 hours. Impossible."*
- *"Option B: You have a CENTRAL SYSTEM — a hospital management dashboard. From one screen, you can see every patient's vitals, push prescriptions to all patients at once, get alerts when someone's condition worsens, and maintain their records in one place."*

*"Your EC2 instances are the patients. SSH is Option A — manual, one-at-a-time. AWS Systems Manager is Option B — centralized, automated, scalable."*

---

### 🗣️ What is AWS Systems Manager?

*"AWS Systems Manager — usually called SSM (from its old name: Simple Systems Manager) — is a FREE service that gives you a centralized dashboard to manage your EC2 instances and on-premises servers."*

*"Here's what SSM lets you do — ALL from one console, without SSH, without key pairs, without opening port 22:"*

| Capability | What It Does | Old Way (Without SSM) |
|-----------|-------------|----------------------|
| **Session Manager** | Terminal access to any instance | SSH + key pairs + port 22 open |
| **Run Command** | Execute commands on 1 or 1000 instances | SSH into each one manually |
| **Parameter Store** | Store secrets, config values | Hardcode in app or use .env files |
| **Patch Manager** | Patch OS across all instances | SSH + `yum update` on each one |
| **State Manager** | Ensure instances stay in desired state | Manual scripts + cron jobs |
| **Inventory** | Track installed software on all instances | SSH + run commands + spreadsheet |
| **Maintenance Windows** | Schedule operations during off-hours | Manual scheduling + cron |
| **Automation** | Run multi-step workflows | Custom scripts, Lambda functions |

### ❓ Ask Students:

*"Quick — what port does SSH use?"*

*"Answer: Port 22. And every security team hates having port 22 open to the internet. It's the #1 target for brute-force attacks. With SSM Session Manager, port 22 can be COMPLETELY CLOSED. No SSH, no key pairs, no inbound rules. Think about how much that simplifies your security posture."*

---

### 🗣️ How Does SSM Work? — The Agent Model

*"SSM uses an AGENT model. Let me draw this:"*

```
                    AWS Systems Manager Service (Managed by AWS)
                              │
                    ┌─────────┼─────────┐
                    │         │         │
                    ▼         ▼         ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐
              │ SSM Agent│ │ SSM Agent│ │ SSM Agent│
              │ (runs on │ │ (runs on │ │ (runs on │
              │  EC2 #1) │ │  EC2 #2) │ │  EC2 #3) │
              └──────────┘ └──────────┘ └──────────┘
                    ↑
                    │
              The agent CALLS OUT to SSM
              (outbound HTTPS on port 443)
              NOT inbound — no ports to open!
```

*"Pay very close attention here. The SSM Agent runs ON your instance. It CALLS OUT to the SSM service over HTTPS (port 443) — outbound traffic. The SSM service NEVER calls IN to your instance. This is why you don't need port 22 open. The agent polls SSM saying 'Hey, got anything for me?' and SSM responds with commands."*

### 🗣️ Three Requirements for SSM to Work

*"For SSM to manage your instance, THREE things must be true:"*

```
Requirement 1: SSM Agent must be INSTALLED and RUNNING
               ✅ Pre-installed on Amazon Linux 2, Amazon Linux 2023, 
                  Ubuntu 16.04+, Windows Server 2016+
               ❌ NOT pre-installed on RHEL, CentOS, Debian, SUSE
                  → You must install it manually

Requirement 2: Instance must have an IAM ROLE with SSM permissions
               → Attach policy: AmazonSSMManagedInstanceCore
               → This allows the agent to talk to the SSM service

Requirement 3: Instance must have NETWORK connectivity to SSM endpoints
               → Option A: Instance in public subnet with internet access (IGW)
               → Option B: NAT Gateway in private subnet
               → Option C: VPC Endpoints for SSM (most secure, no internet needed)
```

### ❓ Ask Students:

*"I launched an EC2 instance with Amazon Linux 2023 in a public subnet. I attached the SSM role. But the instance doesn't show up in SSM Fleet Manager. What could be wrong?"*

*"Possible answers:"*
- *"The Security Group is blocking outbound HTTPS (port 443). SSM Agent can't reach the SSM service."*
- *"The IAM role doesn't have the right policy. Check it's `AmazonSSMManagedInstanceCore`, not some custom policy."*
- *"The SSM Agent isn't running. SSH in (temporarily) and run `sudo systemctl status amazon-ssm-agent`."*
- *"You're looking in the wrong REGION. SSM is regional — the console shows instances in the selected region only."*

---

## Part 2: Session Manager — Never SSH Again (15 minutes)

### 🗣️ What is Session Manager?

*"Session Manager is the SSH killer. It gives you a browser-based terminal to your instance — no SSH, no key pairs, no bastion hosts, no port 22."*

```
Traditional SSH:
  You → Internet → Port 22 → Security Group → EC2
  Needs: Key pair, port 22 open, public IP or bastion host

Session Manager:
  You → AWS Console → SSM Service → SSM Agent → EC2
  Needs: IAM role, IAM permissions, THAT'S IT.
  No keys, no open ports, no bastion host.
```

### 🗣️ Why Session Manager is Superior to SSH

| Feature | SSH | Session Manager |
|---------|-----|-----------------|
| Port 22 open? | ✅ Required | ❌ Not needed |
| Key pair file? | ✅ Required | ❌ Not needed |
| Public IP needed? | ✅ Yes (or bastion) | ❌ No (works with VPC endpoints) |
| Session logging? | ❌ Not built-in | ✅ Logged to S3/CloudWatch |
| Who connected? | Unknown (just key) | ✅ IAM user identity tracked |
| Audit trail? | ❌ None | ✅ Full CloudTrail audit |
| Bastion host? | ✅ Often needed | ❌ Never needed |
| Cost? | Bastion = ~$15/month | ✅ FREE |

*"Let me emphasize the LOGGING. With SSH, if a developer connects to your production server and deletes a database, good luck figuring out who did it. With Session Manager, EVERY session is logged — who connected, when, from which IAM user, and every single command they typed. That's sent to S3 or CloudWatch. This is GOLD for compliance (SOC2, HIPAA, PCI-DSS)."*

### ❓ Ask Students:

*"Your security team says: 'No more SSH. Close port 22 on all servers.' How do you manage the servers now?"*

*"Answer: Use SSM Session Manager. Close port 22, remove all SSH key pairs from instances. Administrators use the AWS Console or AWS CLI to open sessions. All access is controlled by IAM policies and all sessions are logged."*

---

### 🖥️ Lab 1: Connect to EC2 Using Session Manager (Console)

*"Let me prove this works. Remember — our instances have NO key pair and NO port 22 open."*

**Step 1: Open Fleet Manager**
1. Go to **AWS Console** → **Systems Manager** → **Fleet Manager** (left sidebar)
2. *"See both instances? `web-server` and `app-server`. Both show 'SSM Agent ping status: Online.' This means the agent is running and has registered with SSM."*

**Step 2: Start a Session**
1. Click on `web-server` → **Node actions** → **Start session**
2. A browser-based terminal opens
3. *"Look at this — I'm INSIDE the EC2 instance. No SSH. No key pair. No port 22. Let me prove it:"*

```bash
# Who am I?
whoami
# → ssm-user

# What instance is this?
curl http://169.254.169.254/latest/meta-data/instance-id
# → i-0abc123def456

# What's the hostname?
hostname
# → ip-10-0-1-42

# Can I run commands as root?
sudo su -
whoami
# → root

# Check if port 22 is even open
sudo ss -tlnp | grep :22
# → sshd is listening, but Security Group blocks all inbound on 22!
# Nobody from outside can reach it. We're in via SSM.
```

*"Questions? No? Good. You just connected to a server WITHOUT SSH. Your security team is going to love you."*

---

### 🖥️ Lab 2: Connect Using AWS CLI (Terminal)

*"Session Manager also works from your local terminal — not just the console:"*

```bash
# Install the Session Manager plugin first (one-time setup)
# macOS:
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin

# Verify installation
session-manager-plugin --version

# Start a session (replace with your instance ID)
aws ssm start-session --target i-0abc123def456 --region us-east-1

# You're now in the instance terminal!
# Type commands as usual. Type 'exit' to end the session.
```

*"This is how DevOps engineers connect in real companies. No VPN to the office, no bastion host, no key pairs. Just `aws ssm start-session` and you're in."*

---

### 🖥️ Lab 3: Enable Session Logging

*"Let's set up session logging so every keystroke is recorded:"*

1. Go to **Systems Manager** → **Session Manager** → **Preferences** → **Edit**
2. **S3 logging:**
   - ✅ Enable
   - Bucket: `my-ssm-session-logs` (create this bucket first)
   - Prefix: `session-logs/`
3. **CloudWatch logging:**
   - ✅ Enable
   - Log group: `/aws/ssm/sessions`
4. Click **Save**

*"Now open a new session and type some commands. Then go to S3 → your bucket. You'll see a log file with EVERY command that was typed. Your compliance auditor will cry tears of joy."*

---

## Part 3: Run Command — Execute Everywhere (20 minutes)

### 🗣️ What is Run Command?

*"Session Manager gives you a terminal to ONE instance. Run Command lets you execute commands on MANY instances simultaneously — without connecting to any of them."*

```
Run Command:
  You → "Run 'yum update -y' on ALL instances tagged Environment=Production"
  SSM → Sends command to 50 instances simultaneously
  Each SSM Agent → Executes the command
  Results → Sent back to SSM Console
  
  Time taken: ~30 seconds for ALL 50 instances
  Traditional SSH: 50 instances × 3 minutes each = 2.5 HOURS
```

### 🗣️ How Run Command Works

*"Run Command uses DOCUMENTS. An SSM Document is a predefined script — like a recipe. AWS provides hundreds of them, or you can write your own."*

```
SSM Document = A set of instructions
             = "Run this shell script"
             = "Install this package"
             = "Configure this setting"

Popular AWS-managed Documents:
├── AWS-RunShellScript      → Run any Linux shell command
├── AWS-RunPowerShellScript → Run any Windows PowerShell command
├── AWS-InstallApplication  → Install .msi or .rpm packages
├── AWS-ConfigureAWSPackage → Install AWS agents (CloudWatch, Inspector)
├── AWS-UpdateSSMAgent      → Update the SSM Agent itself
├── AWS-RunPatchBaseline    → Apply OS patches
└── AWS-ApplyAnsiblePlaybooks → Run Ansible playbooks!
```

### 🗣️ Targeting — Who Gets the Command?

*"You can target instances in three ways:"*

| Method | Example | Use Case |
|--------|---------|----------|
| **Instance IDs** | `i-0abc123, i-0def456` | Specific instances |
| **Tags** | `Environment=Production` | All prod servers |
| **Resource Groups** | `MyWebServers` | Logical groups |

*"Tags are the most powerful. If you tagged all your web servers with `Role=WebServer`, you can run a command on ALL of them with one click. This is why tagging is so important in AWS."*

### 🗣️ Rate Control — Don't Crash Everything

*"Imagine you run `yum update -y` on 200 servers simultaneously. All 200 start downloading packages at the same time. Your NAT Gateway bandwidth? Saturated. Your servers? All rebooting at once. Your users? Just saw your entire application go down."*

*"Run Command has two controls for this:"*

```
Concurrency: How many instances run the command AT THE SAME TIME
  → "Run on 10 instances at a time" or "Run on 20% at a time"

Error Threshold: How many can FAIL before stopping everything
  → "If 5 instances fail, STOP the entire operation"
  
Example:
  200 instances
  Concurrency: 10 (10 at a time)
  Error threshold: 5
  
  Batch 1: Instances 1-10    → 10 succeed ✓
  Batch 2: Instances 11-20   → 10 succeed ✓
  Batch 3: Instances 21-30   → 3 fail ✗ (total failures: 3)
  Batch 4: Instances 31-40   → 2 fail ✗ (total failures: 5) → STOP!
  Remaining: Instances 41-200 → NOT executed (safety stop)
```

*"This is how mature operations teams roll out changes: slowly, with automatic rollback if things go wrong."*

---

### 🖥️ Lab 4: Run Command — Install Nginx on All Instances (Console)

**Step 1: Open Run Command**
1. Go to **Systems Manager** → **Run Command** → **Run command**

**Step 2: Choose Document**
1. In the search bar, type `AWS-RunShellScript`
2. Select **AWS-RunShellScript**

**Step 3: Configure**
1. **Command parameters:**
```bash
#!/bin/bash
echo "=== Starting Nginx Installation ==="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Timestamp: $(date)"

# Install nginx
sudo dnf install -y nginx

# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify
sudo systemctl status nginx
echo "=== Nginx Installation Complete ==="
```

2. **Targets:** Select **Choose instances manually** → Select BOTH `web-server` and `app-server`
   - *"OR you could select 'Specify instance tags' and use a tag like `Environment=Lab`. That's the scalable way."*

3. **Rate control:**
   - Concurrency: `1` (one at a time — safe for a lab)
   - Error threshold: `1`

4. **Output options:**
   - ✅ Enable writing to S3 (optional)
   - ✅ CloudWatch output

5. Click **Run**

**Step 4: Watch the Execution**
*"Watch the status change: Pending → In Progress → Success"*
*"Click on any instance ID to see the command output — you'll see the nginx installation logs."*

**Step 5: Verify**
```bash
# Open Session Manager to web-server
curl http://localhost
# → Welcome to nginx!

# Or from your browser (if Security Group allows port 80)
# http://<EC2-PUBLIC-IP>
```

*"We just installed nginx on TWO servers with ONE command, without SSH-ing into either of them. Imagine doing this across 200 servers. THAT is the power of Run Command."*

---

### 🖥️ Lab 5: Run Command — Using AWS CLI

*"Let's do the same thing from the CLI:"*

```bash
# Run a shell command on instances by tag
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=web-server,app-server" \
  --parameters 'commands=["hostname","uptime","free -m","df -h"]' \
  --comment "Check system health" \
  --region us-east-1

# You get back a command ID:
# → "CommandId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

# Check the status and output:
aws ssm list-command-invocations \
  --command-id "a1b2c3d4-e5f6-7890-abcd-ef1234567890" \
  --details \
  --region us-east-1

# Output shows: hostname, uptime, memory, disk usage for EACH instance
```

*"In CI/CD pipelines, you use the CLI version. Your Jenkins/GitHub Actions pipeline can run commands on production servers without storing SSH keys in your CI system. That eliminates a HUGE security risk."*

---

### 🖥️ Lab 6: Run Command — Get System Info from All Instances

*"Let's build a practical health check script:"*

```bash
# From Run Command console, use AWS-RunShellScript with:
#!/bin/bash
echo "=========================================="
echo "SYSTEM HEALTH REPORT"
echo "=========================================="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Private IP:  $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "Public IP:   $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Region:      $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
echo "------------------------------------------"
echo "OS Info:"
cat /etc/os-release | head -3
echo "------------------------------------------"
echo "Uptime:"
uptime
echo "------------------------------------------"
echo "Memory:"
free -h
echo "------------------------------------------"
echo "Disk:"
df -h /
echo "------------------------------------------"
echo "Running Services:"
systemctl list-units --type=service --state=running | head -15
echo "=========================================="
```

*"Run this on both instances. Click the output — you get a full health report from every server. This is what operations teams use for daily health checks. Automated, centralized, no SSH required."*

---

## Part 4: Parameter Store — Your Secret Vault (20 minutes)

### 🗣️ What is Parameter Store?

*"Every application needs configuration: database passwords, API keys, endpoint URLs, feature flags. Where do you store them?"*

```
❌ Bad practices:
  → Hardcode in source code:     DB_PASSWORD = "mypassword123"
  → Commit .env files to Git:    .env → password=mypassword123
  → Store in EC2 user data:      Visible in instance metadata
  → Pass as environment vars:    Visible in process list

✅ Good practice:
  → AWS Systems Manager Parameter Store
  → Centralized, encrypted, versioned, access-controlled
```

*"Parameter Store is a key-value store for configuration data and secrets. It's FREE for standard parameters (up to 10,000). Every value is stored securely. Secrets can be encrypted with KMS."*

### 🗣️ Parameter Types

| Type | What It Stores | Encryption | Example |
|------|---------------|------------|---------|
| **String** | Plain text | No | `/app/config/environment = production` |
| **StringList** | Comma-separated values | No | `/app/config/regions = us-east-1,eu-west-1` |
| **SecureString** | Sensitive data | ✅ KMS encrypted | `/app/secrets/db-password = MyS3cretP@ss!` |

*"Always use SecureString for passwords, API keys, tokens, certificates, and anything sensitive. Standard String for non-sensitive config like URLs, feature flags, and environment names."*

### 🗣️ Parameter Hierarchy — Organize Like a Folder Structure

*"Parameters are organized in a PATH hierarchy, like a filesystem:"*

```
/streamflix/
├── production/
│   ├── db/
│   │   ├── host          = "prod-db.cluster-abc.us-east-1.rds.amazonaws.com"
│   │   ├── port          = "5432"
│   │   ├── username      = "admin"      (SecureString)
│   │   └── password      = "Pr0d!Pass"  (SecureString)
│   ├── redis/
│   │   ├── host          = "prod-redis.abc.cache.amazonaws.com"
│   │   └── port          = "6379"
│   └── api/
│       ├── stripe-key    = "sk_live_..."  (SecureString)
│       └── sendgrid-key  = "SG.abc..."    (SecureString)
├── staging/
│   ├── db/
│   │   ├── host          = "staging-db.cluster-xyz.us-east-1.rds.amazonaws.com"
│   │   ├── password      = "St@g1ngP@ss" (SecureString)
│   ...
└── dev/
    ├── db/
    │   ├── host          = "localhost"
    │   ├── password      = "devpass"     (SecureString)
    ...
```

*"This hierarchy is POWERFUL. You can:"*
- *"Get ALL production DB config in one call: `get-parameters-by-path /streamflix/production/db/`"*
- *"Use IAM to restrict access: 'This EC2 role can only read `/streamflix/production/`'"*
- *"Different environments use different paths — same code, different config."*

### 🗣️ Versioning

*"Every time you update a parameter, SSM keeps the old version:"*

```
/streamflix/production/db/password
  Version 1: "OldPassword123"      (created: Jan 1)
  Version 2: "NewerPassword456"    (created: Feb 15)
  Version 3: "LatestPassword789"   (created: Mar 30)  ← Current

# Get specific version
aws ssm get-parameter --name "/streamflix/production/db/password" --version 2
```

*"This is critical for debugging. If your app breaks after a password rotation, you can instantly see what changed and roll back."*

### ❓ Ask Students:

*"Your developer commits a database password to a Git repository. What should you do IMMEDIATELY?"*

*"Answer: 1) Rotate the password immediately. 2) Store the new password in Parameter Store as SecureString. 3) Update the application to read from Parameter Store instead of a config file. 4) Remove the password from Git history (git filter-branch or BFG). 5) Add `.env` to `.gitignore`. The password is compromised the moment it's in Git — even if you delete the commit, it's in the history."*

---

### 🖥️ Lab 7: Create Parameters (Console)

**Step 1: Create a plain text parameter**
1. Go to **Systems Manager** → **Parameter Store** → **Create parameter**
2. **Name:** `/streamflix/production/app/environment`
3. **Type:** String
4. **Value:** `production`
5. Click **Create parameter**

**Step 2: Create a secret parameter**
1. **Create parameter** again
2. **Name:** `/streamflix/production/db/password`
3. **Type:** SecureString
4. **KMS Key:** `aws/ssm` (default — free)
5. **Value:** `SuperSecretP@ssw0rd!`
6. Click **Create parameter**

**Step 3: Create more parameters for the hierarchy**
```
/streamflix/production/db/host        → String    → "mydb.cluster-abc.us-east-1.rds.amazonaws.com"
/streamflix/production/db/port        → String    → "5432"
/streamflix/production/db/username    → SecureString → "admin"
/streamflix/production/app/log-level  → String    → "info"
/streamflix/production/app/max-connections → String → "100"
```

*"Show students the parameter list. Show them the hierarchy. Click on the SecureString parameter — the value shows as dots. Click 'Show' — it decrypts and shows the value. Without the 'Show' click, even YOU can't see it in the console."*

---

### 🖥️ Lab 8: Read Parameters Using AWS CLI

```bash
# Get a single parameter
aws ssm get-parameter \
  --name "/streamflix/production/app/environment" \
  --region us-east-1
# → { "Parameter": { "Name": "...", "Value": "production", "Type": "String" } }

# Get a SecureString (encrypted — shows encrypted blob)
aws ssm get-parameter \
  --name "/streamflix/production/db/password" \
  --region us-east-1
# → Value shows as encrypted text!

# Get a SecureString (DECRYPTED)
aws ssm get-parameter \
  --name "/streamflix/production/db/password" \
  --with-decryption \
  --region us-east-1
# → Value: "SuperSecretP@ssw0rd!"

# Get ALL parameters under a path
aws ssm get-parameters-by-path \
  --path "/streamflix/production/db" \
  --with-decryption \
  --region us-east-1
# → Returns host, port, username, password — everything under /db/

# Get parameter version history
aws ssm get-parameter-history \
  --name "/streamflix/production/db/password" \
  --region us-east-1
# → Shows all versions with timestamps
```

### ❓ Ask Students:

*"What's the difference between `get-parameter` and `get-parameter` with `--with-decryption`?"*

*"Answer: Without `--with-decryption`, SecureString parameters return the encrypted ciphertext blob. With `--with-decryption`, SSM decrypts the value using KMS and returns the plaintext. For String and StringList parameters, `--with-decryption` has no effect — they're not encrypted."*

---

### 🖥️ Lab 9: Use Parameters in an Application (On EC2)

*"Now let's connect to our web-server using Session Manager and write a script that reads config from Parameter Store:"*

```bash
# Connect via Session Manager first!
# Then run:

# Create a simple Python app that reads from Parameter Store
cat << 'EOF' > /tmp/app.py
import boto3
import json

ssm = boto3.client('ssm', region_name='us-east-1')

# Get all DB config in one call
response = ssm.get_parameters_by_path(
    Path='/streamflix/production/db',
    WithDecryption=True
)

print("=" * 50)
print("APPLICATION CONFIGURATION")
print("=" * 50)
for param in response['Parameters']:
    name = param['Name'].split('/')[-1]  # Get just the key name
    value = param['Value']
    param_type = param['Type']
    if param_type == 'SecureString':
        print(f"  {name}: {'*' * len(value)} (encrypted)")
    else:
        print(f"  {name}: {value}")
print("=" * 50)

# In a real app, you'd use these values:
db_config = {}
for param in response['Parameters']:
    key = param['Name'].split('/')[-1]
    db_config[key] = param['Value']

print(f"\nConnection string: postgresql://{db_config.get('username','?')}:****@{db_config.get('host','?')}:{db_config.get('port','?')}")
EOF

# Install boto3 if not present
pip3 install boto3 -q

# Run it
python3 /tmp/app.py
```

*"See? The application reads its configuration from Parameter Store at runtime. No passwords in code. No .env files. If you rotate the password in Parameter Store, the next time the application reads it, it gets the new value. Zero code changes, zero redeployments."*

---

### 🗣️ Parameter Store vs Secrets Manager

*"Students always ask: 'What's the difference between Parameter Store and Secrets Manager?' Good question."*

| Feature | Parameter Store | Secrets Manager |
|---------|----------------|-----------------|
| **Cost** | FREE (standard) | $0.40/secret/month |
| **Automatic rotation** | ❌ No | ✅ Yes (with Lambda) |
| **Cross-account sharing** | ❌ No | ✅ Yes |
| **Max size** | 8 KB (standard) / 8 KB (advanced) | 64 KB |
| **Throughput** | 40 TPS (standard) / 1000 TPS (advanced) | 10,000 TPS |
| **Use case** | Config values, simple secrets | Database credentials that need auto-rotation |
| **RDS integration** | ❌ Manual | ✅ Native RDS password rotation |

*"Rule of thumb: Start with Parameter Store (it's free). If you need automatic password rotation for RDS databases, use Secrets Manager. Many companies use BOTH — Parameter Store for config, Secrets Manager for DB passwords."*

---

## Part 5: Patch Manager — Keep Everything Updated (15 minutes)

### 🗣️ What is Patch Manager?

*"Every month, Microsoft, Red Hat, Amazon, and Ubuntu release security patches. CVEs (Common Vulnerabilities and Exposures) are discovered constantly. If you don't patch your OS, attackers exploit known vulnerabilities."*

*"Remember the WannaCry ransomware in 2017? It exploited a Windows vulnerability that had been PATCHED by Microsoft two months earlier. Every company that hadn't applied the patch? Crippled. Hospitals couldn't access patient records. Factories shut down."*

*"Patch Manager lets you patch ALL your instances from one place, on a schedule, with testing and approval controls."*

```
Without Patch Manager:
  SSH into 200 servers
  Run "yum update -y" on each
  Hope nothing breaks
  Pray the reboot goes smoothly
  Wonder which servers you missed

With Patch Manager:
  Define a patch baseline (what to patch)
  Create a maintenance window (when to patch)
  Target instances by tags (what to patch)
  Let SSM do the rest
  Review compliance dashboard (what's patched, what's not)
```

### 🗣️ Key Concepts

**1. Patch Baseline**
*"A set of rules defining which patches to install:"*
```
AWS-DefaultPatchBaseline (Amazon Linux 2023):
  → Auto-approve: Security patches rated Critical/Important
  → Auto-approve delay: 7 days after release
  → Rejected patches: None
  
You can create CUSTOM baselines:
  → Only install Security patches (skip enhancements)
  → Wait 14 days before approving (let others test first)
  → Reject specific patches that break your app
```

**2. Patch Group**
*"A TAG on your instances that associates them with a patch baseline:"*
```
Instance tag: PatchGroup = WebServers
Patch baseline: "WebServer-Baseline" → linked to PatchGroup "WebServers"
```

**3. Maintenance Window**
*"A scheduled time when patching happens. You don't want to patch production at 2 PM on a Tuesday."*

---

### 🖥️ Lab 10: Scan for Missing Patches

**Step 1: Run a Patch Scan (Not Install — Just Scan)**
1. Go to **Systems Manager** → **Run Command**
2. Document: `AWS-RunPatchBaseline`
3. **Parameters:**
   - Operation: `Scan` (NOT Install! We're just checking.)
4. **Targets:** Select both instances
5. Click **Run**

**Step 2: View Compliance**
1. Go to **Systems Manager** → **Compliance**
2. *"You'll see each instance with a compliance status: Compliant or Non-Compliant."*
3. Click on a non-compliant instance → See the list of missing patches

*"See this? Instance `web-server` is missing 3 security patches and 5 enhancement patches. We scanned without installing anything. The scan tells you what NEEDS to be done."*

**Step 3: Apply Patches (Install)**
1. Go to **Run Command** again
2. Document: `AWS-RunPatchBaseline`
3. **Parameters:**
   - Operation: `Install` (NOW we're installing)
   - Reboot option: `RebootIfNeeded`
4. **Targets:** Select both instances
5. Click **Run**

*"Now it's installing the patches. Some patches require a reboot — SSM will handle the reboot automatically. After the reboot, the SSM Agent comes back up and reports success."*

---

## Part 6: State Manager — Desired State Configuration (10 minutes)

### 🗣️ What is State Manager?

*"State Manager ensures your instances STAY in a desired state. It's like a continuous loop that checks: 'Is the software installed? Is the config correct? Is the service running?' If anything drifts, it fixes it."*

```
Example:
  State: "Nginx must be installed and running on all web servers"
  
  Day 1: State Manager installs nginx on all web servers ✅
  Day 5: Someone accidentally stops nginx on server-3
  Day 5 (next check): State Manager detects nginx is stopped → restarts it ✅
  Day 10: New instance launches with tag Role=WebServer
  Day 10 (next check): State Manager sees new instance → installs nginx ✅
```

*"This is called 'desired state' or 'configuration drift remediation.' Ansible does this with 'ansible-pull.' Puppet and Chef do this with their agents. SSM State Manager is the AWS-native way."*

---

### 🖥️ Lab 11: Create a State Manager Association

*"Let's ensure the SSM Agent is always updated on all instances:"*

1. Go to **Systems Manager** → **State Manager** → **Create association**
2. **Name:** `UpdateSSMAgent`
3. **Document:** `AWS-UpdateSSMAgent`
4. **Targets:** Choose **All instances** (or use tags)
5. **Schedule:**
   - Schedule type: `Rate expression`
   - Rate: `rate(7 days)` (check every 7 days)
6. Click **Create association**

*"Now every 7 days, SSM will check if the SSM Agent on every instance is up to date. If an update is available, it installs it. If it's already current, nothing happens. This runs forever, even on new instances."*

---

## Part 7: SSM with VPC Endpoints — Private Subnet Access (10 minutes)

### 🗣️ The Private Subnet Problem

*"So far, our instances were in a public subnet with internet access. The SSM Agent could reach the SSM service via the internet. But what about instances in a PRIVATE subnet with NO internet access?"*

```
Public Subnet:
  EC2 → Internet Gateway → Internet → SSM Service ✅

Private Subnet:
  EC2 → No IGW → Can't reach internet → SSM Service ❌
  
Solution: VPC Endpoints (PrivateLink)
  EC2 → VPC Endpoint → SSM Service ✅ (never touches the internet)
```

### 🗣️ Required VPC Endpoints for SSM

*"You need THREE VPC endpoints:"*

| Endpoint | Service | Purpose |
|----------|---------|---------|
| `com.amazonaws.{region}.ssm` | SSM service | Core SSM API |
| `com.amazonaws.{region}.ssmmessages` | Session Manager | Session Manager terminal connections |
| `com.amazonaws.{region}.ec2messages` | EC2 Messages | Run Command message delivery |

*"Optional but recommended:"*

| Endpoint | Purpose |
|----------|---------|
| `com.amazonaws.{region}.kms` | Decrypt SecureString parameters |
| `com.amazonaws.{region}.logs` | Send session logs to CloudWatch |
| `com.amazonaws.{region}.s3` | Send session logs to S3 (Gateway endpoint — free) |

### 🖥️ Lab 12: Create VPC Endpoints for SSM (Demo)

1. Go to **VPC Console** → **Endpoints** → **Create endpoint**
2. **Name:** `ssm-endpoint`
3. **Service:** search for `com.amazonaws.us-east-1.ssm`
4. **VPC:** Select your VPC
5. **Subnets:** Select the private subnets
6. **Security Group:** Create one that allows **inbound HTTPS (443)** from the VPC CIDR
7. **Policy:** Full access
8. Click **Create endpoint**

*"Repeat for `ssmmessages` and `ec2messages`."*

*"Now launch an EC2 instance in the private subnet WITH the SSM role. Give it 2-3 minutes. Check Fleet Manager — it'll show up! Open a Session Manager session — it works! No internet, no NAT Gateway, no bastion host. Pure PrivateLink."*

*"Each VPC endpoint costs about $7.20/month + $0.01/GB data processed. That's cheaper than a NAT Gateway ($32/month + $0.045/GB) and far more secure."*

---

## Part 8: SSM Inventory — Know Your Fleet (5 minutes)

### 🗣️ What is Inventory?

*"Inventory automatically collects metadata from your instances:"*

```
What Inventory Collects:
├── Installed applications (name, version, publisher)
├── AWS components (SSM Agent version, CLI version)
├── Network configuration (IP, MAC, DNS)
├── Windows updates (on Windows instances)
├── Instance details (OS, kernel version, hostname)
├── Services (running?, startup type)
├── Windows roles (on Windows instances)
├── Custom inventory (anything you want to track)
```

*"Use case: Your security team asks 'Which servers are running OpenSSL version 1.0.1?' (because that version has Heartbleed vulnerability). Without Inventory, you SSH into every server and check manually. With Inventory, you query it in 10 seconds."*

### 🖥️ Quick Demo: Enable Inventory

1. Go to **Systems Manager** → **Inventory** → **Setup Inventory**
2. **Targets:** All instances
3. **Schedule:** Every 30 minutes
4. **Parameters:** Select all data types
5. Click **Setup Inventory**

*"Wait 5 minutes, then go to Inventory → look at the dashboard. You can see every installed package, every running service, across all your instances."*

---

## Part 9: Automation — Multi-Step Workflows (10 minutes)

### 🗣️ What is Automation?

*"Automation runbooks are multi-step workflows. Unlike Run Command (single command), Automation can do complex operations with decision logic, approvals, and cross-service actions."*

```
Example: Restart an EC2 Instance Safely
  Step 1: Create AMI backup (snapshot)
  Step 2: Stop the instance
  Step 3: Wait for stop → confirm stopped
  Step 4: Start the instance
  Step 5: Wait for status checks → confirm healthy
  Step 6: Send SNS notification "Instance restarted successfully"
  
  If any step fails → Stop and alert
```

### 🗣️ Popular Automation Runbooks

```
AWS-RestartEC2Instance     — Safely restart with health check
AWS-StopEC2Instance        — Stop with optional backup
AWS-CreateImage            — Create AMI from running instance
AWS-CreateSnapshot         — Create EBS snapshot
AWS-UpdateLinuxAmi         — Golden AMI pipeline: 
                             Launch → Update → Create AMI → Test → Done
AWS-AttachEBSVolume        — Attach, mount, format EBS volume
```

### 🖥️ Lab 13: Run an Automation — Create AMI Backup

1. Go to **Systems Manager** → **Automation** → **Execute automation**
2. Search for `AWS-CreateImage`
3. **Parameters:**
   - InstanceId: Select your `web-server`
   - NoReboot: `true` (don't reboot during image creation)
4. Click **Execute**

*"Watch the steps execute: it creates an AMI from your running instance without rebooting it. Each step shows status: Success, InProgress, or Failed. This is the same workflow you'd build for golden AMI pipelines in production."*

---

## Part 10: SSM Pricing (5 minutes)

### 🗣️ How Much Does SSM Cost?

*"This is the best part:"*

| Feature | Cost |
|---------|------|
| **Session Manager** | ✅ FREE |
| **Run Command** | ✅ FREE |
| **Parameter Store (Standard)** | ✅ FREE (up to 10,000 params) |
| **Parameter Store (Advanced)** | $0.05/param/month |
| **State Manager** | ✅ FREE |
| **Inventory** | ✅ FREE |
| **Patch Manager** | ✅ FREE |
| **Automation** | ✅ FREE (first 100,000 steps/month) |
| **Maintenance Windows** | ✅ FREE |

*"Almost EVERYTHING is free. You're paying for EC2 anyway — SSM is a bonus. The only thing that costs money is Advanced Parameters (more than 10,000 or bigger than 4KB) and on-premises server management ($5/server/month)."*

*"Compare this to third-party tools: Ansible Tower = $13,000/year. Puppet Enterprise = $12,000/year. Chef Automate = $13,700/year. SSM does 80% of what they do, for free."*

---

## Part 11: Best Practices (5 minutes)

### 🗣️ SSM Best Practices

1. **NEVER use SSH again** — Use Session Manager for all interactive access
2. **Tag everything** — Tags are how you target instances in Run Command and Patch Manager
3. **Use Parameter Store** — Never hardcode passwords, API keys, or config values
4. **SecureString for ALL secrets** — Never use plain String for passwords
5. **Enable session logging** — Send to S3 and CloudWatch for audit compliance
6. **Use parameter hierarchies** — Organize by `/{app}/{environment}/{component}/{key}`
7. **Patch regularly** — Set up Patch Manager with maintenance windows
8. **Use rate control** — Never blast commands to all instances simultaneously
9. **Use VPC endpoints** — For private subnets, skip the NAT Gateway
10. **Restrict IAM access** — Control who can start sessions, run commands, and read secrets

---

## Part 12: Interview Questions (5 minutes)

### 🗣️ Top 10 SSM Interview Questions

1. **What is AWS Systems Manager?**
   → A centralized management service for EC2 instances and on-premises servers. Provides Session Manager, Run Command, Parameter Store, Patch Manager, and more.

2. **What are the three requirements for SSM to work on an EC2 instance?**
   → SSM Agent installed & running, IAM role with `AmazonSSMManagedInstanceCore`, network connectivity to SSM endpoints.

3. **How does Session Manager work without port 22?**
   → The SSM Agent makes outbound HTTPS calls (port 443) to the SSM service. No inbound ports needed.

4. **What's the difference between Parameter Store and Secrets Manager?**
   → Parameter Store is free and stores config/secrets. Secrets Manager costs $0.40/secret/month but supports automatic secret rotation and cross-account access.

5. **What is a SecureString parameter?**
   → A parameter encrypted at rest using KMS. Requires `--with-decryption` flag to read the plaintext value.

6. **How do you manage SSM on private subnet instances?**
   → Use VPC Endpoints: `ssm`, `ssmmessages`, and `ec2messages`. No internet access required.

7. **What is a maintenance window?**
   → A scheduled time for running operations (patching, commands). Prevents patching during business hours.

8. **What is Run Command concurrency and error threshold?**
   → Concurrency controls how many instances run simultaneously. Error threshold stops the operation if too many instances fail.

9. **What is State Manager?**
   → Ensures instances stay in a desired configuration. If configuration drifts, State Manager corrects it automatically.

10. **Can SSM manage on-premises servers?**
    → Yes. Install the SSM Agent and register the server as a "Hybrid Activation." Costs $5/server/month.

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1: What SSM Solves | 15 min |
| Part 2: Session Manager | 15 min |
| Part 3: Run Command | 20 min |
| Part 4: Parameter Store | 20 min |
| Part 5: Patch Manager | 15 min |
| Part 6: State Manager | 10 min |
| Part 7: VPC Endpoints | 10 min |
| Part 8: Inventory | 5 min |
| Part 9: Automation | 10 min |
| Part 10: Pricing | 5 min |
| Part 11: Best Practices | 5 min |
| Part 12: Interview Questions | 5 min |
| **Total** | **~2.5 hours** |

> **Trainer tip:** Take a break after Part 4 (Parameter Store). The first half is hands-on access/commands/config, the second half is fleet management (patching, state, automation). Students need a mental break between the two halves.

> **Trainer tip:** The biggest "wow" moment is Lab 1 — connecting without SSH. Spend extra time there. Have students try it themselves in CloudShell. When they see the terminal open without any key pair, it clicks.

> **Trainer tip:** For Lab 9 (Python app reading Parameter Store), if time is short, just demo the CLI commands. The Python code is a bonus for students who know programming.
