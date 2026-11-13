# ============================================================
# Dev Environment Configuration
# ============================================================

terraform {
  backend "s3" {
    bucket         = "url-shortener-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

module "url_shortener" {
  source = "../../"

  aws_region           = "ap-southeast-1"
  environment          = "dev"
  project_name         = "url-shortener"
  lambda_memory_size   = 512
  lambda_timeout       = 30
  dynamodb_billing_mode = "PAY_PER_REQUEST"
  cloudfront_price_class = "PriceClass_100"
  enable_xray          = true
  alert_email          = ""  # Add email for alerts

  # Frontend
  frontend_build_path = "../frontend/build"

  # Custom domain (optional - leave empty for dev)
  domain_name     = ""
  hosted_zone_id  = ""
  certificate_arn = ""

  # Lambda image (will be set by CI/CD)
  lambda_image_uri = ""

  common_tags = {
    CostCenter = "engineering"
    Team       = "platform"
  }
}