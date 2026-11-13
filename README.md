# Serverless URL Shortener

A fully serverless URL shortener built with **.NET 10**, **AWS Lambda**, **API Gateway**, **DynamoDB**, **S3**, **CloudFront**, and **Terraform**.

## Architecture

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

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Backend** | .NET 10, ASP.NET Core, Minimal APIs |
| **Compute** | AWS Lambda (Container Image) |
| **API** | API Gateway HTTP API |
| **Database** | DynamoDB (Single-table design with GSIs) |
| **Auth** | JWT (RS256), bcrypt, AWS Secrets Manager |
| **Frontend** | React 18, Nginx |
| **CDN** | CloudFront + S3 Static Hosting |
| **IaC** | Terraform (modular, multi-environment) |
| **CI/CD** | GitHub Actions (OIDC, no static keys) |
| **Observability** | CloudWatch, X-Ray, Custom Metrics |
| **Local Dev** | Docker Compose + LocalStack |

## Project Structure

```
serverless-url-shortener/
├── backend/                 # .NET 10 API
│   ├── src/
│   │   ├── UrlShortener.Api/           # API entry point, controllers
│   │   ├── UrlShortener.Application/   # Business logic, services
│   │   ├── UrlShortener.Domain/        # Entities, interfaces
│   │   └── UrlShortener.Infrastructure/# DynamoDB, Auth, AWS services
│   ├── tests/
│   │   └── UrlShortener.UnitTests/     # Moq + FluentAssertions
│   ├── Dockerfile                      # Lambda container image
│   └── lambda-entrypoint.sh            # Lambda entrypoint
├── frontend/               # React + Nginx
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   └── nginx.conf
├── terraform/              # Infrastructure as Code
│   ├── modules/
│   │   ├── iam/              # IAM roles, policies, Secrets Manager
│   │   ├── dynamodb/         # Tables with GSIs
│   │   ├── lambda/           # Lambda function
│   │   ├── api-gateway/      # HTTP API + custom domain
│   │   ├── s3-cloudfront/    # Frontend hosting + CDN
│   │   └── monitoring/       # CloudWatch dashboards, alarms
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── README.md
├── localstack-init/        # LocalStack initialization scripts
├── scripts/                # Utility scripts
├── docker-compose.yml      # Local development
├── docker-compose.override.yml
└── .github/workflows/      # CI/CD pipelines
```

## Features

- ✅ **Create short URLs** with custom or auto-generated codes
- ✅ **Redirect** with click tracking
- ✅ **User authentication** (register, login, JWT)
- ✅ **User dashboard** (list, update, delete own URLs)
- ✅ **Rate limiting** (API Gateway + application-level)
- ✅ **Health checks** (/health endpoint)
- ✅ **Structured logging** (JSON, CloudWatch-ready)
- ✅ **X-Ray distributed tracing**
- ✅ **Custom metrics** (URLs created, redirects, errors)
- ✅ **Comprehensive unit tests** (100+ tests)
- ✅ **Multi-environment** (dev/staging/prod)
- ✅ **Custom domains** with HTTPS
- ✅ **WAF-ready** (attach Web ACL)

## Quick Start (Local Development)

### Prerequisites

- Docker & Docker Compose
- .NET 10 SDK (for local development without Docker)
- Node.js 20+ (for frontend development)

### Start All Services

```bash
# Clone and navigate
cd serverless-url-shortener

# Start with Docker Compose (includes LocalStack for DynamoDB)
docker-compose up -d

# View logs
docker-compose logs -f api

# Access services
# Frontend: http://localhost:3000
# API: http://localhost:5000
# API Health: http://localhost:5000/health
# LocalStack: http://localhost:4566
```

### Run Tests

```bash
# Backend tests
cd backend
dotnet test

# Frontend tests
cd frontend
npm test
```

## Deployment (AWS)

### Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.6.0
3. AWS CLI configured
4. S3 bucket + DynamoDB table for Terraform state (run once):

```bash
# Run the setup script
./scripts/setup-terraform-backend.sh
```

### Deploy to Dev

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="lambda_image_uri=<your-ecr-image-uri>"
terraform apply -var="lambda_image_uri=<your-ecr-image-uri>"
```

### Deploy via CI/CD (Recommended)

Push to `main` branch - GitHub Actions will:

1. Run backend tests & build
2. Run frontend tests & build
3. Build & push Docker image to ECR
4. **Auto-deploy to dev** (Terraform apply)
5. **Manual approval** for staging
6. **Manual approval** for production
7. Sync frontend to S3 + invalidate CloudFront

### Custom Domain Setup

1. Request ACM certificate in `us-east-1`:
   ```bash
   aws acm request-certificate \
     --domain-name "*.yourdomain.com" \
     --validation-method DNS \
     --region us-east-1
   ```

2. Update environment config (`terraform/environments/<env>/main.tf`):
   ```hcl
   domain_name     = "api.yourdomain.com"
   hosted_zone_id  = "ZXXXXXXXXXXXXX"
   certificate_arn = "arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/..."
   ```

3. Apply Terraform

## API Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/health` | Health check | No |
| GET | `/` | API info | No |
| POST | `/api/url/create` | Create short URL | No |
| GET | `/{code}` | Redirect to original | No |
| GET | `/api/url/user/all` | List user URLs | Yes |
| GET | `/api/url/{code}/details` | Get URL details | Yes |
| PUT | `/api/url/{code}` | Update URL | Yes |
| DELETE | `/api/url/{code}` | Delete URL | Yes |

### Example Usage

```bash
# Create short URL
curl -X POST http://localhost:5000/api/url/create \
  -H "Content-Type: application/json" \
  -d '{"originalUrl": "https://example.com/very/long/url"}'

# Response
{
  "shortCode": "aB3x9K2",
  "shortUrl": "http://localhost:5000/aB3x9K2"
}

# Redirect (follows automatically)
curl -L http://localhost:5000/aB3x9K2

# With authentication
curl -X POST http://localhost:5000/api/url/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"originalUrl": "https://example.com"}'
```

## Monitoring

Access CloudWatch Dashboard after deployment:
```
https://ap-southeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#dashboards:name=url-shortener-dev-overview
```

### Key Metrics

- **Lambda**: Invocations, Errors, Duration (avg/p99), Throttles, Concurrent Executions
- **API Gateway**: Requests, 4xx/5xx, Latency (avg/p99), Integration Latency
- **DynamoDB**: Consumed RCU/WCU, Throttled Requests
- **CloudFront**: Requests, Error Rates, Cache Hit Rate, Origin Latency
- **Custom**: URLs Created, Redirects, Creation Errors, Active Users

### Alarms (notify via SNS)

- Lambda errors > 5/5min
- Lambda p99 duration > 10s
- Lambda throttles > 0
- API Gateway 5xx > 10/5min
- API Gateway p99 latency > 5s
- DynamoDB throttles > 0
- CloudFront 4xx rate > 5%, 5xx rate > 1%
- CloudFront cache hit rate < 80%

## Security

- **IAM**: Least-privilege Lambda execution role
- **Secrets**: JWT secret in AWS Secrets Manager (auto-rotated)
- **Encryption**: DynamoDB encryption at rest, TLS 1.2+ in transit
- **Rate Limiting**: API Gateway (1000 req/s) + Application (100 req/min)
- **CORS**: Configurable allowed origins
- **Headers**: Security headers via CloudFront Functions
- **WAF**: Ready for Web ACL attachment

## Cost Optimization

| Environment | Estimated Monthly Cost |
|-------------|------------------------|
| Dev | $5-15 |
| Staging | $20-50 |
| Production | $50-200+ |

Cost drivers:
- Lambda: $0.20 per 1M requests + GB-seconds
- API Gateway: $1.00 per 1M requests (HTTP API)
- DynamoDB: $0.25 per GB/month + request costs
- CloudFront: $0.085/GB (US) + $0.0075/10k requests
- S3: $0.023/GB/month

## Development

### Backend Development

```bash
cd backend

# Restore packages
dotnet restore

# Run with hot reload
dotnet watch run --project src/UrlShortener.Api

# Run tests
dotnet test

# Build for Lambda
dotnet publish src/UrlShortener.Api -c Release -o ./publish
```

### Frontend Development

```bash
cd frontend

# Install dependencies
npm install

# Start dev server
npm start

# Build for production
npm run build
```

### LocalStack (DynamoDB Local)

```bash
# Start LocalStack only
docker-compose up -d localstack

# Create tables manually
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
  --table-name url-shortener-dev-users \
  --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[{"IndexName":"EmailIndex","KeySchema":[{"AttributeName":"SK","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"}}]'
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) implements:

```
┌─────────────┐
│   Push to   │
│    main     │
└──────┬──────┘
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Backend    │     │  Frontend   │     │  Docker     │
│  Test/Build │────▶│  Test/Build │────▶│  Build/Push │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Prod      │◀────│  Staging    │◀────│    Dev      │
│  (Manual)   │     │  (Manual)   │     │  (Auto)     │
└─────────────┘     └─────────────┘     └─────────────┘
```

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `TF_API_TOKEN` | Terraform Cloud token (optional) |

### IAM Role for GitHub Actions

Create an OIDC role with trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {"StringLike": {"token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"}}
  }]
}
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `dotnet test` and `npm test`
5. Submit a PR

## Useful Links

- [Terraform Documentation](terraform/README.md)
- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [API Gateway HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)