variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "url-shortener"
}

variable "domain_name" {
  description = "Custom domain name (optional, set to enable custom domain)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for custom domain"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN (us-east-1) for custom domain"
  type        = string
  default     = ""
}

# Lambda configuration
variable "lambda_image_uri" {
  description = "ECR image URI for Lambda function"
  type        = string
  default     = ""
}

variable "lambda_memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

# DynamoDB configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_ttl_attribute" {
  description = "TTL attribute name for auto-expiry"
  type        = string
  default     = "ExpiresAt"
}

# Frontend configuration
variable "frontend_build_path" {
  description = "Path to frontend build output"
  type        = string
  default     = "../frontend/build"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

# Monitoring
variable "alert_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "enable_xray" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
}

# Common tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}