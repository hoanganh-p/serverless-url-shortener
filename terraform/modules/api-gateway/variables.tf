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

variable "lambda_function_arn" {
  type        = string
  description = "Lambda function ARN"
}

variable "lambda_function_name" {
  type        = string
  description = "Lambda function name"
}

variable "domain_name" {
  type        = string
  description = "Custom domain name"
  default     = ""
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN (us-east-1)"
  default     = ""
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID"
  default     = ""
}

variable "enable_xray" {
  type        = bool
  description = "Enable X-Ray tracing"
  default     = true
}

variable "allowed_origins" {
  type        = string
  description = "CORS allowed origins"
  default     = "*"
}