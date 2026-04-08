"""
StreamFlix Backend — AWS Lambda Handler
Invoked via API Gateway HTTP API (v2 payload format)
"""
import json
import os
from datetime import datetime, timezone


def lambda_handler(event, context):
    """Handle incoming API Gateway requests."""

    # Log the event for CloudWatch debugging
    print(f"[StreamFlix] Received event: {json.dumps(event)}")

    # Extract useful info from the event
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "UNKNOWN")
    source_ip = event.get("requestContext", {}).get("http", {}).get("sourceIp", "unknown")
    user_agent = event.get("headers", {}).get("user-agent", "unknown")
    path = event.get("rawPath", "/")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-App-Platform,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        },
        "body": json.dumps({
            "message": "Welcome to StreamFlix! Data fetched securely from Lambda behind API Gateway.",
            "service": os.environ.get("APP_NAME", "StreamFlix"),
            "environment": os.environ.get("ENVIRONMENT", "development"),
            "request": {
                "method": http_method,
                "path": path,
                "sourceIp": source_ip,
                "userAgent": user_agent,
            },
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }),
    }
