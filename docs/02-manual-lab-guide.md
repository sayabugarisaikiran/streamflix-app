# Comprehensive Manual Lab Guide: StreamFlix Deployment

This document provides step-by-step instructions for your students to deploy the StreamFlix demo application entirely via the **AWS Management Console**. This lab covers critical configuration options across S3, CloudFront, Route 53, ACM, WAF, and API Gateway.

---

> [!NOTE]
> **Prerequisites for Students:** 
> 1. An AWS Account.
> 2. The `app/` folder containing `index.html`, `styles.css`, and `app.js` saved on their local computer.
> 3. A registered Domain Name (using Route 53 or external registrar).

---

## Phase 1: Security & Identity (Route 53 & ACM)

Before deploying the frontend, we must secure our domain routing and TLS/SSL certificates.

### Step 1.1: Route 53 Hosted Zone
1. Open **Route 53**. Click **Hosted zones**.
2. If using an AWS-purchased domain, a zone is already created. If external, click **Create hosted zone**.
3. **Domain name:** Enter your domain (e.g., `mydomain.com`).
4. **Type:** `Public hosted zone`. Click **Create**.
5. *(Instructor Note: Explain that NS and SOA records are created automatically. If external, students must update nameservers at their registrar).*

### Step 1.2: ACM (AWS Certificate Manager)
> [!WARNING]
> **CRITICAL:** Switch your AWS Region to **us-east-1 (N. Virginia)**. CloudFront *only* accepts ACM certificates from this specific region!

1. Open **Certificate Manager**. Click **Request a certificate**.
2. **Certificate type:** `Request a public certificate`.
3. **Domain names:**
   * Enter your root domain: `mydomain.com`
   * Click **Add another name to this certificate** and enter `*.mydomain.com` (Wildcard).
4. **Validation method:** `DNS validation` (Recommended & automated).
5. Click **Request**.
6. On the next screen, click into the certificate details UI. Click the **"Create records in Route 53"** button to automatically add the CNAME validation records. Wait for the status to change from *Pending validation* to **Issued** (takes ~3 minutes).

---

## Phase 2: Frontend Storage (Amazon S3)

We will use S3 purely for storage, leveraging CloudFront for public delivery.

### Step 2.1: Create the Bucket
1. Switch your region back to your preferred local region (e.g., `us-west-2` or `eu-central-1`).
2. Open **S3**. Click **Create bucket**.
3. **Bucket name:** `streamflix-frontend-[YOUR-NAME]-[RANDOM-NUMBER]`.
4. **Object Ownership:** Leave as `ACLs disabled`.
5. **Block Public Access settings:**
   * > [!IMPORTANT]
     > **LEAVE THIS CHECKED! "Block all public access" MUST remain ON.** This teaches the modern security paradigm. We will not use the older "Static Website Hosting" feature.
6. Click **Create bucket**.

### Step 2.2: Upload Files
1. Open your new bucket.
2. Click **Upload**, then **Add files**.
3. Select `index.html`, `styles.css`, and `app.js` from the `app/` directory.
4. Click **Upload**.

---

## Phase 3: Edge Delivery & Security (CloudFront & WAF)

This is the most critical networking phase. We will distribute the S3 content globally and attach a firewall.

### Step 3.1: Create CloudFront Distribution
1. Open **CloudFront**. Click **Create distribution**.
2. **Origin domain:** Select your S3 bucket from the dropdown.
3. **Origin path:** Leave blank.
4. **Origin access:** Select **Origin Access Control settings (recommended)**.
   * Click **Create control setting**, use the default name, and click **Create**.
   * *(Instructor Note: Explain that OAC replaces the older OAI and uses AWS SigV4 to securely sign requests from CloudFront to S3).*
5. **Default cache behavior:**
   * **Viewer protocol policy:** Select **Redirect HTTP to HTTPS**.
   * **Allowed HTTP methods:** `GET, HEAD`.
   * **Cache key and origin requests:** Use the recommended `Cache policy and origin request policy`.
6. **Web Application Firewall (WAF):**
   * Select **Enable security protections**. This automatically creates a WAF Web ACL blocking common vulnerabilities and rate limits IPs exceeding 100 requests/5 minutes.
7. **Settings:**
   * **Alternate domain name (CNAME):** Enter your desired URLs (e.g., `mydomain.com` and `www.mydomain.com`).
   * **Custom SSL certificate:** Select the ACM certificate you created in Phase 1 (if it doesn't appear, you forgot to create it in `us-east-1`!).
   * **Default root object:** Type `index.html`.
8. Click **Create distribution**.

### Step 3.2: Update S3 Bucket Policy
1. On the CloudFront distribution success screen, a yellow banner will say "The S3 bucket policy needs to be updated." Click **Copy policy**.
2. Go back to S3 -> Your Bucket -> **Permissions** tab.
3. Scroll to **Bucket policy**, click **Edit**, paste the copied JSON, and click **Save**. This grants CloudFront permission to read your private bucket.

---

## Phase 4: DNS Routing (Route 53)

Connect the user-friendly domain name to the global CloudFront distribution.

1. Open **Route 53** -> **Hosted zones** -> Your domain.
2. Click **Create record**.
3. **Record name:** Leave blank for the root domain (or type `www`).
4. **Record type:** `A - Routes traffic to an IPv4 address and some AWS resources`.
5. **Alias:** Toggle to **YES**.
   * **Route traffic to:** Select `Alias to CloudFront distribution`.
   * **Choose distribution:** Select the CloudFront URL (`dxxxxx.cloudfront.net`).
6. Click **Create records**.
7. *(Testing: Go to your domain name. View the padlock! Check the CSS!)*

---

## Phase 5: Serverless Backend (API Gateway & Lambda)

Now we will build the backend so the "Test Backend API" button works.

### Step 5.1: Create the Lambda Function
1. Open **Lambda** -> **Create function**.
2. **Author from scratch**. Name: `streamflix_backend`.
3. **Runtime:** `Python 3.x`. Click **Create function**.
4. In the Code source pane, replace the code with:
   ```python
   import json
   def lambda_handler(event, context):
       return {
           "statusCode": 200,
           "headers": {
               "Access-Control-Allow-Origin": "*",
               "Access-Control-Allow-Headers": "Content-Type",
               "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
           },
           "body": json.dumps({"message": "Data successfully fetched from AWS Lambda!"})
       }
   ```
5. Click **Deploy**.

### Step 5.2: Create the API Gateway
1. Open **API Gateway**. Scroll to **HTTP API** and click **Build**.
2. **Integrations:** Click **Add integration**. Select **Lambda**. Choose the `streamflix_backend` function.
3. **API name:** `streamflix-api`. Click Next.
4. **Configure routes:**
   * **Method:** `GET`
   * **Resource path:** `/hello`
   * **Integration target:** Your Lambda function.
5. Click Next through the stages (default `$default` stage is fine) and click **Create**.
6. **Enable CORS:**
   * On the left menu of your API, click **CORS**.
   * Click **Configure**.
   * **Access-Control-Allow-Origins:** Enter `*` (or your domain url).
   * **Access-Control-Allow-Methods:** Select `GET`, `OPTIONS`.
   * **Access-Control-Allow-Headers:** Enter `*`.
   * Save.

### Step 5.3: Connect Frontend to Backend
1. In API Gateway, copy the **Invoke URL**.
2. On your local computer, open `app/app.js`.
3. Locate `const API_GATEWAY_URL` at the top of the file.
4. Replace the string with your Invoke URL + `/hello`. Example:
   `const API_GATEWAY_URL = 'https://abc123xyz.execute-api.us-east-1.amazonaws.com/hello';`
5. Go to your **S3 Bucket**, upload the modified `app.js` to overwrite the old one.
6. Go to **CloudFront**, click **Invalidations**, and create an invalidation for `/*` so the browser downloads the new JS file.
7. Go to your website, click the button, and watch it hit the backend successfully!
