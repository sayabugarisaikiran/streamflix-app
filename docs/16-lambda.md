# AWS Lambda & Serverless Compute (Complete Teaching Script)

> **For the trainer:** Word-for-word classroom script. 🗣️ = what you SAY. 🖥️ = what you DO on screen. ❓ = questions for students. ~2 hour session.

---

## Part 1: The Evolution of Compute (20 minutes)

### 🗣️ Opening Hook

*"Welcome back. Today we are going to talk about a paradigm shift in how we build applications. We are going to talk about 'Serverless'."*

*"To understand why Serverless is such a big deal, we have to look at the history of how we've run code:"*

1. **Physical Servers (On-Premises):** *"Twenty years ago, you bought a physical metal box, plugged it into a wall, installed Linux, and ran your code. If you needed more power, you waited 3 months for Dell to ship you another box."*
2. **Virtual Machines (EC2):** *"Then came the cloud. You click a button, and in 2 minutes you have a virtual server. But... you still have to patch the OS. You still have to manage SSH keys. And crucially, if your app gets zero traffic at 3 AM, you are STILL paying for that EC2 instance sitting there doing nothing."*
3. **Containers (Docker/ECS):** *"Then we packaged our apps into lightweight containers. Better resource usage, faster deployments. But you still have to manage the underlying cluster of servers running those containers."*

*"What if you could just write your code, hand it to AWS, and say: 'Run this whenever a user clicks a button. I don't care how you do it. I don't want to see a server. And I only want to pay for the exact milliseconds my code is actively running.'?"*

*"That is **AWS Lambda**."*

---

## Part 2: How AWS Lambda Works (30 minutes)

### 🗣️ The Core Concept

*"AWS Lambda is a Serverless compute service. 'Serverless' does NOT mean there are no servers. There are absolutely servers in an AWS data center. 'Serverless' means YOU do not manage the servers."*

*"With Lambda, you deploy a **Function**—a small piece of code written in Python, Node.js, Java, Go, etc. That function just sits there, dormant, costing you $0.00."*

*"When an **Event** happens—like a user making an HTTP request, or a file being uploaded to S3—AWS instantly grabs a tiny piece of computing power, loads your code into it, runs it, returns the result, and then destroys the computing environment."*

### 🗣️ Pricing: The Millisecond Model

*"This changes how we pay for computing."*

*"With EC2, you pay per hour or per second that the instance is 'Running', regardless of whether it is processing requests or sitting idle."*

*"With Lambda, you pay for two things:"*
1. **Number of Requests:** *(First 1 million per month are free).*
2. **Compute Time:** *"You are billed for the exact duration your code executes, measured in **milliseconds**. If your code takes 200 milliseconds to run, you pay for exactly 200 milliseconds. If your code doesn't run for a whole week, your bill is literally zero dollars."*

### 🗣️ 3 Key Components of a Lambda Function

*"When you write a Lambda function, there are three concepts you must understand:"*

1. **The Handler:** *"This is the entry point. It's the main function that AWS calls when your Lambda is triggered. If your code was a book, the handler is Chapter 1, Page 1."*
2. **The Event Object:** *"This is the data passed INTO your function. If an API Gateway triggers your Lambda, the `event` object contains the HTTP headers, the URL path, and the JSON body the user sent."*
3. **The Context Object:** *"This contains metadata about the execution environment itself. How much time is remaining before the function times out? What is the AWS request ID?"*

---

## Part 3: Triggers and Integrations (20 minutes)

### 🗣️ Event-Driven Architecture

*"Lambda functions don't just run randomly. They are **Event-Driven**. They must be triggered by something. We call these **Event Sources**."*

*"Lambda integrates natively with almost every service in AWS. Here are the most common patterns:"*

1. **API Gateway (Synchronous):** *"A user goes to your website and clicks 'Login'. The browser sends an HTTP request to Amazon API Gateway. API Gateway triggers your Lambda function. The Lambda function checks the database, generates a token, and returns it to API Gateway, which sends the HTTP response back to the user."*
2. **Amazon S3 (Asynchronous):** *"A user uploads a high-resolution profile picture to an S3 bucket. S3 automatically triggers a Lambda function. The Lambda function takes the image, compresses it, creates a thumbnail, and saves the thumbnail back to a different S3 bucket. The user didn't wait for this; it happened in the background."*
3. **EventBridge / CloudWatch Events (Scheduled):** *"You want a script to run every night at 2:00 AM to clean up old database records. You create a cron job in EventBridge that triggers your Lambda function."*
4. **Amazon SQS / DynamoDB Streams (Event Source Mapping):** *"Lambda can poll a queue or a database stream, grabbing batches of records and processing them continuously."*

---

## Part 4: Lambda Limitations & "Gotchas" (30 minutes)

### 🗣️ The Limits

*"Lambda is incredible, but it is not a silver bullet. You cannot run every application on Lambda. There are strict hard limits imposed by AWS."*

1. **Execution Timeout:** *"A Lambda function can run for a maximum of **15 minutes**. Period. If you have a video rendering script that takes 30 minutes, it WILL fail on Lambda. You must use ECS or EC2 for that."*
2. **Memory/CPU Allocation:** *"You do not pick a CPU size for Lambda. You only pick Memory (RAM), from 128 MB up to 10 GB. **CPU power is allocated proportionally to the memory you choose.** If your function is calculating heavy math and is too slow, you give it more RAM, which automatically gives it more CPU power."*
3. **Storage (`/tmp`):** *"Lambda functions are stateless. When the function ends, the server is destroyed. If you need to temporarily download a file to process it, you can use the `/tmp` directory, which gives you up to 10 GB of ephemeral storage."*

### 🗣️ The Biggest Problem: "Cold Starts"

*"This is the most important concept to understand about Serverless performance."*

*"Imagine nobody has visited your website in 3 hours. Your Lambda function is dormant."*
*"A user clicks a link. AWS has to:"*
1. *Find an available server in their massive pool.*
2. *Download your code.*
3. *Start the runtime environment (like spinning up the Node.js or Java engine).*
4. *Run your code.*

*"Steps 1-3 take time. Maybe 500 milliseconds, maybe 2 seconds (especially for Java). This delay is called a **Cold Start**. The user experiences a slow page load."*

*"But... what happens when a second user clicks the link 10 seconds later? AWS says: 'Hey, I still have that environment running from the last guy! Let's just use that.' The code runs instantly. This is called a **Warm Start**."*

*"If you have a high-traffic app, most requests are Warm Starts. But Cold Starts are a major issue for latency-sensitive applications. To fix this, AWS offers **Provisioned Concurrency**, where you pay a little bit extra to keep a certain number of environments 'warm' and ready to go at all times."*

---

## Part 5: Hands-on Demo (20 minutes)

### 🖥️ Demo: S3 Thumbnail Generator

> **Trainer Note:** You need two S3 buckets: `my-images-raw` and `my-images-thumbnails`. Have a simple Python snippet ready to print the event object.

1. **Create the Function:** *"Let's go to the Lambda Console. Click **Create function**. We'll call it `ImageProcessor`. Runtime: `Python 3.10`. Click Create."*
2. **The Code:** *"Look at the code editor in the console. Notice the `def lambda_handler(event, context):` structure. Let's add a `print(event)` statement so we can see what data S3 sends us."*
3. **Add Trigger:** *"Click **Add trigger**. Select **S3**. Choose our `my-images-raw` bucket. Event type: `All object create events`. This tells AWS: anytime a file is created here, run my code."*
4. **Test it:** *"Let's go to S3 and upload a photo called `vacation.jpg` to the raw bucket."*
5. **View the Logs:** *"How do we know if it worked? Since there are no servers to SSH into, all Lambda `print()` statements are automatically sent to **Amazon CloudWatch Logs**."*
6. *"Let's go to CloudWatch. We see our log stream. Look at the `event` object! It's a huge JSON payload. Right there in the middle, we can extract `bucket.name` and `object.key`. Our Python code could now download `vacation.jpg`, shrink it, and upload it to the thumbnail bucket."*

---

## Part 6: Interview Questions & Wrap-up (10 minutes)

### 🗣️ Top Serverless & Lambda Interview Questions

1. **What is the maximum execution time for a Lambda function?**
   * → *15 minutes.*

2. **How do you increase the CPU processing power of a Lambda function?**
   * → *You cannot directly increase CPU. You must increase the allocated Memory (RAM), and AWS automatically provisions more CPU power proportionally.*

3. **What is a "Cold Start" in AWS Lambda?**
   * → *The latency experienced when a Lambda function is invoked after being idle. AWS has to allocate compute resources, download the code, and start the runtime environment before executing the handler.*

4. **Your Lambda function needs to process a 2GB file. Where can it store this file temporarily during execution?**
   * → *In the `/tmp` directory, which provides up to 10 GB of ephemeral storage.*

5. **A Lambda function writes data to a local file system. Will that data be there the next time the function runs?**
   * → *Maybe, if it's a "warm start" reusing the same execution environment. But you should NEVER rely on it. Lambda is stateless. Any persistent data must be saved to a database (DynamoDB) or external storage (S3).*

### 🗣️ Wrap up

*"Serverless changes everything. It forces us to build small, single-purpose functions instead of giant monolithic applications. It scales instantly from zero to tens of thousands of concurrent requests, and you only pay for exactly what you use. Once you learn to build Serverless apps, you'll never want to manage an EC2 server again."*
