#!/usr/bin/env bash

# Usage: ./backend.sh <bucket-name> [region] [lock-table-name]
# Creates an S3 bucket for Terraform remote state and a DynamoDB table for state locking.
# If region is omitted, the default AWS CLI region is used.
# If lock-table-name is omitted, defaults to "terraform-state-lock".


# create-s3-bucket.sh
# Simple helper to create an S3 bucket using the AWS CLI.
# Usage: ./create-s3-bucket.sh <bucket-name> [region]
# If region is omitted, the default AWS CLI region is used.

set -euo pipefail



if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <bucket-name> [region]"
  exit 1
fi

BUCKET_NAME="$1"
REGION="${2:-}"   # optional region argument
LOCK_TABLE="${3:-terraform-state-lock}" # Capture optional lock table name (third argument)


# Validate bucket name (basic check)
if [[ ! "$BUCKET_NAME" =~ ^[a-z0-9.-]{3,63}$ ]]; then
  echo "Error: Invalid bucket name. Must be 3-63 characters, lowercase letters, numbers, hyphens or periods."
  exit 1
fi

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket \"$BUCKET_NAME\" already exists."
  exit 0
fi

# Build the create command for the bucket
if [[ -n "$REGION" ]]; then
  if [[ "$REGION" == "us-east-1" ]]; then
    echo "Creating bucket \"$BUCKET_NAME\" in region \"$REGION\" (no LocationConstraint needed)..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  else
    echo "Creating bucket \"$BUCKET_NAME\" in region \"$REGION\"..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
else
  echo "Creating bucket \"$BUCKET_NAME\" in the default region..."
  aws s3api create-bucket --bucket "$BUCKET_NAME"
fi

# Enable versioning (optional, can be removed if not desired)
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled

# Create DynamoDB lock table if requested
if [[ -n "$LOCK_TABLE" ]]; then
  echo "Creating DynamoDB lock table \"$LOCK_TABLE\"..."
  # Check if table exists
  if aws dynamodb describe-table --table-name "$LOCK_TABLE" 2>/dev/null; then
    echo "DynamoDB table \"$LOCK_TABLE\" already exists."
  else
    aws dynamodb create-table \
      --table-name "$LOCK_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST
    echo "DynamoDB table \"$LOCK_TABLE\" created."
  fi
fi
if [[ -n "$REGION" ]]; then
  echo "Creating bucket \"$BUCKET_NAME\" in region \"$REGION\"..."
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
else
  echo "Creating bucket \"$BUCKET_NAME\" in the default region..."
  aws s3api create-bucket --bucket "$BUCKET_NAME"
fi

# Enable versioning (optional, can be removed if not desired)
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled

echo "Bucket \"$BUCKET_NAME\" created and versioning enabled."