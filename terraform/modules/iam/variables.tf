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

variable "dynamodb_table_names" {
  type        = list(string)
  description = "DynamoDB table names for policy"
  default     = []
}

variable "enable_xray" {
  type        = bool
  description = "Enable X-Ray tracing permissions"
  default     = true
}

variable "jwt_secret_value" {
  type        = string
  description = "JWT secret value (optional, will generate if empty)"
  default     = ""
  sensitive   = true
}