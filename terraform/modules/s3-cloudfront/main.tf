# ============================================================
# S3 + CloudFront Module - Static Frontend Hosting
# ============================================================

# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.name_prefix}-frontend-${random_id.suffix.hex}"
  force_destroy = var.environment != "prod"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access (CloudFront OAC will handle access)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control (OAC) - Modern replacement for OAI
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.name_prefix}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "URL Shortener Frontend - ${var.environment}"
  default_root_object = "index.html"
  price_class         = var.price_class

  # Origin - S3 with OAC
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"

    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Default cache behavior - SPA routing
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    compress = true

    # Lambda@Edge for SPA routing (optional - can use CloudFront Functions instead)
    # lambda_function_association {
    #   event_type   = "origin-request"
    #   lambda_arn   = var.lambda_edge_arn
    #   include_body = false
    # }
  }

  # Cache behavior for static assets (long cache)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 31536000
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  # Error pages for SPA routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer Certificate
  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == ""
    acm_certificate_arn            = var.domain_name != "" ? var.certificate_arn : null
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Custom Domain (optional)
  aliases = var.domain_name != "" ? [var.domain_name] : []

  tags = var.tags
}

# S3 Bucket Policy for CloudFront OAC
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}

# Route53 Record for Custom Domain (optional)
resource "aws_route53_record" "frontend_custom" {
  count = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = true
  }
}

# CloudFront Function for SPA Rewrite (alternative to Lambda@Edge)
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.name_prefix}-spa-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "SPA rewrite for clean URLs"

  publish = true

  code = <<-EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check if URI has a file extension
    if (!uri.match(/\\.[a-zA-Z0-9]+$/)) {
        // No extension - rewrite to index.html for SPA routing
        request.uri = '/index.html';
    }
    return request;
}
EOF
}

# Attach CloudFront Function to distribution (via default cache behavior)
# Note: This requires updating the distribution after creation
# For simplicity, we use custom_error_response above instead

# Sync frontend build to S3 (using null_resource with local-exec for CI/CD)
# In practice, use GitHub Actions `aws s3 sync` instead
resource "null_resource" "sync_frontend" {
  triggers = {
    build_path = var.build_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ -d "${var.build_path}" ]; then
        aws s3 sync "${var.build_path}" "s3://${aws_s3_bucket.frontend.id}" --delete --cache-control "public, max-age=31536000, immutable" --exclude "index.html" --exclude "*.json"
        aws s3 sync "${var.build_path}" "s3://${aws_s3_bucket.frontend.id}" --cache-control "public, max-age=0, must-revalidate" --include "index.html" --include "*.json"
        aws cloudfront create-invalidation --distribution-id "${aws_cloudfront_distribution.frontend.id}" --paths "/*"
      else
        echo "Build path ${var.build_path} does not exist, skipping sync"
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# Outputs
output "bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "Frontend S3 bucket name"
}

output "bucket_arn" {
  value       = aws_s3_bucket.frontend.arn
  description = "Frontend S3 bucket ARN"
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "CloudFront distribution ID"
}

output "distribution_domain_name" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "CloudFront distribution domain name"
}

output "distribution_url" {
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
  description = "CloudFront distribution URL"
}

output "custom_domain_url" {
  value       = var.domain_name != "" ? "https://${var.domain_name}" : ""
  description = "Custom domain URL if configured"
}