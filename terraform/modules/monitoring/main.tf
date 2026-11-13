# ============================================================
# Monitoring Module - CloudWatch Dashboards, Alarms, Log Groups
# ============================================================

# SNS Topic for Alarms
resource "aws_sns_topic" "alerts" {
  count = var.alert_email != "" ? 1 : 0
  name  = "${var.name_prefix}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Groups (additional to Lambda/API Gateway)
resource "aws_cloudwatch_log_group" "dynamodb" {
  name              = "/aws/dynamodb/${var.name_prefix}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  tags              = var.tags
}

# ============================================================
# CloudWatch Alarms
# ============================================================

# Lambda Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  alarm_description   = "Lambda function errors > 5 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.name_prefix}-lambda-duration"
  alarm_description   = "Lambda p99 duration > 10 seconds"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "p99"
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.name_prefix}-lambda-throttles"
  alarm_description   = "Lambda throttles > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_invocations" {
  alarm_name          = "${var.name_prefix}-lambda-no-invocations"
  alarm_description   = "No Lambda invocations for 15 minutes (possible outage)"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "breaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = var.tags
}

# API Gateway Alarms
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.name_prefix}-api-5xx"
  alarm_description   = "API Gateway 5xx errors > 10 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ApiId = var.api_gateway_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_4xx" {
  alarm_name          = "${var.name_prefix}-api-4xx"
  alarm_description   = "API Gateway 4xx errors > 100 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ApiId = var.api_gateway_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.name_prefix}-api-latency"
  alarm_description   = "API Gateway p99 latency > 5 seconds"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "p99"
  threshold           = 5000
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ApiId = var.api_gateway_id
  }

  tags = var.tags
}

# DynamoDB Alarms
resource "aws_cloudwatch_metric_alarm" "dynamodb_users_throttles" {
  alarm_name          = "${var.name_prefix}-dynamodb-users-throttles"
  alarm_description   = "DynamoDB Users table throttled requests > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    TableName = var.dynamodb_users_table
  }

  tags = var_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_urls_throttles" {
  alarm_name          = "${var.name_prefix}-dynamodb-urls-throttles"
  alarm_description   = "DynamoDB URLs table throttled requests > 0"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    TableName = var.dynamodb_urls_table
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_users_consumed_rcu" {
  alarm_name          = "${var.name_prefix}-dynamodb-users-rcu"
  alarm_description   = "DynamoDB Users consumed RCU > 80% of provisioned (if not on-demand)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    TableName = var.dynamodb_users_table
  }

  tags = var.tags
}

# CloudFront Alarms
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  alarm_name          = "${var.name_prefix}-cloudfront-4xx"
  alarm_description   = "CloudFront 4xx error rate > 5%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 0.05
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "${var.name_prefix}-cloudfront-5xx"
  alarm_description   = "CloudFront 5xx error rate > 1%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 0.01
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_cache_hit_rate" {
  alarm_name          = "${var.name_prefix}-cloudfront-cache-hit-rate"
  alarm_description   = "CloudFront cache hit rate < 80%"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 0.80
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.tags
}

# ============================================================
# CloudWatch Dashboard
# ============================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"
  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Lambda Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Lambda - Invocations, Errors, Duration"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, {stat: "Sum", label: "Invocations"}],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name, {stat: "Sum", label: "Errors", color: "#FF0000"}],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, {stat: "Average", label: "Avg Duration (ms)", yAxis: "right"}],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, {stat: "p99", label: "P99 Duration (ms)", yAxis: "right"}],
            ["AWS/Lambda", "Throttles", "FunctionName", var.lambda_function_name, {stat: "Sum", label: "Throttles", color: "#FFA500"}]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Lambda - Concurrent Executions & Memory"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.lambda_function_name, {stat: "Maximum", label: "Concurrent Executions"}],
            ["AWS/Lambda", "UnreservedConcurrentExecutions", "FunctionName", var.lambda_function_name, {stat: "Maximum", label: "Unreserved Concurrent"}]
          ]
        }
      },

      # Row 2: API Gateway Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "API Gateway - Requests, Errors, Latency"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.api_gateway_id, {stat: "Sum", label: "Total Requests"}],
            ["AWS/ApiGateway", "4XXError", "ApiId", var.api_gateway_id, {stat: "Sum", label: "4xx Errors", color: "#FFA500"}],
            ["AWS/ApiGateway", "5XXError", "ApiId", var.api_gateway_id, {stat: "Sum", label: "5xx Errors", color: "#FF0000"}],
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_id, {stat: "Average", label: "Avg Latency (ms)", yAxis: "right"}],
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_id, {stat: "p99", label: "P99 Latency (ms)", yAxis: "right"}]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "API Gateway - Integration Latency"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "IntegrationLatency", "ApiId", var.api_gateway_id, {stat: "Average", label: "Avg Integration Latency"}],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiId", var.api_gateway_id, {stat: "p99", label: "P99 Integration Latency"}]
          ]
        }
      },

      # Row 3: DynamoDB Metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title = "DynamoDB Users Table - Reads/Writes/Throttles"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_users_table, {stat: "Sum", label: "Consumed RCU"}],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.dynamodb_users_table, {stat: "Sum", label: "Consumed WCU"}],
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", var.dynamodb_users_table, {stat: "Sum", label: "Throttled Requests", color: "#FF0000"}],
            ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", var.dynamodb_users_table, {stat: "Sum", label: "Read Throttles", color: "#FFA500"}],
            ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", var.dynamodb_users_table, {stat: "Sum", label: "Write Throttles", color: "#FFA500"}]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title = "DynamoDB URLs Table - Reads/Writes/Throttles"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_urls_table, {stat: "Sum", label: "Consumed RCU"}],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.dynamodb_urls_table, {stat: "Sum", label: "Consumed WCU"}],
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", var.dynamodb_urls_table, {stat: "Sum", label: "Throttled Requests", color: "#FF0000"}],
            ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", var.dynamodb_urls_table, {stat: "Sum", label: "Read Throttles", color: "#FFA500"}],
            ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", var.dynamodb_urls_table, {stat: "Sum", label: "Write Throttles", color: "#FFA500"}]
          ]
        }
      },

      # Row 4: CloudFront Metrics
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title = "CloudFront - Requests, Errors, Cache Hit Rate"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, {stat: "Sum", label: "Total Requests"}],
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id, {stat: "Average", label: "4xx Error Rate", yAxis: "right"}],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, {stat: "Average", label: "5xx Error Rate", yAxis: "right"}],
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", var.cloudfront_distribution_id, {stat: "Average", label: "Cache Hit Rate", yAxis: "right"}]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title = "CloudFront - Latency & Data Transfer"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["AWS/CloudFront", "OriginLatency", "DistributionId", var.cloudfront_distribution_id, {stat: "Average", label: "Avg Origin Latency (ms)"}],
            ["AWS/CloudFront", "OriginLatency", "DistributionId", var.cloudfront_distribution_id, {stat: "p99", label: "P99 Origin Latency (ms)"}],
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", var.cloudfront_distribution_id, {stat: "Sum", label: "Bytes Downloaded", yAxis: "right"}],
            ["AWS/CloudFront", "BytesUploaded", "DistributionId", var.cloudfront_distribution_id, {stat: "Sum", label: "Bytes Uploaded", yAxis: "right"}]
          ]
        }
      },

      # Row 5: Custom Application Metrics (if you push them)
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 24
        height = 6
        properties = {
          title = "Application - URL Shortener Business Metrics"
          view  = "timeSeries"
          stacked = false
          period = 300
          region = data.aws_region.current.name
          metrics = [
            ["UrlShortener", "UrlsCreated", {stat: "Sum", label: "URLs Created"}],
            ["UrlShortener", "Redirects", {stat: "Sum", label: "Redirects"}],
            ["UrlShortener", "UrlCreationErrors", {stat: "Sum", label: "Creation Errors", color: "#FF0000"}],
            ["UrlShortener", "ActiveUsers", {stat: "Maximum", label: "Active Users", yAxis: "right"}]
          ]
        }
      }
    ]
  })

  tags = var.tags
}

# X-Ray Sampling Rule (if enabled)
resource "aws_xray_sampling_rule" "default" {
  count = var.enable_xray ? 1 : 0
  rule_name = "${var.name_prefix}-sampling"
  priority = 1000
  fixed_rate = 0.1
  reservoir_size = 5
  service_name = var.name_prefix
  service_type = "*"
  host = "*"
  http_method = "*"
  url_path = "*"
  resource_arn = "*"
  attributes = {}
}

data "aws_region" "current" {}

locals {
  var_tags = var.tags
}

# Outputs
output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.main.dashboard_name
  description = "CloudWatch dashboard name"
}

output "sns_topic_arn" {
  value       = var.alert_email != "" ? aws_sns_topic.alerts[0].arn : ""
  description = "SNS topic ARN for alarms"
}