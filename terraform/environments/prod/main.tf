# ============================================================
# Production Environment Configuration
# ============================================================

terraform {
  backend "s3" {
    bucket         = "url-shortener-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

module "url_shortener" {
  source = "../../"

  aws_region           = "ap-southeast-1"
  environment          = "prod"
  project_name         = "url-shortener"
  lambda_memory_size   = 1024
  lambda_timeout       = 30
  dynamodb_billing_mode = "PAY_PER_REQUEST"
  cloudfront_price_class = "PriceClass_All"
  enable_xray          = true
  alert_email          = "alerts@yourdomain.com"  # Configure

  # Frontend
  frontend_build_path = "../frontend/build"

  # Custom domain for production
  domain_name     = "yourdomain.com"
  hosted_zone_id  = "ZXXXXXXXXXXXXX"  # Replace with your hosted zone ID
  certificate_arn = "arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  # Lambda image (will be set by CI/CD)
  lambda_image_uri = ""

  common_tags = {
    CostCenter = "engineering"
    Team       = "platform"
    Tier       = "production"
    Criticality = "high"
  }
}