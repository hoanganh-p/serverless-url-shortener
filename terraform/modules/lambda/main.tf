# ============================================================
# Lambda Module - Container-based Lambda Function
# ============================================================

# Lambda Function (Container Image)
resource "aws_lambda_function" "api" {
  function_name = "${var.name_prefix}-api"
  package_type  = "Image"
  role          = var.iam_role_arn

  image_uri = var.image_uri != "" ? var.image_uri : "public.ecr.aws/lambda/dotnet:10-${var.environment == "prod" ? "latest" : "latest"}"

  memory_size = var.memory_size
  timeout     = var.timeout

  # Environment variables
  environment {
    variables = {
      ASPNETCORE_ENVIRONMENT                 = var.environment == "prod" ? "Production" : "Development"
      AWS_REGION                             = data.aws_region.current.name
      DYNAMODB_USERS_TABLE                   = var.dynamodb_users_table
      DYNAMODB_URLS_TABLE                    = var.dynamodb_urls_table
      JWT_SECRET_ARN                         = var.jwt_secret_arn
      JwtSettings__Issuer                    = "url-shortener-api"
      JwtSettings__Audience                  = "url-shortener-client"
      JwtSettings__ExpirationInMinutes       = "60"
      AllowedOrigins                         = var.allowed_origins
      BaseUrl                                = var.base_url
      # X-Ray
      AWS_XRAY_DAEMON_ADDRESS                = var.enable_xray ? "127.0.0.1:2000" : ""
      AWS_XRAY_CONTEXT_MISSING               = "LOG_ERROR"
    }
  }

  # X-Ray Tracing
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  # Logging configuration
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda.name
    system_log_level = var.environment == "prod" ? "WARN" : "INFO"
    application_log_level = "DEBUG"
  }

  # Ephemeral storage (for larger containers)
  ephemeral_storage {
    size = 512
  }

  # VPC config (optional - uncomment if needed)
  # vpc_config {
  #   subnet_ids         = var.subnet_ids
  #   security_group_ids = [aws_security_group.lambda.id]
  # }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_secrets
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}-api"
  retention_in_days = var.environment == "prod" ? 30 : 7
  tags              = var.tags
}

# Lambda Alias for blue/green or stable routing
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
  description      = "Live traffic alias"
}

# Outputs
output "function_arn" {
  value       = aws_lambda_function.api.arn
  description = "Lambda function ARN"
}

output "function_name" {
  value       = aws_lambda_function.api.function_name
  description = "Lambda function name"
}

output "function_version" {
  value       = aws_lambda_function.api.version
  description = "Lambda function version"
}

output "alias_arn" {
  value       = aws_lambda_alias.live.arn
  description = "Lambda live alias ARN"
}

data "aws_region" "current" {}