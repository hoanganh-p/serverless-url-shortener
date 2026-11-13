#!/bin/bash
# LocalStack DynamoDB initialization script
# Runs automatically when LocalStack starts
# Table names match Terraform naming convention: ${project}-${env}-${table}

set -e

PROJECT_NAME="${PROJECT_NAME:-url-shortener}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

USERS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-users"
URLS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-urls"

echo "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "running"'; do
  sleep 2
done

echo "LocalStack is ready. Creating DynamoDB tables..."

# Set AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=${AWS_REGION}
export AWS_ENDPOINT_URL=http://localhost:4566

# Create Users table
aws dynamodb create-table \
  --endpoint-url=http://localhost:4566 \
  --table-name ${USERS_TABLE} \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[
      {
        "IndexName": "EmailIndex",
        "KeySchema": [{"AttributeName": "SK", "KeyType": "HASH"}],
        "Projection": {"ProjectionType": "ALL"}
      }
    ]' \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  || echo "Users table already exists"

# Create ShortUrls table
aws dynamodb create-table \
  --endpoint-url=http://localhost:4566 \
  --table-name ${URLS_TABLE} \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[
      {
        "IndexName": "CodeIndex",
        "KeySchema": [{"AttributeName": "SK", "KeyType": "HASH"}],
        "Projection": {"ProjectionType": "ALL"}
      }
    ]' \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  || echo "ShortUrls table already exists"

echo "DynamoDB tables created successfully!"

# List tables to verify
aws dynamodb list-tables --endpoint-url=http://localhost:4566