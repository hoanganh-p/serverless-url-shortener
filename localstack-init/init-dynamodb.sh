#!/bin/bash
# LocalStack DynamoDB initialization script
# Runs automatically when LocalStack starts

set -e

echo "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "running"'; do
  sleep 2
done

echo "LocalStack is ready. Creating DynamoDB tables..."

# Set AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Create Users table
aws dynamodb create-table \
  --endpoint-url=http://localhost:4566 \
  --table-name Users \
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
        "Projection": {"ProjectionType": "ALL"},
        "ProvisionedThroughput": {"ReadCapacityUnits": 5, "WriteCapacityUnits": 5}
      }
    ]' \
  || echo "Users table already exists"

# Create ShortUrls table
aws dynamodb create-table \
  --endpoint-url=http://localhost:4566 \
  --table-name ShortUrls \
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
        "Projection": {"ProjectionType": "ALL"},
        "ProvisionedThroughput": {"ReadCapacityUnits": 5, "WriteCapacityUnits": 5}
      }
    ]' \
  || echo "ShortUrls table already exists"

echo "DynamoDB tables created successfully!"

# List tables to verify
aws dynamodb list-tables --endpoint-url=http://localhost:4566