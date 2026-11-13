variable "name_prefix" {
  type        = string
  description = "Resource name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "tags" {
  type        = map(string)
  description = "Tags for resources"
  default     = {}
}

variable "lambda_function_name" {
  type        = string
  description = "Lambda function name"
}

variable "api_gateway_id" {
  type        = string
  description = "API Gateway API ID"
}

variable "dynamodb_users_table" {
  type        = string
  description = "DynamoDB Users table name"
}

variable "dynamodb_urls_table" {
  type        = string
  description = "DynamoDB URLs table name"
}

variable "cloudfront_distribution_id" {
  type        = string
  description = "CloudFront distribution ID"
}

variable "alert_email" {
  type        = string
  description = "Email for alarm notifications"
  default     = ""
}

variable "enable_xray" {
  type        = bool
  description = "Enable X-Ray tracing"
  default     = true
}