# AWS Storage — EBS, EFS, and S3 (Complete Teaching Script)

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~3.5 hour session with break.

---

## Part 1: The "Big Three" AWS Storage Options (30 minutes)

### 🗣️ Opening Hook

*"Welcome back, everyone. Today we are talking about the most fundamental component of any IT system: Storage. Where do we put our data?"*

*"Imagine you are building a new application. You have a database, you have user-uploaded profile pictures, and you have application log files. If you buy a physical server, you just shove some hard drives in it and save everything to `C:\` or `/var/log`."*

*"But in the cloud, we don't just have 'hard drives'. AWS gives us purpose-built storage services. Why? Because storing a 2-byte text file is very different from storing a 50 GB database file, which is very different from storing 10 million cat videos. If you use the wrong storage, your app will be slow, and your AWS bill will explode."*

*"There are three main types of storage in AWS you absolutely must know: EBS, EFS, and S3. Let's break down the practical differences."*

---

### 🗣️ 1. EBS (Elastic Block Store) — "The Local Hard Drive"

*"Let's start with EBS. EBS stands for Elastic Block Store."*

*"EBS is a virtual hard drive attached to a single EC2 instance. It is Block Storage. Block storage means the drive is formatted with an operating system file system (like NTFS for Windows, or ext4 for Linux). When you change a file, it only updates the specific 'blocks' of data that changed on the disk."*

**Practical Example:**
*"Think of EBS like a USB flash drive. You plug it into one computer (an EC2 instance). You install your operating system on it, you put your database on it. It is incredibly fast. BUT... you cannot plug that same USB drive into two computers at the exact same time."*

**Key Rules for EBS:**
1. It is locked to a specific Availability Zone (AZ). If the drive is in `us-east-1a`, you can only attach it to an EC2 instance in `us-east-1a`.
2. Generally, it can only be attached to ONE EC2 instance at a time.
3. If the EC2 instance goes down, the EBS volume survives (if you configure it to).
4. **Use Case:** Operating systems (boot drives), databases (MySQL, PostgreSQL), anything that requires high-speed, low-latency, frequent reads and writes.

---

### 🗣️ 2. EFS (Elastic File System) — "The Network Shared Drive"

*"Next is EFS. Elastic File System."*

*"EBS was a USB drive plugged into one computer. EFS is like a network-attached storage (NAS) drive. It is a shared folder that lives on the network."*

**Practical Example:**
*"Imagine you have 10 EC2 instances running a WordPress website. Users are constantly uploading images. If you save an image to EC2 Server 1's EBS drive, Server 2 cannot see it. So if the load balancer sends the next user to Server 2, the image is broken."*
*"The solution? EFS. You create one EFS network drive, and you 'mount' it to all 10 EC2 instances simultaneously. When Server 1 saves an image to `/mnt/efs/uploads`, Server 2 can instantly see it in its own `/mnt/efs/uploads` folder."*

**Key Rules for EFS:**
1. It can be attached to hundreds of EC2 instances simultaneously.
2. It spans across multiple Availability Zones automatically (Multi-AZ).
3. It only works with Linux instances (no Windows support).
4. You don't guess the size. It automatically scales up and down as you add or remove files.
5. **Use Case:** Content management systems (WordPress), shared code repositories, massive parallel data processing.

---

### 🗣️ 3. S3 (Simple Storage Service) — "The Infinite Cloud Folder"

*"Finally, S3. Simple Storage Service. This is Object Storage, not block or file storage."*

*"S3 is not a hard drive. You cannot install an operating system on S3. You cannot run a database on S3. S3 is basically an infinite, massive web-based folder. You access it via the internet (HTTPS API), not by mounting it to a server."*

**Practical Example:**
*"Think of Google Drive or Dropbox. You upload a file, you get a link, you download a file. If you have 5 million user profile pictures, you put them in S3. Your application just asks S3: 'Give me user_123.jpg', and S3 hands it over via a web URL."*

**Key Rules for S3:**
1. Infinite storage. You never run out of space.
2. Files are stored as 'Objects' in 'Buckets'.
3. It is serverless. You don't attach it to EC2. Anyone with the right permissions can access it from anywhere in the world.
4. **Use Case:** Backups, static websites, images, videos, data lakes, logs.

---

### ❓ Ask Students: Scenario Drill

*"Okay, let's test your knowledge. I will give you a scenario, you tell me: EBS, EFS, or S3?"*

1. *"I am installing an Oracle SQL Database that needs sub-millisecond read times."*
   * → **Answer:** EBS. Databases need fast block storage.
2. *"I am storing 5 years of PDF invoices for compliance. I rarely read them, but I must keep them safely."*
   * → **Answer:** S3. Cheap, infinite object storage for backups/archives.
3. *"I have 5 Linux web servers that all need to read the exact same configuration file in real-time."*
   * → **Answer:** EFS. Shared file system across multiple instances.
4. *"I want to host a static HTML/CSS website with no backend servers at all."*
   * → **Answer:** S3. S3 has a built-in static website hosting feature.

*"Excellent. Now that you know the difference, the rest of today's class is a deep dive into the undisputed king of cloud storage: Amazon S3."*

---

## Part 2: Amazon S3 Fundamentals (20 minutes)

### 🗣️ What is S3?

*"S3 is the oldest, most reliable, and most widely used service in AWS. It was launched in 2006. It is designed to provide 99.999999999% (11 nines) of durability. That means if you store 10 million objects in S3, you can expect to lose a single object once every 10,000 years."*

*"In S3, there are two main concepts you need to know: Buckets and Objects."*

### 🗣️ 1. Buckets

*"A Bucket is the top-level container for your files. Think of it like a root folder. But there is one massive catch."*

*"**BUCKET NAMES MUST BE GLOBALLY UNIQUE.**"*

*"If I create a bucket named `my-test-bucket`, nobody else in the entire world can use that name. Not in my AWS account, not in your AWS account, nowhere. It is like registering a web domain name. Why? Because every bucket gets a unique public web URL."*

*Rules for Bucket Names:*
- Must be globally unique.
- No uppercase letters.
- No underscores.
- 3 to 63 characters long.
- Example: `streamflix-prod-assets-2026`

*"S3 is a global service. But when you create a bucket, you must choose an AWS Region (like `us-east-1` or `eu-west-1`). Your data stays in that region unless YOU explicitly copy it somewhere else. AWS will never move your data across borders without your permission."*

### 🗣️ 2. Objects

*"The files you put inside a bucket are called Objects."*

*"An object consists of:"*
1. **Key:** The full path and name of the file. (e.g., `images/profile/user1.jpg`)
2. **Value:** The actual data bytes of the file.
3. **Version ID:** If versioning is enabled.
4. **Metadata:** Data about data. S3 adds system metadata (like file size, upload date). You can add custom metadata (like `uploaded-by: user_123`).

*"Here is a trick question. Does S3 have folders?"*
*"The answer is... NO. S3 has a 'flat' structure. It does not have real folders like Windows. If I upload a file named `photos/2026/jan/vacation.jpg`, S3 does not create a folder called `photos`. The word `photos/20...` is literally just part of the file's extremely long name (the Key). The AWS Console just fakes the folder UI for humans."*

*"Max object size in S3 is 5 Terabytes. If you are uploading anything larger than 100 Megabytes, you must use a 'Multipart Upload', which breaks the file into pieces, uploads them in parallel, and S3 stitches them together."*

---

## Part 3: S3 Storage Classes (30 minutes)

### 🗣️ The Cost of Storage

*"S3 is cheap. But if you are storing Petabytes of data, 'cheap' still equals tens of thousands of dollars a month. S3 gives you ways to save money by moving data you don't use often into cheaper tiers. We call these Storage Classes."*

🖥️ *Write these on the whiteboard or display them on screen.*

### 🗣️ 1. S3 Standard

*"This is the default. It's for data you access frequently. Low latency, high throughput. Used for mobile apps, gaming, dynamic websites."*
- **Cost:** Most expensive storage cost, but retrieving data is free/cheap.
- **Durability:** 11 Nines. Spans across at least 3 Availability Zones.

### 🗣️ 2. S3 Standard-IA (Infrequent Access)

*"This is for data you don't need often, but when you do need it, you need it FAST (milliseconds). Think: disaster recovery backups, older photos."*
- **Cost:** Cheaper to store than Standard, BUT you are charged a fee every time you retrieve (read) the data.
- **Rule of thumb:** If you access the file less than once a month, put it in IA.
- **Catch:** Minimum storage duration is 30 days. Minimum billable size is 128KB.

### 🗣️ 3. S3 One Zone-IA

*"Same as Standard-IA, but instead of copying your data to 3 AZs, S3 only stores it in ONE Availability Zone. If that single data center catches fire, your data is gone."*
- **Cost:** 20% cheaper than Standard-IA.
- **Use Case:** Secondary backup copies, thumbnails that you can easily recreate if lost. NEVER use this for your only copy of critical data.

### 🗣️ 4. S3 Glacier Flexible Retrieval

*"Now we enter the 'Cold Storage' or Archive tiers. This is for data you must keep for legal or compliance reasons for 10 years, but hope to never look at again."*
- **Cost:** extremely cheap to store.
- **Catch:** You CANNOT access your data instantly. If you request a file, you must wait 3 to 5 hours for S3 to 'thaw' the file before you can download it.

### 🗣️ 5. S3 Glacier Deep Archive

*"The absolute cheapest storage class in all of AWS. It is practically free."*
- **Cost:** $0.00099 per GB/month. Storing 1 Terabyte costs about $1 a month.
- **Catch:** Retrieval time takes 12 to 48 HOURS. Minimum storage duration is 180 days.

### 🗣️ 6. S3 Intelligent-Tiering

*"What if you don't know how often your data is accessed? It's unpredictable. Enter Intelligent-Tiering. You pay AWS a tiny monthly monitoring fee per object. S3 watches your files. If nobody touches a file for 30 days, S3 automatically moves it to IA. If someone accesses it, S3 instantly moves it back to Standard. You get the cost savings without any manual work."*

### ❓ Ask Students:

*"A hospital needs to keep patient X-rays for 7 years by law. Doctors look at the X-rays constantly for the first week, then almost never again. If an auditor asks for an old X-ray, the hospital has 24 hours to provide it. Which storage class should they use for the old X-rays?"*

*"Answer: S3 Glacier Flexible Retrieval or Deep Archive. Since they have 24 hours to provide it, Deep Archive might be slightly too slow (up to 48 hours), so Glacier Flexible (3-5 hours) is the safest bet for maximum cost savings."*

---

## Part 4: The 3 Layers of S3 Security (30 minutes)

### 🗣️ The #1 Cloud Vulnerability

*"Do you know what the number one cause of cloud data breaches is? It's not elite hackers breaking encryption. It's a junior developer creating an S3 bucket with customer data and accidentally making it public to the internet."*

*"To properly secure your data, you need to understand the comprehensive security model of S3. S3 has 3 distinct layers of defense. Let's look at each one and exactly how to implement them."*

---

### 🗣️ Layer 1: Access Control

*"The first layer ensures that only authorized entities can interact with your bucket and its contents. We have four main tools here:"*

1. **Block Public Access:** *"By default, S3 blocks all public access at the account and bucket levels to prevent accidental data exposure. This is the ultimate safety switch."*
2. **Bucket Policies:** *"Resource-based policies that grant or deny permissions to users or services for the entire bucket."*
3. **IAM Policies:** *"Identity-based policies attached to users, groups, or roles to define exactly what actions they can perform (e.g., `s3:GetObject`)."*
4. **VPC Endpoints:** *"Private connections between your Virtual Private Cloud (VPC) and S3, ensuring traffic stays within the AWS network and does not traverse the public internet."*

🖥️ **Step-by-Step Implementation (Block Public Access):**
1. *"Go to the AWS S3 Console and click on your bucket."*
2. *"Navigate to the **Permissions** tab."*
3. *"Scroll to the **Block public access (bucket settings)** section and click **Edit**."*
4. *"Check the box that says **Block all public access**."*
5. *"Click **Save changes** and type 'confirm' in the pop-up box."*

---

### 🗣️ Layer 2: Data Encryption

*"The second layer protects the confidentiality of your data both while it is stored and while it is moving."*

1. **Encryption at Rest:** *"Amazon S3 automatically encrypts all new objects at the base level using SSE-S3. You can also use AWS Key Management Service (KMS) for more control over key rotation and access."*
2. **Encryption in Transit:** *"You can enforce secure connections over HTTPS (TLS) by using bucket policies that deny any requests made over unencrypted HTTP."*

🖥️ **Step-by-Step Implementation (Force HTTPS via Bucket Policy):**
1. *"In your bucket, go to the **Permissions** tab."*
2. *"Scroll down to **Bucket policy** and click **Edit**."*
3. *"Add a policy with `Effect: Deny`, `Action: s3:*`, and `Condition: {"Bool": {"aws:SecureTransport": "false"}}`."*
4. *"Click **Save changes**. Now any HTTP (unencrypted) request will be instantly denied."*

---

### 🗣️ Layer 3: Monitoring and Auditing

*"The final layer provides visibility into activity within your bucket to detect and respond to security incidents."*

1. **AWS CloudTrail:** *"Records every API call made to S3, providing a detailed history of who accessed what and when."*
2. **S3 Server Access Logs:** *"Provides detailed records for requests that are made to a bucket, useful for security and access audits."*
3. **Amazon GuardDuty:** *"Uses machine learning to detect suspicious S3 access patterns, such as unusual data exfiltration or access from known malicious IP addresses."*

🖥️ **Step-by-Step Implementation (Enable Server Access Logging):**
1. *"Go to the AWS S3 Console and click on your bucket."*
2. *"Navigate to the **Properties** tab."*
3. *"Scroll down to **Server access logging** and click **Edit**."*
4. *"Select **Enable** and choose a target bucket where you want the logs saved."*
5. *"Click **Save changes**."*

---

## Part 5: S3 Advanced Features (20 minutes)

### 🗣️ 1. Versioning

*"What happens if I upload `resume.pdf`. Tomorrow, I upload a new file also named `resume.pdf` to the same bucket? S3 overwrites it. The old one is gone."*

*"Unless... you enable Versioning. If Versioning is on, S3 keeps ALL variants of an object. The new one becomes the current version, but the old one is saved as a previous version. You can easily roll back."*

*"**WARNING:** If you have versioning on, and you delete a file, S3 doesn't actually delete it. It places a 'Delete Marker' on top of it to hide it. The file is still there, and you are STILL PAYING for it. To permanently delete it, you must explicitly delete the specific version ID."*

### 🗣️ 2. Lifecycle Rules

*"Remember our storage classes? Do I have to manually move files to Glacier after 30 days? No. You use Lifecycle Rules."*

*"A Lifecycle Rule is an automation script. Example:"*
- Rule: "Take all files in the `logs/` path."
- Action 1: Move to Standard-IA after 30 days.
- Action 2: Move to Glacier after 90 days.
- Action 3: Permanently delete after 365 days.
*"Set it and forget it."*

### 🗣️ 3. Cross-Region Replication (CRR)

*"S3 replicates your data across multiple Availability Zones in one region. But what if the entire `us-east-1` region (Northern Virginia) goes completely offline? If your business cannot survive that, you need Cross-Region Replication."*

*"CRR automatically, asynchronously copies every object uploaded to Bucket A in us-east-1 over to Bucket B in eu-west-1 (Ireland). Versioning MUST be enabled on both buckets for this to work."*

---

## Part 6: Practical Use Cases (20 minutes)

### 🗣️ Static Website Hosting

*"This is one of the coolest features of S3. If you have a website made entirely of HTML, CSS, and client-side JavaScript (like a React or Angular app), you do NOT need an EC2 web server."*

🖥️ *Console Demo Steps (Verbal walk-through):*
1. *"Create a bucket. Turn OFF Block Public Access."*
2. *"Upload `index.html` and `error.html`."*
3. *"Go to Bucket Properties -> Static Website Hosting -> Enable."*
4. *"Go to Permissions -> Add a Bucket Policy allowing `s3:GetObject` for `Principal: *`."*
5. *"S3 gives you an endpoint URL. Your website is now live, infinitely scalable, and costs pennies a month."*

### 🗣️ Pre-Signed URLs

*"Scenario: You are building Netflix. You store the movie files in an S3 bucket. The bucket is PRIVATE. You do NOT want anyone downloading movies unless they are a logged-in, paying subscriber."*

*"How does your app let a user download the movie if the bucket is private? The answer is Pre-Signed URLs."*

*"Your backend code (using AWS credentials) tells S3: 'Hey, generate a temporary URL for `movie.mp4` that is valid for exactly 15 minutes.' S3 gives you a long, crazy-looking URL. Your app gives this URL to the user. The user clicks it and downloads the movie. 16 minutes later? The URL expires and becomes useless. This is how secure file sharing works in the cloud."*

---

## Part 7: Interview Questions & Wrap-up (10 minutes)

### 🗣️ Top S3 & Storage Interview Questions

1. **What is the difference between EBS, EFS, and S3?**
   * → *EBS is block storage for one EC2 instance. EFS is file storage shared across many EC2 instances. S3 is object storage accessed via the web.*

2. **Can you install an OS on S3?**
   * → *No, S3 is object storage, not block storage. You must use EBS for boot volumes.*

3. **What is the maximum object size in S3?**
   * → *5 Terabytes. (Though a single PUT request maxes at 5GB, requiring multipart upload for larger).*

4. **How do you ensure data is automatically deleted after 1 year?**
   * → *Create an S3 Lifecycle Rule with an expiration action.*

5. **How can you grant temporary access to a private S3 object?**
   * → *Use a Pre-Signed URL.*

6. **You deleted a file in a versioned bucket but want it back. How?**
   * → *Remove the 'Delete Marker' that S3 placed over the file.*

7. **A client wants cheapest possible storage for 10-year archival data, but can wait 24 hours to retrieve it. What class?**
   * → *S3 Glacier Deep Archive.*

### 🗣️ Wrap up

*"Storage is the bedrock of AWS. If you master S3, EBS, and EFS, you can design the architecture for 95% of applications in the world. S3 for static assets and backups, EBS for databases and OS, EFS for shared network files. Simple, elegant, and infinitely scalable."*

*"Take a 15-minute break, and when we come back, we'll get our hands dirty in the console building an S3 static website."*
