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

variable "build_path" {
  type        = string
  description = "Path to frontend build output"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class"
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_100", "PriceClass_200"], var.price_class)
    error_message = "Invalid price class."
  }
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

variable "api_base_url" {
  type        = string
  description = "API base URL for frontend config"
  default     = ""
}