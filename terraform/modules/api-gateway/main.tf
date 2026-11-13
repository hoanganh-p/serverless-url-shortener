# ============================================================
# API Gateway Module - HTTP API (cheaper, faster than REST API)
# ============================================================

# HTTP API
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "URL Shortener HTTP API"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins     = var.allowed_origins != "" ? [var.allowed_origins] : ["*"]
    max_age           = 86400
  }

  tags = var.tags
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.lambda_function_arn
  payload_format_version = "2.0"
  timeout_milliseconds = 30000
}

# Routes
resource "aws_apigatewayv2_route" "create" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /api/url/create"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "redirect" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /{code}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_user_urls" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /api/url/user/all"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_url_details" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /api/url/{code}/details"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "update_url" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "PUT /api/url/{code}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_url" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "DELETE /api/url/{code}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      requestId       = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    logging_level           = "INFO"
    data_trace_enabled      = var.enable_xray
    throttling_rate_limit   = 1000
    throttling_burst_limit  = 2000
  }

  route_settings = {
    "GET /{code}" = {
      throttling_rate_limit  = 5000
      throttling_burst_limit = 10000
    }
  }
}

# Lambda Permission for API Gateway to invoke
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# Custom Domain (optional)
resource "aws_apigatewayv2_domain_name" "custom" {
  count = var.domain_name != "" && var.certificate_arn != "" ? 1 : 0

  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

resource "aws_apigatewayv2_api_mapping" "custom" {
  count = var.domain_name != "" && var.certificate_arn != "" ? 1 : 0

  api_id      = aws_apigatewayv2_api.http.id
  domain_name = aws_apigatewayv2_domain_name.custom[0].id
  stage       = aws_apigatewayv2_stage.default.name
}

# Route53 Record for Custom Domain (optional)
resource "aws_route53_record" "api_custom" {
  count = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.custom[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = true
  }
}

# CloudWatch Log Group for API Gateway Access Logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.environment == "prod" ? 30 : 7
  tags              = var.tags
}

# WAF Association (optional - requires WAF Web ACL)
# resource "aws_wafv2_web_acl_association" "api" {
#   resource_arn = aws_apigatewayv2_stage.default.arn
#   web_acl_arn  = var.waf_web_acl_arn
# }

# Outputs
output "api_id" {
  value       = aws_apigatewayv2_api.http.id
  description = "HTTP API ID"
}

output "api_endpoint" {
  value       = aws_apigatewayv2_api.http.api_endpoint
  description = "Default API endpoint"
}

output "api_base_url" {
  value       = "https://${aws_apigatewayv2_api.http.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
  description = "API base URL"
}

output "custom_domain_url" {
  value       = var.domain_name != "" ? "https://${var.domain_name}" : ""
  description = "Custom domain URL if configured"
}

output "stage_name" {
  value       = aws_apigatewayv2_stage.default.name
  description = "Stage name"
}

data "aws_region" "current" {}