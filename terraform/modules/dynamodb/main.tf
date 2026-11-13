# ============================================================
# DynamoDB Module - Single-table design with GSIs
# ============================================================

# Users Table
resource "aws_dynamodb_table" "users" {
  name           = "${var.name_prefix}-users"
  billing_mode   = var.billing_mode
  hash_key       = "PK"
  range_key      = "SK"
  deletion_protection = var.environment == "prod"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI for email lookups
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}

# ShortUrls Table
resource "aws_dynamodb_table" "urls" {
  name           = "${var.name_prefix}-urls"
  billing_mode   = var.billing_mode
  hash_key       = "PK"
  range_key      = "SK"
  deletion_protection = var.environment == "prod"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI for short code lookups (redirect path)
  global_secondary_index {
    name            = "CodeIndex"
    hash_key        = "SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}

# Outputs
output "users_table_name" {
  value       = aws_dynamodb_table.users.name
  description = "Users table name"
}

output "users_table_arn" {
  value       = aws_dynamodb_table.users.arn
  description = "Users table ARN"
}

output "urls_table_name" {
  value       = aws_dynamodb_table.urls.name
  description = "ShortUrls table name"
}

output "urls_table_arn" {
  value       = aws_dynamodb_table.urls.arn
  description = "ShortUrls table ARN"
}