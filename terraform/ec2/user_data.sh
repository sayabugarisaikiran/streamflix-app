#!/bin/bash
# ================================================================
#  StreamFlix EC2 User Data Script
#  Installs nginx, deploys the app, and writes instance metadata
# ================================================================
set -e

# Update and install nginx
yum update -y
amazon-linux-extras install nginx1 -y 2>/dev/null || yum install nginx -y

# Start nginx
systemctl enable nginx
systemctl start nginx

# Deploy app files
rm -rf /usr/share/nginx/html/*
aws s3 cp s3://${S3_BUCKET}/app/ /usr/share/nginx/html/ --recursive 2>/dev/null || true

# If S3 copy failed (no bucket configured), copy from the embedded files
if [ ! -f /usr/share/nginx/html/index.html ]; then
    echo "S3 copy failed or not configured — will use files from /tmp/streamflix-app/"
fi

# IMDSv2 — get a token first, then fetch metadata
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

# Write metadata.json so the frontend can display it
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

# Configure nginx for health check endpoint
cat > /etc/nginx/conf.d/health.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Health check for ALB
    location /health {
        access_log off;
        return 200 '{"status":"healthy"}';
        add_header Content-Type application/json;
    }

    # Serve metadata (no caching so ALB rotation is visible)
    location /metadata.json {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# Remove default nginx config that conflicts
rm -f /etc/nginx/conf.d/default.conf

# Restart nginx with new config
nginx -t && systemctl restart nginx

echo "StreamFlix deployed successfully on $INSTANCE_ID"
