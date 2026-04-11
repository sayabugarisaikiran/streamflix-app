# Amazon EBS (Elastic Block Store) — Complete Teaching Script

> **For the trainer:** This is your word-for-word classroom script. Sections marked 🗣️ are what you SAY. Sections marked 🖥️ are what you DO on screen. Sections marked ❓ are questions to ask students.

---

## Pre-Lab Setup (Do This BEFORE Class)

> **Trainer prep:** Launch 1 EC2 instance (Amazon Linux 2023, `t3.micro`) in a public subnet with a key pair OR SSM role (for Session Manager access). This instance will be used for all EBS labs. Ensure the instance has a root volume (default 8 GB gp3). Do NOT create additional EBS volumes — that's part of the live demo.

### Quick Setup Checklist

```bash
# 1. Launch EC2 instance
#    - AMI: Amazon Linux 2023
#    - Instance type: t3.micro
#    - Key pair: Your existing key pair (or use SSM Session Manager)
#    - Root volume: 8 GB, gp3 (default)
#    - Name tag: "ebs-lab-instance"
#    - Region: us-east-1 (N. Virginia)
#    - AZ: us-east-1a (REMEMBER this — EBS is AZ-specific!)

# 2. Note the Instance ID and AZ — you'll need both
```

---

## Transition from Previous Topic

### 🗣️ Bridge

*"Alright, we've learned how to launch EC2 instances, connect to them, and manage them at scale with SSM. But here's something we've been taking for granted — storage."*

*"When you launch an EC2 instance, where does the operating system live? Where does your application data go? Where do database files sit? The answer: EBS — Elastic Block Store. And if you get it wrong, you'll either lose data, overpay, or your application will crawl."*

*"Let me show you exactly how EBS works."*

---

## Part 1: What Problem Does EBS Solve? (15 minutes)

### 🗣️ Opening — The Hard Drive Analogy

*"Everyone here has used a computer. Your laptop has a hard drive or SSD, right? 256 GB, 512 GB, 1 TB. Your OS is on it, your files are on it, your applications are on it."*

*"Now imagine your laptop's hard drive is NOT physically inside your laptop. It's connected over a super-fast network cable. You can't see it or touch it. But it works exactly like a local drive."*

*"That's EBS. It's a NETWORK-ATTACHED STORAGE DRIVE for your EC2 instances."*

```
Traditional Computer:
  [CPU + RAM + SSD] — Everything in one box
  
EC2 with EBS:
  [EC2 Instance: CPU + RAM]  ←── Network ──→  [EBS Volume: Storage]
  ^^ Compute ^^                                ^^ Storage ^^
  Separate! Connected over the network.
```

*"This separation is actually genius. Let me explain why."*

---

### 🗣️ Why Separate Compute and Storage?

*"Having storage separate from compute gives you superpowers:"*

| Benefit | Without EBS (Local Storage) | With EBS |
|---------|---------------------------|----------|
| **Instance dies** | DATA IS GONE FOREVER 💀 | Data survives — reattach to new instance |
| **Need more storage** | Resize the entire machine | Add another EBS volume. Done. |
| **Need faster storage** | Buy a new machine | Change volume type (gp3 → io2). No migration. |
| **Backup** | Manual, complex | Snapshot — 1 click, incremental, stored in S3 |
| **Move data** | Copy files across network (slow) | Detach volume, reattach to another instance |
| **Encryption** | Configure yourself | 1 checkbox. AES-256. Done. |

*"The key insight: your EC2 instance is EPHEMERAL — it can be terminated and replaced. But your DATA is PERSISTENT — it must survive instance failures. EBS gives you persistent, durable storage that lives independently of your instance."*

### ❓ Ask Students:

*"I have an EC2 instance running a MySQL database. The instance crashes and is terminated. Is my database data lost?"*

*"Answer: It depends! If the data was on the ROOT EBS volume and 'Delete on Termination' was set to Yes (the default), then YES, the data is lost when the instance is terminated. If 'Delete on Termination' was set to No, or if the data was on a SEPARATE EBS volume, the data survives. This is why production databases should store data on a SEPARATE EBS volume with 'Delete on Termination' disabled."*

---

### 🗣️ EBS Key Characteristics

*"Write these down — they're interview favorites:"*

```
1. NETWORK DRIVE — Not physically attached. Connected via the network.
   → This means there IS slight latency (microseconds, not milliseconds).
   → But it also means it can be detached and moved to another instance.

2. AZ-LOCKED — An EBS volume is locked to ONE Availability Zone.
   → A volume in us-east-1a CANNOT be attached to an instance in us-east-1b.
   → To move data across AZs: Snapshot → Create volume from snapshot in new AZ.

3. PROVISIONED CAPACITY — You specify the size upfront.
   → 1 GB to 64 TB per volume.
   → You're charged for PROVISIONED size, not USED size.
   → If you provision 100 GB but use only 10 GB, you pay for 100 GB.

4. ONE-TO-ONE (mostly) — One EBS volume attaches to ONE instance at a time.
   → Exception: io1/io2 with Multi-Attach (up to 16 instances — advanced use case).

5. PERSISTENT — Data persists after instance stop/start.
   → Unlike instance store (ephemeral storage), EBS keeps your data.

6. ROOT VOLUME vs DATA VOLUME
   → Root volume: Has the OS. Created automatically with the instance.
   → Data volume: Additional volumes you attach for application data.
```

### 🗣️ EBS vs Instance Store

*"I need to clear up a confusion. EC2 instances can have TWO types of storage:"*

| Feature | EBS Volume | Instance Store |
|---------|-----------|----------------|
| **Persistence** | ✅ Survives stop/start/terminate (if not deleted) | ❌ Data LOST on stop/terminate |
| **Network** | Over network (slight latency) | Physically attached (fastest possible) |
| **Backup** | ✅ Snapshots | ❌ No snapshots |
| **Resize** | ✅ Modify size/type online | ❌ Fixed |
| **Encryption** | ✅ Built-in | ✅ Built-in |
| **Detach/Move** | ✅ Yes | ❌ No |
| **Use case** | Databases, boot volumes, most apps | High-performance temporary cache, scratch data |

*"Instance Store is physically attached NVMe SSD — blazing fast. But if you stop or terminate the instance, ALL data on instance store is WIPED. It's called 'ephemeral' storage. Use it only for temporary data like caches, buffers, and scratch files."*

### ❓ Ask Students:

*"I need the FASTEST possible storage for a temporary cache in my application. The data can be regenerated if lost. Should I use EBS or Instance Store?"*

*"Answer: Instance Store. It's physically attached NVMe — lowest possible latency. And since the data can be regenerated, the ephemeral nature is acceptable."*

---

## Part 2: EBS Volume Types — The Complete Guide (25 minutes)

### 🗣️ Overview

*"Not all EBS volumes are the same. AWS offers FOUR types, designed for different workloads. Think of it like cars — you wouldn't use a family sedan for Formula 1, and you wouldn't use a race car for grocery shopping."*

```
EBS Volume Types:

SSD-Based (Random I/O — databases, boot volumes):
  ├── gp3 / gp2  — General Purpose SSD  (the Honda Civic — reliable, affordable)
  └── io2 / io1  — Provisioned IOPS SSD  (the Ferrari — expensive, blazing fast)

HDD-Based (Sequential I/O — big data, logs, archives):
  ├── st1  — Throughput Optimized HDD  (the cargo truck — moves lots of data)
  └── sc1  — Cold HDD  (the warehouse — cheap, rarely accessed)
```

---

### 🗣️ gp3 — General Purpose SSD (THE DEFAULT)

*"This is your go-to. If you're not sure what to pick, pick gp3. It replaced gp2 in 2020 and is the default for new volumes."*

```
gp3 — General Purpose SSD
━━━━━━━━━━━━━━━━━━━━━━━━━
Size:          1 GiB – 16 TiB
IOPS:          3,000 baseline (included free!)
               Up to 16,000 IOPS (at $0.005/provisioned IOPS above 3,000)
Throughput:    125 MiB/s baseline (included free!)
               Up to 1,000 MiB/s (at $0.04/provisioned MiB/s above 125)
Latency:       ~1 ms (single-digit milliseconds)
Cost:          $0.08/GB/month
Boot volume:   ✅ Yes
Multi-Attach:  ❌ No
```

*"The genius of gp3: you get 3,000 IOPS and 125 MB/s INCLUDED in the base price. With gp2, IOPS scaled with volume size — you had to provision a bigger disk just to get more IOPS. With gp3, IOPS and throughput are INDEPENDENTLY configurable."*

**Use cases:**
- *Boot volumes (OS disk)*
- *Development and test environments*
- *Virtual desktops*
- *Most production applications*
- *Small to medium databases*

### 🗣️ gp2 — General Purpose SSD (Legacy)

*"gp2 is the previous generation. You'll still see it in existing infrastructure."*

```
gp2 — General Purpose SSD (Previous Gen)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Size:          1 GiB – 16 TiB
IOPS:          3 IOPS per GB (baseline)
               Min: 100 IOPS (for volumes < 33.3 GB)
               Max: 16,000 IOPS (at 5,334+ GB)
Throughput:    Up to 250 MiB/s
Burst:         3,000 IOPS burst for volumes < 1 TiB (uses burst credits)
Cost:          $0.10/GB/month ← 25% MORE expensive than gp3!
Boot volume:   ✅ Yes
```

*"Key difference: gp2 IOPS are tied to volume size. Want more IOPS? Pay for a bigger disk."*

```
gp2 IOPS Calculation:
  100 GB → 300 IOPS (100 × 3) — with burst to 3,000
  500 GB → 1,500 IOPS — with burst to 3,000
  1,000 GB → 3,000 IOPS — no burst needed (baseline = max burst)
  5,334 GB → 16,000 IOPS — maximum
```

*"gp2 has 'burst credits.' Small volumes accumulate credits when idle and spend them during bursts. If you run out of credits, IOPS drops to the baseline. This has caused MANY production outages — people provision a small gp2, it works fine during testing (burst credits full), then crashes under sustained production load (credits exhausted)."*

### ❓ Ask Students:

*"I have a 100 GB gp2 volume. My application does 2,500 IOPS consistently. Will it work?"*

*"Answer: Initially yes — burst credits give you 3,000 IOPS. But the baseline is only 300 IOPS (100 × 3). Once burst credits run out (after about 50 minutes), IOPS drops to 300. Your application will slow to a crawl. Solution: Switch to gp3 (3,000 baseline IOPS regardless of size) or increase volume size to 834 GB (834 × 3 = 2,502 IOPS baseline)."*

---

### 🗣️ io2 Block Express / io2 / io1 — Provisioned IOPS SSD

*"This is the Ferrari. You tell AWS exactly how many IOPS you want, and AWS guarantees them. No bursting, no credits, no surprises."*

```
io2 Block Express — Provisioned IOPS SSD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Size:          4 GiB – 64 TiB
IOPS:          Up to 256,000 IOPS (!!!)
Throughput:    Up to 4,000 MiB/s (4 GB/s!!!)
Latency:       Sub-millisecond
IOPS/GB ratio: Up to 1,000 IOPS per GB
Durability:    99.999% (5 nines — 100x better than gp3)
Cost:          $0.125/GB/month + $0.065/provisioned IOPS/month
Boot volume:   ✅ Yes
Multi-Attach:  ✅ Yes (up to 16 instances — io1/io2 only)
```

```
io1 — Provisioned IOPS SSD (Previous Gen)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Size:          4 GiB – 16 TiB
IOPS:          Up to 64,000 IOPS
IOPS/GB ratio: Up to 50 IOPS per GB
Durability:    99.8% – 99.9%
Cost:          $0.125/GB/month + $0.065/provisioned IOPS/month
Multi-Attach:  ✅ Yes
```

*"When to use io2/io1:"*
- *Large production databases (Oracle, SQL Server, PostgreSQL)*
- *Workloads needing guaranteed, consistent IOPS*
- *Databases that need sub-millisecond latency*
- *Applications requiring Multi-Attach (clustered databases)*

*"io2 Block Express is the latest — it's available on R5b, R6i, and Nitro-based instances. It gives you up to 256,000 IOPS and 4 GB/s throughput. That's insane."*

### 🗣️ Multi-Attach (io1/io2 Only)

*"Multi-Attach lets you attach ONE EBS volume to up to 16 EC2 instances simultaneously in the same AZ."*

```
                    ┌──── EC2 Instance 1 ────┐
                    │                        │
EBS io2 Volume ────├──── EC2 Instance 2 ────┤  (All in same AZ)
                    │                        │
                    └──── EC2 Instance 3 ────┘

⚠️ Constraints:
  → All instances must be in the SAME AZ
  → Only io1/io2 volume types
  → Maximum 16 instances
  → Application must handle concurrent writes! (Use cluster-aware filesystem)
  → Linux: Must use cluster filesystem like GFS2 or OCFS2
```

*"Use case: Clustered databases like Oracle RAC that need shared storage across nodes."*

---

### 🗣️ st1 — Throughput Optimized HDD

*"Now we switch from SSD to HDD. HDD can't do random I/O well, but they can push LARGE amounts of sequential data cheaply."*

```
st1 — Throughput Optimized HDD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Size:          125 GiB – 16 TiB
IOPS:          Up to 500 IOPS (low — don't use for databases!)
Throughput:    Up to 500 MiB/s
Cost:          $0.045/GB/month ← 44% cheaper than gp3
Boot volume:   ❌ NO — Cannot be a boot volume!
```

**Use cases:**
- *Big data analytics (Hadoop, Kafka)*
- *Data warehousing*
- *Log processing*
- *Streaming workloads (sequential reads)*

---

### 🗣️ sc1 — Cold HDD

*"The cheapest EBS option. For data you rarely access."*

```
sc1 — Cold HDD
━━━━━━━━━━━━━━
Size:          125 GiB – 16 TiB
IOPS:          Up to 250 IOPS
Throughput:    Up to 250 MiB/s
Cost:          $0.015/GB/month ← CHEAPEST EBS option (81% less than gp3!)
Boot volume:   ❌ NO
```

**Use cases:**
- *Archival data that's accessed a few times per year*
- *Backups that you want online (not in Glacier) but rarely read*
- *Compliance data — must be stored but rarely accessed*

---

### 🗣️ The Complete Comparison Table

| Feature | gp3 | gp2 | io2 | io1 | st1 | sc1 |
|---------|-----|-----|-----|-----|-----|-----|
| **Type** | SSD | SSD | SSD | SSD | HDD | HDD |
| **Max Size** | 16 TiB | 16 TiB | 64 TiB | 16 TiB | 16 TiB | 16 TiB |
| **Max IOPS** | 16,000 | 16,000 | 256,000 | 64,000 | 500 | 250 |
| **Max Throughput** | 1,000 MiB/s | 250 MiB/s | 4,000 MiB/s | 1,000 MiB/s | 500 MiB/s | 250 MiB/s |
| **Cost (GB/mo)** | $0.08 | $0.10 | $0.125 | $0.125 | $0.045 | $0.015 |
| **Boot Volume?** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Multi-Attach?** | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| **Best For** | Most apps | Legacy | Critical DBs | Databases | Big data | Archives |

### 🗣️ Decision Flowchart

```
Need a boot volume?
  ├── Yes → gp3 (default) or io2 (critical production)
  └── No → ↓

Need high IOPS (> 16,000)?
  ├── Yes → io2 Block Express (up to 256,000 IOPS)
  └── No → ↓

Need consistent IOPS with SLA guarantee?
  ├── Yes → io2 / io1
  └── No → ↓

Sequential access pattern? (Big data, logs, streaming)
  ├── Yes → ↓
  │   Accessed frequently?
  │   ├── Yes → st1 ($0.045/GB)
  │   └── No  → sc1 ($0.015/GB)  
  └── No → gp3 (default choice)
```

### ❓ Ask Students:

*"I'm running a PostgreSQL database on EC2. It needs 10,000 IOPS consistently with sub-millisecond latency. Which volume type?"*

*"Answer: gp3 could handle this — it supports up to 16,000 IOPS. But for 'consistent' IOPS with a guarantee and sub-millisecond latency on a production database, io2 is the safer choice. With gp3, your IOPS can vary slightly. With io2, AWS guarantees the provisioned IOPS with 99.999% durability."*

---

## Part 3: EBS Snapshots — Your Safety Net (15 minutes)

### 🗣️ What is a Snapshot?

*"A snapshot is a POINT-IN-TIME BACKUP of your EBS volume. It captures the exact state of the volume at the moment you take the snapshot."*

```
EBS Volume (100 GB):                    Snapshot (stored in S3):
┌────────────────────┐                  ┌────────────────────┐
│ OS Files      │ 8GB│       ───→       │ Block 1: OS Files  │
│ App Code      │ 2GB│                  │ Block 2: App Code  │
│ Database      │20GB│                  │ Block 3: Database  │
│ Empty         │70GB│                  │ (Empty blocks NOT  │
└────────────────────┘                  │  stored — saves $) │
                                        └────────────────────┘
                                        Only ~30 GB stored!
```

### 🗣️ How Snapshots Work — Incremental

*"The first snapshot copies ALL data. Every subsequent snapshot copies ONLY the blocks that CHANGED since the last snapshot. This is called INCREMENTAL."*

```
Snapshot 1 (Monday):    Copies ALL 30 GB of data           → 30 GB stored
Snapshot 2 (Tuesday):   Only 2 GB changed since Monday     → 2 GB stored
Snapshot 3 (Wednesday): Only 500 MB changed since Tuesday  → 500 MB stored

Total stored: 32.5 GB (not 90 GB!)
Total cost:  32.5 × $0.05/GB = $1.63/month
```

*"Even better: if you delete Snapshot 1, AWS KEEPS any data blocks that Snapshot 2 and 3 depend on. Each snapshot is self-sufficient for restoration. You can delete old snapshots safely."*

### 🗣️ Snapshot Features

```
Snapshots:
├── Stored in S3 (managed by AWS — you don't see them in your S3 buckets)
├── Regional — can COPY to other regions (disaster recovery!)
├── Can create a NEW volume from a snapshot (in ANY AZ in the same region)
├── Can SHARE with other AWS accounts (or make public)
├── Can create an AMI from a snapshot (new machine image)
├── Incremental — only changed blocks are stored
├── Can be ENCRYPTED (even if original volume wasn't)
└── Pricing: $0.05/GB/month (only for data stored)
```

### 🗣️ Amazon EBS Snapshot Archive

*"For snapshots you need to keep for compliance but rarely restore, there's Snapshot Archive:"*

```
Standard Snapshot:
  Cost:     $0.05/GB/month
  Restore:  Immediate (create volume instantly)

Archive Snapshot:
  Cost:     $0.0125/GB/month (75% cheaper!)
  Restore:  24-72 hours (must restore to standard first)
```

*"Use case: Your compliance team says 'Keep database backups for 7 years.' Store the old ones in Archive tier. 75% cost savings."*

### 🗣️ Recycle Bin for Snapshots

*"What if you accidentally delete a snapshot? AWS has a RECYCLE BIN:"*

```
Recycle Bin Rule:
  Resource type: EBS Snapshots
  Retention: 7 days
  
Flow:
  You delete a snapshot → It goes to Recycle Bin (not actually deleted)
  Within 7 days → You can RECOVER it
  After 7 days → Permanently deleted
```

*"This is like the Windows Recycle Bin for your snapshots. Set up a retention rule and you'll never accidentally lose a backup again."*

### ❓ Ask Students:

*"I have an EBS volume in us-east-1a. I want to move it to us-east-1b. How?"*

*"Answer: You can't directly move a volume across AZs. Steps: 1) Create a snapshot of the volume. 2) Create a new volume from the snapshot in us-east-1b. 3) Attach the new volume to an instance in us-east-1b. 4) Delete the old volume if no longer needed."*

---

### 🖥️ Lab 1: Create an EBS Volume and Attach It (Console)

*"Let's get hands-on. We're going to create a NEW EBS volume, attach it to our instance, format it, and use it."*

**Step 1: Create the Volume**
1. Go to **EC2 Console** → **Elastic Block Store** → **Volumes** → **Create volume**
2. **Settings:**
   - Volume type: `gp3`
   - Size: `10 GiB`
   - IOPS: `3000` (default — free)
   - Throughput: `125 MiB/s` (default — free)
   - Availability Zone: `us-east-1a` ← **MUST match your instance's AZ!**
   - Encryption: ✅ Enable (check this — good practice)
   - KMS Key: `aws/ebs` (default)
3. **Tags:**
   - Name: `data-volume`
4. Click **Create volume**

*"See the status? 'Creating' → 'Available.' Available means it exists but is NOT attached to any instance yet. It's floating in the AZ, waiting."*

**Step 2: Attach the Volume**
1. Select the volume → **Actions** → **Attach volume**
2. **Instance:** Select `ebs-lab-instance`
3. **Device name:** `/dev/xvdf` (or the suggested name)
4. Click **Attach volume**

*"Status changes to 'In-use.' The volume is now connected to our instance. But can we use it? Not yet — we need to format and mount it. Let me show you."*

---

### 🖥️ Lab 2: Format, Mount, and Use the Volume (Terminal)

*"Connect to the instance via Session Manager or SSH:"*

```bash
# Step 1: See all block devices
lsblk
# Output:
# NAME    MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
# xvda    202:0    0   8G  0 disk
# └─xvda1 202:1    0   8G  0 part /
# xvdf    202:80   0  10G  0 disk         ← Our new volume! No mount point.

# Step 2: Check if the volume has a filesystem
sudo file -s /dev/xvdf
# → /dev/xvdf: data    ← "data" means NO filesystem. Brand new empty disk.

# Step 3: Create a filesystem (FORMAT the disk)
sudo mkfs -t xfs /dev/xvdf
# → meta-data=/dev/xvdf ... 
# → "Now it has an XFS filesystem."

# Step 4: Create a mount point (directory)
sudo mkdir /data

# Step 5: Mount the volume
sudo mount /dev/xvdf /data

# Step 6: Verify the mount
lsblk
# Output:
# xvdf    202:80   0  10G  0 disk /data    ← Mounted at /data ✓

df -h /data
# Filesystem  Size  Used  Avail  Use%  Mounted on
# /dev/xvdf   10G   104M  9.9G   2%    /data

# Step 7: Create some test data
sudo sh -c 'echo "This is my important data on a separate EBS volume!" > /data/important.txt'
sudo sh -c 'echo "Database file simulation" > /data/database.db'
sudo sh -c 'dd if=/dev/urandom of=/data/large-file.bin bs=1M count=100'

ls -la /data/
# → important.txt, database.db, large-file.bin (~100MB)
```

*"We now have a working 10 GB data volume. The operating system is on /dev/xvda (root), and our application data is on /dev/xvdf (/data). If we terminate this instance with 'Delete on Termination' disabled for this volume, the data survives."*

---

### 🖥️ Lab 3: Make the Mount Persistent (Survive Reboot)

*"There's a gotcha. If the instance reboots, the mount disappears. We need to add it to `/etc/fstab`:"*

```bash
# Step 1: Get the volume's UUID (more reliable than /dev/xvdf)
sudo blkid /dev/xvdf
# → /dev/xvdf: UUID="a1b2c3d4-e5f6-7890-abcd-ef1234567890" TYPE="xfs"

# Step 2: Backup fstab (ALWAYS do this — a bad fstab = unbootable instance!)
sudo cp /etc/fstab /etc/fstab.backup

# Step 3: Add the entry to fstab
# Replace the UUID with YOUR UUID from step 1
echo 'UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890  /data  xfs  defaults,nofail  0  2' | sudo tee -a /etc/fstab

# Step 4: Verify fstab is valid (THIS IS CRITICAL)
sudo mount -a
# If no errors → you're good
# If errors → FIX them before rebooting, or the instance won't boot!

# Step 5: Verify
df -h /data
# → Should still show /data mounted
```

*"The `nofail` option is CRITICAL. If the EBS volume is not available at boot time (detached, AZ issue), the `nofail` flag tells Linux to continue booting instead of hanging. Without it, a missing volume means a bricked instance."*

### ❓ Ask Students:

*"I added a mount entry to /etc/fstab but used the wrong UUID. I rebooted the instance. What happens?"*

*"Answer: The instance hangs during boot! It tries to mount a non-existent filesystem and waits forever — unless you used the `nofail` option. This is why you ALWAYS: 1) use `nofail`, 2) backup fstab, 3) run `mount -a` to test BEFORE rebooting."*

---

### 🖥️ Lab 4: Take a Snapshot and Restore

**Step 1: Create a Snapshot**
1. Go to **EC2 Console** → **Volumes** → Select `data-volume`
2. **Actions** → **Create snapshot**
3. **Description:** `data-volume-backup-lab`
4. Click **Create snapshot**

*"Go to Snapshots — see it? Status: 'Pending' → 'Completed.' This is a point-in-time copy of everything on that volume."*

**Step 2: Simulate Data Loss**
```bash
# Connect to instance
sudo rm -rf /data/*
ls /data/
# → Empty! Oh no, we 'accidentally' deleted everything!
```

**Step 3: Restore from Snapshot**
1. Go to **Snapshots** → Select your snapshot
2. **Actions** → **Create volume from snapshot**
3. **Settings:**
   - Volume type: `gp3`
   - Size: `10 GiB` (can increase, never decrease)
   - AZ: `us-east-1a` (same as your instance)
4. Click **Create volume**

**Step 4: Swap Volumes**
```bash
# On the instance — unmount the damaged volume
sudo umount /data
```

1. **EC2 Console** → **Volumes** → Select the OLD (empty) volume → **Actions** → **Detach volume**
2. Select the NEW (restored) volume → **Actions** → **Attach volume** → Instance: `ebs-lab-instance` → Device: `/dev/xvdf`

```bash
# Mount the restored volume
sudo mount /dev/xvdf /data
ls -la /data/
# → important.txt ✓, database.db ✓, large-file.bin ✓
# ALL DATA RESTORED! 🎉

cat /data/important.txt
# → "This is my important data on a separate EBS volume!"
```

*"We just recovered from a complete data loss in under 2 minutes. That snapshot saved us. This is why you should ALWAYS have a snapshot strategy — daily snapshots at minimum for any important data."*

---

### 🖥️ Lab 5: Copy Snapshot to Another Region (Disaster Recovery)

*"What if your entire region goes down? Let's copy our snapshot to another region:"*

1. Go to **Snapshots** → Select your snapshot
2. **Actions** → **Copy snapshot**
3. **Destination Region:** `us-west-2` (Oregon)
4. **Encryption:** ✅ Enable
5. Click **Copy snapshot**

*"Switch to the Oregon console. Go to Snapshots — you'll see the copy. From this copy, you can create a volume in Oregon and attach it to an instance there. This is the foundation of cross-region disaster recovery."*

### 🗣️ Snapshot CLI Commands for Automation

```bash
# Create a snapshot
aws ec2 create-snapshot \
  --volume-id vol-0abc123def456 \
  --description "Daily backup $(date +%Y-%m-%d)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=daily-backup}]' \
  --region us-east-1

# List snapshots for a volume
aws ec2 describe-snapshots \
  --filters "Name=volume-id,Values=vol-0abc123def456" \
  --query "Snapshots[*].[SnapshotId,StartTime,VolumeSize,State]" \
  --output table \
  --region us-east-1

# Copy snapshot to another region
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-0abc123def456 \
  --destination-region us-west-2 \
  --description "DR copy"

# Delete old snapshots (careful!)
aws ec2 delete-snapshot \
  --snapshot-id snap-0abc123def456 \
  --region us-east-1
```

---

## Part 4: EBS Encryption (10 minutes)

### 🗣️ How EBS Encryption Works

*"EBS encryption is DEAD SIMPLE. One checkbox. Let me explain what happens behind the scenes."*

```
Unencrypted Volume:
  Data on disk: readable by anyone with physical access

Encrypted Volume:
  Data on disk: AES-256 encrypted
  Data in transit (between EC2 and EBS): encrypted
  Snapshots: encrypted
  Volumes created from encrypted snapshots: encrypted
  
  All handled by AWS KMS (Key Management Service)
  ZERO performance impact on modern Nitro instances!
```

### 🗣️ Key Points About Encryption

```
1. Encryption is PER-VOLUME — you choose at creation time
2. You CANNOT encrypt an existing unencrypted volume directly
   → Workaround: Snapshot → Copy with encryption → Create volume from encrypted snapshot
3. You CAN set a DEFAULT: Account Settings → "Always encrypt new EBS volumes" ← DO THIS
4. KMS Keys:
   → aws/ebs — free, managed by AWS (default)
   → Custom CMK — you manage the key, more control, supports cross-account
5. Encryption is FREE — no additional cost
6. NO performance penalty on Nitro instances (all modern instances)
```

### 🖥️ Lab 6: Encrypt an Unencrypted Volume

*"Our root volume is unencrypted (default). Let's encrypt it:"*

```bash
# Step 1: Check if root volume is encrypted
aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=i-0abc123def456" \
  --query "Volumes[*].[VolumeId,Encrypted,Size,VolumeType]" \
  --output table \
  --region us-east-1

# Output:
# vol-root123   False   8    gp3    ← Unencrypted!
# vol-data456   True    10   gp3    ← Encrypted ✓
```

**In the console:**

1. **Create snapshot** of the unencrypted root volume
2. Go to **Snapshots** → Select → **Actions** → **Copy snapshot**
3. ✅ **Encrypt this snapshot**
4. KMS Key: `aws/ebs` (default)
5. Click **Copy**
6. Wait for copy to complete
7. **Create volume** from the encrypted snapshot copy
8. **Stop the instance**
9. **Detach** the old unencrypted root volume
10. **Attach** the new encrypted volume as `/dev/xvda`
11. **Start the instance**

*"Now the root volume is encrypted. All data at rest, data in transit, and any snapshots taken from this volume will be encrypted. Compliance teams love this."*

### 🗣️ Enable Default Encryption (Do This on Day 1)

*"The SMARTEST thing you can do: enable default encryption for ALL new volumes in your account."*

1. Go to **EC2 Console** → **Settings** (bottom of left sidebar)
2. **EBS encryption** → **Manage**
3. ✅ **Always encrypt new EBS volumes**
4. Default KMS key: `aws/ebs`
5. Click **Update**

*"Now every new EBS volume in this region is encrypted by default. No more 'I forgot to check the encryption box.' This is a security baseline that every company should set."*

---

## Part 5: EBS Modifications — Resize and Change Type Online (10 minutes)

### 🗣️ Elastic Volumes — Modify Without Downtime

*"One of the coolest EBS features: you can modify a volume WHILE it's in use. Change the size, change the type, change the IOPS — all without stopping the instance."*

```
Before:                              After:
  Volume: 10 GB, gp3, 3000 IOPS       Volume: 50 GB, gp3, 5000 IOPS
  
  Modified LIVE — instance keeps running!
  No downtime. No detach. No unmount.
```

### 🗣️ Rules for Modification

```
✅ You CAN:
  → Increase size (10 GB → 50 GB)
  → Change type (gp2 → gp3, gp3 → io2, etc.)
  → Increase IOPS (gp3, io2)
  → Increase throughput (gp3)

❌ You CANNOT:
  → DECREASE size (50 GB → 10 GB) — ever!
  → Modify again until previous modification completes
  → Cool-down period: 6 hours between modifications
```

### 🖥️ Lab 7: Resize a Volume Online

**Step 1: Modify the Volume (Console)**
1. Go to **Volumes** → Select `data-volume`
2. **Actions** → **Modify volume**
3. Change size: `10 GiB` → `20 GiB`
4. Click **Modify** → Confirm

*"Status: 'Modifying' → 'Optimizing' → 'Completed'. The volume is now 20 GB. But Linux doesn't know that yet!"*

**Step 2: Extend the Filesystem**
```bash
# Check current situation
lsblk
# xvdf    202:80   0  20G  0 disk /data    ← Disk shows 20 GB
df -h /data
# /dev/xvdf   10G   ...    ← But filesystem still shows 10 GB!

# The disk is bigger, but the filesystem hasn't expanded yet.
# Extend the XFS filesystem:
sudo xfs_growfs /data

# Or for ext4:
# sudo resize2fs /dev/xvdf

# Verify
df -h /data
# /dev/xvdf   20G   ...    ← Now 20 GB! ✓
```

*"Two steps: 1) Modify the volume in AWS. 2) Extend the filesystem in Linux. Students always forget step 2 — the disk is bigger but the filesystem doesn't automatically expand."*

### ❓ Ask Students:

*"I modified a volume from 10 GB to 20 GB. I need to make another change to 30 GB. Can I do it immediately?"*

*"Answer: No. There's a 6-hour cooldown between modifications. You must wait 6 hours. Plan ahead!"*

---

### 🖥️ Lab 8: Change Volume Type Online

*"Let's upgrade our volume from gp3 to io2 for database workload:"*

1. Go to **Volumes** → Select `data-volume`
2. **Actions** → **Modify volume**
3. Change type: `gp3` → `io2`
4. IOPS: `5000` (provisioned)
5. Click **Modify** → Confirm

```bash
# Verify the change
aws ec2 describe-volumes \
  --volume-id vol-0abc123def456 \
  --query "Volumes[0].[VolumeType,Iops,Size]" \
  --output table

# Output:
# io2   5000   20
```

*"We just upgraded from a general-purpose SSD to a high-performance database SSD — while the application was running. Zero downtime."*

---

## Part 6: Detach, Reattach, and Delete on Termination (10 minutes)

### 🗣️ Volume Lifecycle

```
Create → Attach → Use → Detach → Reattach (to another instance) or Delete

Volume States:
  Available  → Not attached to any instance (floating)
  In-use     → Attached to a running instance
  Deleting   → Being deleted
  Error      → Something went wrong

IMPORTANT: "Delete on Termination" flag
  Root volume:  Default = YES (deleted when instance terminates)
  Data volumes: Default = NO (survives instance termination)

  ⚠️ For production databases: ALWAYS set Delete on Termination = NO!
```

### 🖥️ Lab 9: Detach and Reattach a Volume

*"Let's move our data volume from one instance to another (if you have two instances). Or we'll detach and reattach to the same instance on a different device name."*

```bash
# Step 1: Unmount inside the instance
sudo umount /data

# Step 2: Detach in the console
# EC2 → Volumes → Select → Actions → Detach volume → Yes
# Status changes to "Available"

# Step 3: Reattach to the same (or different) instance
# Actions → Attach volume → Select instance → Device: /dev/xvdg (different name)
# Status changes to "In-use"

# Step 4: Mount at the new device
sudo mount /dev/xvdg /data
ls /data/
# → All data still there! ✓
```

*"In production, this is how you move data between instances. Terminate the old instance, keep the volume, attach it to a new instance. Database migration without copying any files."*

---

### 🖥️ Lab 10: Check and Modify 'Delete on Termination'

```bash
# Check the current setting
aws ec2 describe-instances \
  --instance-id i-0abc123def456 \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[*].[DeviceName,Ebs.DeleteOnTermination,Ebs.VolumeId]" \
  --output table \
  --region us-east-1

# Output:
# /dev/xvda   True    vol-root123    ← Root will be deleted on termination!
# /dev/xvdf   False   vol-data456    ← Data volume will survive ✓

# Change Delete on Termination for root volume (protect it):
aws ec2 modify-instance-attribute \
  --instance-id i-0abc123def456 \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"DeleteOnTermination":false}}]' \
  --region us-east-1

# Now root volume also survives termination ✓
```

---

## Part 7: Amazon Data Lifecycle Manager (DLM) — Automated Snapshots (10 minutes)

### 🗣️ The Problem with Manual Snapshots

*"Taking snapshots manually is fine for a lab. But in production with 100 volumes, you need AUTOMATION. Amazon Data Lifecycle Manager (DLM) creates and manages snapshots on a schedule."*

```
DLM Lifecycle Policy:
  Target: All volumes tagged "Backup=True"
  Schedule: Every 12 hours
  Retention: Keep last 7 snapshots
  Cross-region copy: Copy to us-west-2
  
  DLM automatically:
    → Takes snapshots every 12 hours
    → Keeps the last 7 (deletes older ones)
    → Copies each snapshot to Oregon for DR
    → No human intervention needed!
```

### 🖥️ Lab 11: Create a DLM Lifecycle Policy

**Step 1: Tag your volumes**
1. Go to **Volumes** → Select your data volume → **Tags** → Add tag:
   - Key: `Backup`
   - Value: `True`

**Step 2: Create the Policy**
1. Go to **EC2 Console** → **Elastic Block Store** → **Lifecycle Manager** → **Create lifecycle policy**
2. **Policy type:** EBS snapshot policy
3. **Description:** `Daily backup for production volumes`
4. **Target resource tags:**
   - Tag key: `Backup`
   - Tag value: `True`
5. **Schedule:**
   - Name: `DailyBackup`
   - Frequency: Every `24` hours
   - Starting at: `00:00 UTC` (midnight)
   - Retention: Retain `7` snapshots
6. **Cross-region copy:** (optional)
   - ✅ Enable cross-region copy
   - Target region: `us-west-2`
   - Retain copy: `3` snapshots
7. Click **Create policy**

*"Now every night at midnight UTC, DLM takes a snapshot of every volume tagged `Backup=True`, keeps the last 7, copies to Oregon, and keeps the last 3 copies there. Fully automated disaster recovery backup. Set it and forget it."*

---

## Part 8: EBS Pricing (5 minutes)

### 🗣️ How Much Does EBS Cost?

| Component | Cost (us-east-1) |
|-----------|-------------------|
| **gp3 storage** | $0.08/GB/month |
| **gp3 IOPS** (above 3,000) | $0.005/IOPS/month |
| **gp3 throughput** (above 125 MiB/s) | $0.04/MiB/s/month |
| **gp2 storage** | $0.10/GB/month |
| **io2 storage** | $0.125/GB/month |
| **io2 IOPS** | $0.065/IOPS/month |
| **st1 storage** | $0.045/GB/month |
| **sc1 storage** | $0.015/GB/month |
| **Snapshots** | $0.05/GB/month |
| **Snapshot Archive** | $0.0125/GB/month |
| **Snapshot restore from archive** | $0.03/GB |

### 🗣️ Real-World Cost Examples

```
Example 1: Small Web App
  Root volume: 20 GB gp3 = $1.60/month
  Data volume: 50 GB gp3 = $4.00/month
  Snapshots:   30 GB     = $1.50/month
  Total:                   $7.10/month  ✅ Cheap!

Example 2: Production Database
  Data volume: 500 GB io2, 10,000 IOPS
    Storage:   500 × $0.125         = $62.50/month
    IOPS:      10,000 × $0.065     = $650.00/month
    Snapshots: 200 GB × $0.05      = $10.00/month
  Total:                             $722.50/month  😬 IOPS costs add up!

Example 3: Data Lake / Big Data
  10 × st1 volumes, 1 TB each
    Storage:   10,000 × $0.045     = $450.00/month
    Snapshots: 5,000 GB × $0.05   = $250.00/month
  Total:                             $700.00/month
```

*"The lesson: STORAGE is cheap. IOPS are expensive. Choose your volume type carefully."*

---

## Part 9: EBS Best Practices (5 minutes)

### 🗣️ Best Practices

1. **Use gp3 instead of gp2** — Cheaper and better. Always choose gp3 for new volumes.
2. **Separate root and data volumes** — OS on root, application data on separate volume with Delete on Termination disabled.
3. **Enable default encryption** — Account-wide setting. Do it on Day 1.
4. **Automate snapshots with DLM** — Never rely on manual snapshots.
5. **Cross-region snapshot copies** — For disaster recovery.
6. **Use `nofail` in fstab** — Prevents bricked instances on reboot.
7. **Monitor burst credits** (gp2) — If you're still on gp2, watch the `BurstBalance` CloudWatch metric.
8. **Right-size your volumes** — Don't provision 1 TB when you need 100 GB. You pay for provisioned, not used.
9. **Tag volumes for cost tracking** — Use `Environment`, `Application`, `Team` tags.
10. **Delete unused volumes** — Unattached volumes still cost money! Run monthly audits.

### 🗣️ Finding Unused Volumes (Cost Savings)

```bash
# Find all unattached (available) volumes — these are costing you money!
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query "Volumes[*].[VolumeId,Size,VolumeType,CreateTime]" \
  --output table \
  --region us-east-1

# If any show up — investigate and delete if not needed
# These are often leftover from terminated instances
```

---

## Part 10: Interview Questions (5 minutes)

### 🗣️ Top 10 EBS Interview Questions

1. **What is EBS?**
   → Network-attached block storage for EC2. Persistent, supports snapshots, encryption, and multiple volume types.

2. **What's the difference between EBS and Instance Store?**
   → EBS is persistent, network-attached, supports snapshots. Instance Store is ephemeral, physically attached, fastest performance, but data is lost on stop/terminate.

3. **Can you attach an EBS volume to instances in different AZs?**
   → No. EBS is AZ-locked. To move: snapshot → create volume in new AZ.

4. **What's the difference between gp3 and gp2?**
   → gp3: 3,000 baseline IOPS (free), IOPS/throughput independent of size, $0.08/GB. gp2: IOPS tied to volume size (3 IOPS/GB), uses burst credits, $0.10/GB. gp3 is cheaper and better.

5. **How do EBS snapshots work?**
   → Point-in-time, incremental backups stored in S3. First snapshot is full, subsequent snapshots only copy changed blocks.

6. **Can you decrease the size of an EBS volume?**
   → No. You can only increase. To "shrink," create a smaller volume, copy data, and swap.

7. **How do you encrypt an existing unencrypted volume?**
   → Snapshot → Copy snapshot with encryption → Create volume from encrypted snapshot.

8. **What is Delete on Termination?**
   → Controls whether EBS volume is deleted when EC2 instance terminates. Default: Yes for root, No for additional volumes.

9. **What is EBS Multi-Attach?**
   → Attach one io1/io2 volume to up to 16 instances in the same AZ. Requires cluster-aware filesystem.

10. **What is the maximum size of an EBS volume?**
    → 64 TiB for io2 Block Express, 16 TiB for all other types.

---

## Timing Summary

| Section | Duration |
|---------|----------|
| Part 1: What EBS Solves | 15 min |
| Part 2: Volume Types | 25 min |
| Part 3: Snapshots | 15 min |
| Part 4: Encryption | 10 min |
| Part 5: Modifications | 10 min |
| Part 6: Detach/Reattach | 10 min |
| Part 7: DLM Automation | 10 min |
| Part 8: Pricing | 5 min |
| Part 9: Best Practices | 5 min |
| Part 10: Interview Questions | 5 min |
| **Total** | **~2 hours** |

> **Trainer tip:** The "wow" moments are Lab 2 (formatting/mounting — students see raw Linux disk ops), Lab 4 (snapshot restore — they feel the power of recovery), and Lab 7 (live resize — modifying a running volume). Spend extra time on these.

> **Trainer tip:** Have students create their OWN volumes, format, mount, and take snapshots. Don't just demo — let them do it. The filesystem commands (mkfs, mount, fstab, xfs_growfs) are things they'll use in every Linux job.

> **Trainer tip:** The gp2 vs gp3 burst credits discussion is GOLD for interviews. Spend time on the "100 GB gp2 with 2,500 sustained IOPS" example. Every interviewer asks about EBS burst credits.
