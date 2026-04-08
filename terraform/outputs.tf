output "website_url" {
  description = "The public URL of the StreamFlix website"
  value       = "https://${local.full_domain}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = aws_cloudfront_distribution.cdn.id
}

output "api_gateway_url" {
  description = "The invoke URL for your API Gateway backend"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/hello"
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "next_steps" {
  description = "Instructions after deployment"
  value       = <<-EOT

    ╔═══════════════════════════════════════════════════════════╗
    ║  StreamFlix deployed successfully!                       ║
    ╠═══════════════════════════════════════════════════════════╣
    ║                                                           ║
    ║  1. Update app.js with the API Gateway URL above          ║
    ║  2. Re-upload app.js to S3:                               ║
    ║     aws s3 cp ../app/app.js s3://${aws_s3_bucket.frontend.id}/ ║
    ║  3. Invalidate CloudFront cache:                          ║
    ║     aws cloudfront create-invalidation \                  ║
    ║       --distribution-id ${aws_cloudfront_distribution.cdn.id} \           ║
    ║       --paths "/*"                                        ║
    ║  4. Visit: https://${local.full_domain}                   ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
  EOT
}
