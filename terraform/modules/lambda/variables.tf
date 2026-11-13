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

variable "image_uri" {
  type        = string
  description = "ECR image URI for Lambda"
  default     = ""
}

variable "memory_size" {
  type        = number
  description = "Lambda memory in MB"
  default     = 512
}

variable "timeout" {
  type        = number
  description = "Lambda timeout in seconds"
  default     = 30
}

variable "iam_role_arn" {
  type        = string
  description = "Lambda execution role ARN"
}

variable "dynamodb_users_table" {
  type        = string
  description = "Users DynamoDB table name"
}

variable "dynamodb_urls_table" {
  type        = string
  description = "URLs DynamoDB table name"
}

variable "dynamodb_users_table_arn" {
  type        = string
  description = "Users DynamoDB table ARN"
}

variable "dynamodb_urls_table_arn" {
  type        = string
  description = "URLs DynamoDB table ARN"
}

variable "jwt_secret_arn" {
  type        = string
  description = "JWT secret ARN in Secrets Manager"
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

variable "base_url" {
  type        = string
  description = "Base URL for short links"
  default     = ""
}