# ============================================================
# Root Module Outputs
# ============================================================

output "api_endpoint" {
  value       = module.api_gateway.api_endpoint
  description = "Default API Gateway endpoint"
}

output "api_base_url" {
  value       = module.api_gateway.api_base_url
  description = "API base URL"
}

output "custom_api_url" {
  value       = module.api_gateway.custom_domain_url
  description = "Custom domain API URL"
}

output "frontend_url" {
  value       = module.frontend.distribution_url
  description = "CloudFront distribution URL for frontend"
}

output "custom_frontend_url" {
  value       = module.frontend.custom_domain_url
  description = "Custom domain frontend URL"
}

output "lambda_function_name" {
  value       = module.lambda.function_name
  description = "Lambda function name"
}

output "lambda_function_arn" {
  value       = module.lambda.function_arn
  description = "Lambda function ARN"
}

output "dynamodb_users_table" {
  value       = module.dynamodb.users_table_name
  description = "Users DynamoDB table name"
}

output "dynamodb_urls_table" {
  value       = module.dynamodb.urls_table_name
  description = "URLs DynamoDB table name"
}

output "cloudfront_distribution_id" {
  value       = module.frontend.distribution_id
  description = "CloudFront distribution ID"
}

output "s3_bucket_name" {
  value       = module.frontend.bucket_name
  description = "Frontend S3 bucket name"
}

output "monitoring_dashboard" {
  value       = module.monitoring.dashboard_name
  description = "CloudWatch dashboard name"
}

output "sns_topic_arn" {
  value       = module.monitoring.sns_topic_arn
  description = "SNS topic ARN for alarms"
}