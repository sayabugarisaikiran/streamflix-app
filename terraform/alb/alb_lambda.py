"""
StreamFlix ALB Backend — Lambda Handler
Invoked by Application Load Balancer (ALB)
Note: ALB Lambda payload format is DIFFERENT from API Gateway!
"""
import json
from datetime import datetime, timezone


def lambda_handler(event, context):
    """Handle incoming ALB requests."""

    # ALB sends a different event format than API Gateway
    path = event.get("path", "/")
    method = event.get("httpMethod", "GET")
    headers = event.get("headers", {})
    source_ip = headers.get("x-forwarded-for", "unknown")

    print(f"[StreamFlix ALB] {method} {path} from {source_ip}")

    # Health check endpoint — ALB pings this
    if path == "/health":
        return {
            "statusCode": 200,
            "statusDescription": "200 OK",
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "healthy", "service": "streamflix-alb"}),
            "isBase64Encoded": False,
        }

    # Default response
    return {
        "statusCode": 200,
        "statusDescription": "200 OK",
        "headers": {
            "Content-Type": "application/json",
            "X-Powered-By": "StreamFlix-ALB",
        },
        "body": json.dumps({
            "message": "Hello from StreamFlix ALB Backend!",
            "served_by": "Application Load Balancer → Lambda",
            "path": path,
            "method": method,
            "source_ip": source_ip,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }),
        "isBase64Encoded": False,
    }
