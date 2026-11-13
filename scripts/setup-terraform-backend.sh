#!/bin/bash
# Setup Terraform Backend Resources
# Run this once to create the S3 bucket and DynamoDB table for Terraform state

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
STATE_BUCKET="${STATE_BUCKET:-url-shortener-terraform-state}"
LOCK_TABLE="${LOCK_TABLE:-terraform-locks}"
PROJECT_NAME="${PROJECT_NAME:-url-shortener}"

echo "=========================================="
echo "Setting up Terraform Backend Resources"
echo "=========================================="
echo "Region: $AWS_REGION"
echo "State Bucket: $STATE_BUCKET"
echo "Lock Table: $LOCK_TABLE"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Create S3 bucket for Terraform state
echo "Creating S3 bucket: $STATE_BUCKET"
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    echo "  Bucket already exists"
else
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$STATE_BUCKET" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo "  Bucket created"
fi

# Enable versioning
echo "Enabling versioning on bucket"
aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "Enabling server-side encryption on bucket"
aws s3api put-bucket-encryption \
    --bucket "$STATE_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

# Block public access
echo "Blocking public access on bucket"
aws s3api put-public-access-block \
    --bucket "$STATE_BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Add bucket policy to enforce HTTPS
echo "Adding bucket policy for HTTPS enforcement"
aws s3api put-bucket-policy \
    --bucket "$STATE_BUCKET" \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "EnforceHTTPS",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'"$STATE_BUCKET"'",
                "arn:aws:s3:::'"$STATE_BUCKET"'/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }]
    }'

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking: $LOCK_TABLE"
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "  Table already exists"
else
    aws dynamodb create-table \
        --table-name "$LOCK_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Purpose,Value="terraform-lock"

    echo "  Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"
    echo "  Table created and active"
fi

# Enable TTL on lock table (optional, for cleanup)
echo "Enabling TTL on lock table"
aws dynamodb update-time-to-live \
    --table-name "$LOCK_TABLE" \
    --time-to-live-specification Enabled=true,AttributeName=TTL \
    --region "$AWS_REGION" 2>/dev/null || echo "  TTL already enabled or not supported"

echo ""
echo "=========================================="
echo "Terraform Backend Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Update terraform/providers.tf with your bucket/table names if different"
echo "2. Run 'terraform init' in each environment directory:"
echo "   cd terraform/environments/dev && terraform init"
echo "   cd terraform/environments/staging && terraform init"
echo "   cd terraform/environments/prod && terraform init"
echo ""
echo "Backend configuration:"
echo "  bucket         = \"$STATE_BUCKET\""
echo "  key            = \"<environment>/terraform.tfstate\""
echo "  region         = \"$AWS_REGION\""
echo "  dynamodb_table = \"$LOCK_TABLE\""
echo "  encrypt        = true"