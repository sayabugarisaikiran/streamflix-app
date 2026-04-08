# AWS Networking & Security Mastery: A Complete Teaching Plan

This guide provides a comprehensive, beginner-friendly framework to teach AWS Networking and Security concepts with industry-level depth.

---

## 1. Core Concepts (Spoon-Feeding Explanations)

> [!NOTE]
> **Instructor Tip:** Always use analogies first, then map them to the technical AWS terms.

*   **S3 (Simple Storage Service):** **The Unlimited Internet Hard Drive.** You put files in, you get a link to view them. It never runs out of space.
*   **ACM (Amazon Certificate Manager):** **The "Green Padlock" Generator.** It ensures your website is verified and traffic is encrypted (HTTPS) so hackers can't intercept passwords.
*   **Route 53:** **The Internet Phonebook.** Humans remember names like `amazon.com`. Computers only understand numbers (IP Addresses like `192.168.1.1`). Route 53 takes the name you typed and looks up the number.
*   **CloudFront:** **The Global Delivery Guy (CDN).** If your server is in New York, users in India will experience lag. CloudFront keeps a cached copy of your images/videos in India so it loads instantly for them.
*   **WAF (Web Application Firewall):** **The Club Bouncer.** It stands at the front door of your app checking IDs. Normal users get in. If someone tries to sneak in a weapon (like a SQL Injection attack) or a bot tries to spam you, WAF kicks them out immediately.
*   **API Gateway:** **The Receptionist.** When your frontend wants data from the backend database, it talks to the receptionist. The receptionist checks if the request is valid, routes it to the right department (Lambda/EC2), and brings the answer back.

---

## 2. Real-World Architecture Flow (Amazon / Netflix Style)

**The Scenario:** A user in Tokyo wants to watch a movie trailer on a site hosted in Virginia.

1.  **The Lookup:** User types `movies.com`. **Route 53** acts as the phonebook and points them to the nearest CloudFront location in Tokyo.
2.  **The Arrival & Security Check:** The request hits **CloudFront** (Tokyo). Immediately, the **WAF** (Bouncer) checks the request. Is it a malicious bot? No. It's allowed through.
3.  **The Handshake:** **ACM** provides the SSL certificate, ensuring the connection is secure (HTTPS).
4.  **The Delivery (Cache Hit):** CloudFront checks: *"Do I already have this trailer?"* If yes, it sends it back instantly to the user in 10 milliseconds.
5.  **The Origin Fetch (Cache Miss):** If CloudFront doesn't have it, it securely goes to the **S3 Bucket** in Virginia to grab the file, delivers it to the user, and *keeps a copy* in Tokyo for the next person!
6.  **Dynamic Data:** If the user is logging in instead of watching a video, CloudFront forwards the request to **API Gateway**, which securely triggers the login code.

---

## 3. Teaching Script (What to say in class)

**Opening Hook:**
*"Welcome folks! How long are you willing to wait for a website to load before you close the tab? Three seconds? Two? Today, we are going to learn how Netflix and Amazon make their websites load in milliseconds, no matter where you are in the world. But fast isn't enough—we are also going to make it bulletproof against hackers."*

**Connecting S3 and CloudFront:**
*"So we have our static website sitting in an S3 bucket in Virginia. If I access it from India, it's slow. How do we fix this? Enter CloudFront! Let's put a CloudFront distribution in front of S3. Think of CloudFront as putting mini-fridges full of our content in every major city in the world."*

**Introducing WAF:**
*"Now our site is blazingly fast globally. But guess what? Hackers love fast sites too. What if someone writes a script to hit our site 10,000 times a second? We pay for that! This is why we need WAF. We are going to attach a bouncer to our CloudFront mini-fridges. If anyone looks suspicious, WAF drops the connection permanently."*

---

## 4. Step-by-Step Hands-On Demo (The "Secure Global Frontend" Stack)

> [!IMPORTANT]
> Ensure students have a registered domain name (via Route 53 or third-party) before this lab.

**Step 1: The S3 Bucket**
1.  Go to **S3** -> Create Bucket (e.g., `my-awesome-site-demo`).
2.  **CRITICAL:** Leave "Block all public access" **ON**. (We will use OAC so only CloudFront can read it).
3.  Upload an `index.html` file.

**Step 2: The ACM Certificate (The Padlock)**
1.  Go to **ACM**.
2.  > [!WARNING]
    > **Mistake Alert:** You MUST switch your region to `us-east-1` (N. Virginia) for CloudFront certificates!
3.  Click "Request Certificate". Enter `*.yourdomain.com` and `yourdomain.com`.
4.  Choose "DNS Validation". Click "Create records in Route 53" to validate instantly.

**Step 3: The CloudFront Distribution (The Global Network)**
1.  Go to **CloudFront** -> Create Distribution.
2.  **Origin:** Select your S3 bucket.
3.  **Origin Access:** Select **Origin Access Control settings (OAC)**. (Click Create control setting). This is the modern, secure way!
4.  **WAF:** Select "Enable security protections" (creates a basic WAF).
5.  **Viewer Protocol Policy:** Choose "Redirect HTTP to HTTPS".
6.  **Custom SSL Certificate:** Choose the ACM cert you just created.
7.  **Default Root Object:** Type `index.html`.
8.  Create Distribution. Copy the S3 standard bucket policy provided by CloudFront and paste it into the S3 Bucket Permissions.

**Step 4: The Route 53 Record (The Phonebook)**
1.  Go to **Route 53** -> Hosted Zones.
2.  Create Record.
3.  **Record Name:** Leave blank (or type `www`).
4.  **Record Type:** A.
5.  **Alias:** Switch to YES. Choose "Alias to CloudFront distribution".
6.  Paste your CloudFront URL (`dxxxxx.cloudfront.net`). Save.

**Verification:**
Wait 5 minutes. Go to `yourdomain.com`. It loads instantly, has a padlock, and the S3 bucket URL itself remains completely private!

---

## 5. WAF Attack Demo Ideas (The "Wow" Factor)

Students learn best when they see things break.

1.  **Rate Limiting Demo:**
    *   **Action:** Add a WAF rule blocking IPs that make > 100 requests in 5 minutes.
    *   **Attack:** Have students run a bash loop in CloudShell: `while true; do curl https://yourdomain.com; done`
    *   **Result:** Initially, they see the HTML. After a few seconds, boom! `403 Forbidden`. The bouncer kicked them out.
2.  **Geo-Blocking Demo:**
    *   **Action:** Add a WAF rule blocking traffic from "Country X" or "Your Current Country" just for fun.
    *   **Attack:** Tell students to try accessing the site using a VPN or their normal connection.
    *   **Result:** Access denied based on geography.
3.  **SQLi / XSS Blocking:**
    *   **Action:** Enable AWS Managed Core Rule Set in WAF.
    *   **Attack:** Ask students to visit: `https://yourdomain.com/?search=1' OR '1'='1`
    *   **Result:** Instantly blocked by WAF's SQL Injection filters.

---

## 6. Common Mistakes (To warn students about)

> [!CAUTION]
> These are the top reasons student labs fail. Review these before starting!

1.  **ACM Region Error:** Creating the SSL certificate in their local region (e.g., `eu-west-1`) instead of `us-east-1`. CloudFront *only* accepts certs from N. Virginia.
2.  **S3 Naked URLs:** Using the S3 static website hosting URL as the CloudFront origin. This bypasses OAC and leaves the bucket exposed. Always use the standard REST API endpoint.
3.  **Route 53 CNAME vs. Alias:** Using a CNAME pointing to the CloudFront URL at the root domain (`example.com`). Root domains *must* use an AWS Alias A-Record.
4.  **Cache Invalidation:** Uploading a new `index.html` to S3 and wondering why the site didn't update. (Explain that CloudFront is holding the old copy! They must create a cache invalidation).

---

## 7. 2-Day Workshop Plan

### Day 1: Global Content Delivery
*   **Morning (09:00 - 12:00):** AWS Networking Basics, Route 53 (DNS logic), and S3 Storage classes.
*   **12:00 - 13:00:** Lunch
*   **Afternoon (13:00 - 16:00):** CDN Concepts, ACM Certificates, and Hands-on S3 + CloudFront deployment.
*   **Late Afternoon (16:00 - 17:00):** Lab Troubleshooting & Review.

### Day 2: Security & Automation
*   **Morning (09:00 - 12:00):** Understanding OSI Layer 7 attacks, WAF concepts, API Gateway introduction.
*   **12:00 - 13:00:** Lunch
*   **Afternoon (13:00 - 15:30):** WAF Hands-on Attack Demos, Infrastructure as Code (Terraform basics).
*   **Late Afternoon (15:30 - 17:00):** Final Challenge (Build the full stack via Terraform) & Resume Building Session.

---

## 8. Interview Questions & Resume Projects

### Resume Project Idea
**"Global Content Delivery & Edge Security Implementation"**
*Architected and deployed a highly-available frontend infrastructure using S3 and CloudFront, reducing global latency by 70%. Implemented an Origin Access Control (OAC) zero-trust model. Secured the edge against OWASP Top 10 vulnerabilities and DDoS attacks using AWS WAF and custom rate-limiting rules. Automated SSL/TLS provisioning via ACM and DNS management using Route 53.*

### Top Interview Questions
1.  **"How do you securely serve a static website globally without exposing your S3 bucket to the public?"**
    *   *Ans:* Use CloudFront with Origin Access Control (OAC). Block all public access on S3.
2.  **"Why would you use an Alias record over a CNAME in Route 53?"**
    *   *Ans:* CNAMEs aren't allowed at the "zone apex" (the root domain like `google.com`). AWS Alias records let you point the apex domain to AWS resources like CloudFront for free.
3.  **"A customer complains the website hasn't updated even though they uploaded new files to S3. What's wrong?"**
    *   *Ans:* CloudFront has cached the old files. You need to run a cache invalidation or use object versioning.

---

## 9. Basic Terraform Example

To show them how the "big dogs" do it, provide this minimal Terraform snippet showing an S3 bucket configured for CloudFront OAC.

```hcl
provider "aws" {
  region = "us-east-1"
}

# 1. Create the S3 Bucket
resource "aws_s3_bucket" "frontend" {
  bucket = "my-secure-frontend-bucket-12345"
}

# 2. Block ALL Public Access (Security First!)
resource "aws_s3_bucket_public_access_block" "frontend_secure" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "frontend-oac"
  description                       = "OAC for frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```
*Instructor Note: Point out how `block_public_acls = true` guarantees no one can bypass CloudFront.*
