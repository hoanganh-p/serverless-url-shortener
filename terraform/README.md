# Terraform Infrastructure for URL Shortener

This directory contains the Infrastructure as Code (Terraform) for deploying the URL Shortener application to AWS using a fully serverless architecture.

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   CloudFront    │────▶│      S3          │     │  Route53 + ACM  │
│   (CDN + WAF)   │     │  (Static Host)   │     │  (Custom Domain)│
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                           │
                                                           ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  API Gateway    │────▶│   Lambda         │────▶│   DynamoDB      │
│  (HTTP API)     │     │  (Container)     │     │  (Users/URLs)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │  CloudWatch      │
                        │  (Logs/Metrics/  │
                        │   Alarms/X-Ray)  │
                        └──────────────────┘
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.6.0 installed
3. **AWS CLI** configured
4. **S3 Bucket** for Terraform state (create once):
   ```bash
   aws s3 mb s3://url-shortener-terraform-state --region ap-southeast-1
   aws dynamodb create-table \
     --table-name terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ap-southeast-1
   ```
5. **ECR Repository** for Lambda container images:
   ```bash
   aws ecr create-repository --repository-name url-shortener-api --region ap-southeast-1
   ```
6. **ACM Certificate** in `us-east-1` for custom domains (optional but recommended)
7. **Route53 Hosted Zone** for custom domains (optional)

## Directory Structure

```
terraform/
├── providers.tf           # Provider configuration
├── variables.tf           # Root variables
├── main.tf                # Root module composition
├── outputs.tf             # Root outputs
├── modules/
│   ├── iam/               # IAM roles, policies, Secrets Manager
│   ├── dynamodb/          # DynamoDB tables with GSIs
│   ├── lambda/            # Lambda function (container image)
│   ├── api-gateway/       # HTTP API Gateway + custom domain
│   ├── s3-cloudfront/     # S3 + CloudFront for frontend
│   └── monitoring/        # CloudWatch dashboards, alarms, X-Ray
└── environments/
    ├── dev/               # Development environment
    ├── staging/           # Staging environment
    └── prod/              # Production environment
```

## Quick Start

### 1. Initialize Terraform Backend

```bash
cd terraform/environments/dev
terraform init
```

### 2. Plan Deployment

```bash
terraform plan \
  -var="lambda_image_uri=<your-ecr-image-uri>"
```

### 3. Apply

```bash
terraform apply \
  -var="lambda_image_uri=<your-ecr-image-uri>"
```

## Environment Configuration

Each environment has its own `main.tf` with environment-specific settings:

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| Lambda Memory | 512 MB | 1024 MB | 1024 MB |
| DynamoDB Billing | PAY_PER_REQUEST | PAY_PER_REQUEST | PAY_PER_REQUEST |
| CloudFront Price Class | PriceClass_100 | PriceClass_100 | PriceClass_All |
| Point-in-Time Recovery | Disabled | Enabled | Enabled |
| Log Retention | 7 days | 30 days | 30 days |
| Custom Domain | No | Yes | Yes |
| Deletion Protection | No | No | Yes |

## Required Variables

Set these in each environment's `main.tf` or via `-var` flags:

| Variable | Description | Required |
|----------|-------------|----------|
| `lambda_image_uri` | ECR image URI for Lambda | Yes (CI/CD sets this) |
| `domain_name` | Custom domain (e.g., `api.example.com`) | No |
| `hosted_zone_id` | Route53 hosted zone ID | If using custom domain |
| `certificate_arn` | ACM certificate ARN (us-east-1) | If using custom domain |
| `alert_email` | Email for CloudWatch alarms | No |

## GitHub Actions CI/CD

The pipeline (`.github/workflows/ci-cd.yml`) handles:

1. **Backend**: Test, build, publish
2. **Frontend**: Lint, test, build
3. **Docker**: Build & push to ECR
4. **Terraform Plan** (Dev → Staging → Prod)
5. **Terraform Apply** (Dev auto, Staging/Prod manual approval)
6. **Frontend Deploy**: Sync to S3 + CloudFront invalidation

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `TF_API_TOKEN` | Terraform Cloud API token (optional) |

### Required IAM Role

Create a GitHub Actions OIDC role in AWS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"
        }
      }
    }
  ]
}
```

Attach policies: `AdministratorAccess` (or least-privilege custom policy)

## Local Development

Use Docker Compose with LocalStack:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api

# Run tests
docker-compose exec api dotnet test

# Stop
docker-compose down -v
```

## Custom Domain Setup

1. Request ACM certificate in `us-east-1`:
   ```bash
   aws acm request-certificate \
     --domain-name "*.yourdomain.com" \
     --validation-method DNS \
     --region us-east-1
   ```

2. Create Route53 hosted zone (or use existing)

3. Update environment config:
   ```hcl
   domain_name     = "api.yourdomain.com"
   hosted_zone_id  = "ZXXXXXXXXXXXXX"
   certificate_arn = "arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/..."
   ```

4. Apply Terraform

## Monitoring

After deployment, access CloudWatch Dashboard:
```
https://ap-southeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#dashboards:name=url-shortener-dev-overview
```

Key metrics monitored:
- Lambda: Invocations, Errors, Duration, Throttles, Concurrent Executions
- API Gateway: Requests, 4xx/5xx, Latency, Integration Latency
- DynamoDB: Consumed RCU/WCU, Throttled Requests
- CloudFront: Requests, Error Rates, Cache Hit Rate, Latency

Alarms configured:
- Lambda errors > 5/5min
- Lambda p99 duration > 10s
- Lambda throttles > 0
- API Gateway 5xx > 10/5min
- API Gateway latency p99 > 5s
- DynamoDB throttles > 0
- CloudFront 4xx rate > 5%, 5xx rate > 1%
- CloudFront cache hit rate < 80%

## Cost Optimization

- **DynamoDB**: PAY_PER_REQUEST for unpredictable workloads
- **Lambda**: Right-size memory (512MB dev, 1024MB prod)
- **CloudFront**: PriceClass_100 for dev/staging, PriceClass_All for prod
- **Logs**: 7-day retention for dev, 30-day for prod

Estimated monthly cost (dev): ~$5-15
Estimated monthly cost (prod): ~$50-200 (depends on traffic)

## Security

- **IAM**: Least-privilege roles for Lambda
- **Secrets**: JWT secret in AWS Secrets Manager
- **Encryption**: DynamoDB encryption at rest, TLS in transit
- **WAF**: Can be attached to CloudFront/API Gateway (add `waf_web_acl_arn` variable)
- **VPC**: Optional - Lambda can run in VPC for private DynamoDB access

## Cleanup

```bash
# Destroy specific environment
cd terraform/environments/dev
terraform destroy

# Or destroy all (careful!)
# This will delete ALL resources including data
```

## Troubleshooting

### Lambda Timeout
Increase `lambda_timeout` variable (max 900s / 15min)

### DynamoDB Throttling
Switch to PROVISIONED billing mode with autoscaling, or increase RCU/WCU

### CloudFront Cache Issues
```bash
aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/*"
```

### Terraform State Lock
```bash
terraform force-unlock <LOCK_ID>
```

## Useful Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Show current state
terraform show

# List resources
terraform state list

# Import existing resource
terraform import module.dynamodb.aws_dynamodb_table.users <table-name>

# Refresh state
terraform refresh
```

## References

- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [API Gateway HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)