# ============================================================
# IAM Module - Lambda Execution Role, Policies, Secrets Manager
# ============================================================

# Lambda Execution Role
resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# Lambda Basic Execution Policy (CloudWatch Logs + X-Ray)
resource "aws_iam_role_policy" "lambda_basic" {
  name = "${var.name_prefix}-lambda-basic"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# DynamoDB Access Policy
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.name_prefix}-lambda-dynamodb"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:ConditionCheckItem"
      ]
      Resource = [
        for arn in var.dynamodb_table_names : [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${arn}",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${arn}/index/*"
        ]
      ]
    }]
  })
}

# Secrets Manager Access for JWT Secret
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.name_prefix}-lambda-secrets"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = var.jwt_secret_arn != "" ? [var.jwt_secret_arn] : []
    }]
  })
}

# CloudWatch Metrics Access (for custom metrics)
resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name = "${var.name_prefix}-lambda-cloudwatch"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "cloudwatch:PutMetricData"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "cloudwatch:namespace" = "UrlShortener"
        }
      }
    }]
  })
}

# JWT Secret in Secrets Manager
resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.name_prefix}/jwt-secret"
  description = "JWT signing secret for URL Shortener API"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    SecretKey = var.jwt_secret_value != "" ? var.jwt_secret_value : random_password.jwt_secret.result
    Issuer    = "url-shortener-api"
    Audience  = "url-shortener-client"
    ExpirationInMinutes = 60
  })
}

# Generate random JWT secret if not provided
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
  override_special = "_-="
}

# Data sources for ARN construction
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Outputs
output "lambda_role_arn" {
  value       = aws_iam_role.lambda.arn
  description = "Lambda execution role ARN"
}

output "lambda_role_name" {
  value       = aws_iam_role.lambda.name
  description = "Lambda execution role name"
}

output "jwt_secret_arn" {
  value       = aws_secretsmanager_secret.jwt.arn
  description = "JWT secret ARN in Secrets Manager"
}

output "jwt_secret_name" {
  value       = aws_secretsmanager_secret.jwt.name
  description = "JWT secret name"
}