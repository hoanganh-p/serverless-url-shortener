locals {
  # Full resource name prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # Merge common tags
  tags = merge({
    Name        = local.name_prefix
    Project     = var.project_name
    Environment = var.environment
  }, var.common_tags)
}

# ============================================================
# IAM Module - Roles and Policies
# ============================================================
module "iam" {
  source = "./modules/iam"

  name_prefix          = local.name_prefix
  environment          = var.environment
  project_name         = var.project_name
  tags                 = local.tags
  dynamodb_table_names = [module.dynamodb.users_table_name, module.dynamodb.urls_table_name]
  enable_xray          = var.enable_xray
}

# ============================================================
# DynamoDB Module - Tables
# ============================================================
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix         = local.name_prefix
  environment         = var.environment
  project_name        = var.project_name
  tags                = local.tags
  billing_mode        = var.dynamodb_billing_mode
  ttl_attribute       = var.dynamodb_ttl_attribute
  point_in_time_recovery = var.environment != "dev"
}

# ============================================================
# Lambda Module - Container-based Lambda Function
# ============================================================
module "lambda" {
  source = "./modules/lambda"

  name_prefix           = local.name_prefix
  environment           = var.environment
  project_name          = var.project_name
  tags                  = local.tags
  image_uri             = var.lambda_image_uri
  memory_size           = var.lambda_memory_size
  timeout               = var.lambda_timeout
  iam_role_arn          = module.iam.lambda_role_arn
  dynamodb_users_table  = module.dynamodb.users_table_name
  dynamodb_urls_table   = module.dynamodb.urls_table_name
  dynamodb_users_table_arn = module.dynamodb.users_table_arn
  dynamodb_urls_table_arn  = module.dynamodb.urls_table_arn
  enable_xray           = var.enable_xray
  jwt_secret_arn        = module.iam.jwt_secret_arn
}

# ============================================================
# API Gateway Module - HTTP API
# ============================================================
module "api_gateway" {
  source = "./modules/api-gateway"

  name_prefix           = local.name_prefix
  environment           = var.environment
  project_name          = var.project_name
  tags                  = local.tags
  lambda_function_arn   = module.lambda.function_arn
  lambda_function_name  = module.lambda.function_name
  domain_name           = var.domain_name
  certificate_arn       = var.certificate_arn
  hosted_zone_id        = var.hosted_zone_id
  enable_xray           = var.enable_xray
}

# ============================================================
# S3 + CloudFront Module - Frontend Hosting
# ============================================================
module "frontend" {
  source = "./modules/s3-cloudfront"

  name_prefix          = local.name_prefix
  environment          = var.environment
  project_name         = var.project_name
  tags                 = local.tags
  build_path           = var.frontend_build_path
  price_class          = var.cloudfront_price_class
  domain_name          = var.domain_name
  certificate_arn      = var.certificate_arn
  hosted_zone_id       = var.hosted_zone_id
  api_base_url         = module.api_gateway.api_base_url
}

# ============================================================
# Monitoring Module - CloudWatch Dashboards, Alarms, Log Groups
# ============================================================
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix           = local.name_prefix
  environment           = var.environment
  project_name          = var.project_name
  tags                  = local.tags
  lambda_function_name  = module.lambda.function_name
  api_gateway_id        = module.api_gateway.api_id
  dynamodb_users_table  = module.dynamodb.users_table_name
  dynamodb_urls_table   = module.dynamodb.urls_table_name
  cloudfront_distribution_id = module.frontend.distribution_id
  alert_email           = var.alert_email
  enable_xray           = var.enable_xray
}