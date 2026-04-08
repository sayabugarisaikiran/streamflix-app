#!/bin/bash
# ================================================================
#  StreamFlix — Deploy app to EC2 instances
#
#  Usage:
#    chmod +x deploy_to_ec2.sh
#    ./deploy_to_ec2.sh <key-pair-file.pem> <instance-1-ip> [instance-2-ip]
#
#  Example:
#    ./deploy_to_ec2.sh ~/.ssh/my-key.pem 54.230.10.42 34.201.55.88
# ================================================================
set -e

KEY_FILE=$1
IP1=$2
IP2=$3

if [ -z "$KEY_FILE" ] || [ -z "$IP1" ]; then
    echo "Usage: $0 <key-file.pem> <instance-1-ip> [instance-2-ip]"
    echo ""
    echo "Example: $0 ~/.ssh/my-key.pem 54.230.10.42 34.201.55.88"
    exit 1
fi

APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"

echo "📦 App directory: $APP_DIR"
echo ""

deploy_to_instance() {
    local ip=$1
    local label=$2

    echo "═══════════════════════════════════════"
    echo "🚀 Deploying to $label ($ip)..."
    echo "═══════════════════════════════════════"

    # Wait for instance to be ready
    echo "⏳ Waiting for SSH to be ready..."
    for i in $(seq 1 30); do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@"$ip" "echo ready" 2>/dev/null; then
            break
        fi
        echo "   Attempt $i/30..."
        sleep 10
    done

    # Copy app files
    echo "📂 Uploading app files..."
    scp -o StrictHostKeyChecking=no -i "$KEY_FILE" -r \
        "$APP_DIR/index.html" \
        "$APP_DIR/styles.css" \
        "$APP_DIR/app.js" \
        "$APP_DIR/error.html" \
        ec2-user@"$ip":/tmp/

    # Move files to nginx directory and regenerate metadata
    echo "🔧 Installing files and regenerating metadata..."
    ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@"$ip" <<'REMOTE_SCRIPT'
        sudo cp /tmp/index.html /tmp/styles.css /tmp/app.js /tmp/error.html /usr/share/nginx/html/

        # Regenerate metadata.json with instance info
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

        sudo tee /usr/share/nginx/html/metadata.json > /dev/null <<EOF
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

        # Ensure nginx config has health check
        if [ ! -f /etc/nginx/conf.d/health.conf ]; then
            sudo tee /etc/nginx/conf.d/health.conf > /dev/null <<'NGINX'
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
        add_header Pragma "no-cache";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX
            sudo rm -f /etc/nginx/conf.d/default.conf
        fi

        sudo nginx -t && sudo systemctl restart nginx
        echo "✅ Nginx restarted successfully"
REMOTE_SCRIPT

    echo "✅ $label deployed! Visit: http://$ip"
    echo ""
}

# Deploy to Instance 1
deploy_to_instance "$IP1" "Instance-1"

# Deploy to Instance 2 (if provided)
if [ -n "$IP2" ]; then
    deploy_to_instance "$IP2" "Instance-2"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║        ✅ Deployment Complete!               ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Instance 1: http://$IP1                     "
if [ -n "$IP2" ]; then
echo "║  Instance 2: http://$IP2                     "
fi
echo "║                                              ║"
echo "║  Verify:                                     ║"
echo "║    curl http://$IP1/metadata.json            "
echo "║    curl http://$IP1/health                   "
echo "╚══════════════════════════════════════════════╝"
