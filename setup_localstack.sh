#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup_localstack.sh
# -----------------------------------------------------------------------------
# Purpose:
#   Initialize LocalStack environment for Lambda-based architecture:
#   - Creates DynamoDB table "ShopInventory"
#   - Creates S3 bucket "poc-data-bucket"
#   - Uploads sample.txt to S3 bucket
#
# Uses: awslocal CLI (recommended best practice for LocalStack)
# -----------------------------------------------------------------------------

set -euo pipefail

# Load environment variables from .env if present
if [ -f .env ]; then
  source .env
fi

# Try to load AWS CLI helper (creates awslocal function if not already available)
# This handles paths with spaces better than venv's awslocal script
if [ -f "$(dirname "$0")/utils/aws_cli_alias.sh" ]; then
  source "$(dirname "$0")/utils/aws_cli_alias.sh" 2>/dev/null || true
fi

# Default fallback values
: "${AWS_REGION:=us-east-1}"
: "${AWS_ENDPOINT_URL:=http://localhost:4566}"

# Check if awslocal function exists (from helper script), otherwise use aws CLI
# Note: We prefer the wrapper function to avoid issues with venv paths containing spaces
# Use 'whence -w' for zsh compatibility, fallback to 'type -t' for bash
if command -v whence &> /dev/null; then
    AWSLOCAL_TYPE=$(whence -w awslocal 2>/dev/null | cut -d: -f2 | xargs)
else
    AWSLOCAL_TYPE=$(type -t awslocal 2>/dev/null || echo "")
fi

if [ "$AWSLOCAL_TYPE" = "function" ]; then
  AWS_CMD="awslocal"
  echo "✅ Using awslocal function (recommended - handles paths with spaces)"
elif command -v awslocal &> /dev/null 2>&1; then
  # Try to use awslocal command if available (but may fail with spaces in path)
  # Test if it actually works by trying a simple command
  if awslocal --version &> /dev/null 2>&1; then
    AWS_CMD="awslocal"
    echo "✅ Using awslocal CLI"
  else
    # Fallback if awslocal command exists but doesn't work (e.g., broken shebang)
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
    AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT_URL}"
    echo "⚠️  Using aws CLI with endpoint-url (awslocal command has issues - likely path with spaces)"
  fi
else
  # Set dummy credentials for LocalStack when using aws CLI
  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
  export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
  AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT_URL}"
  echo "⚠️  Using aws CLI with endpoint-url (consider sourcing utils/aws_cli_alias.sh for awslocal function)"
fi

MAX_RETRIES=60
SLEEP_SEC=2
i=0

echo "🔍 Waiting for LocalStack services to be ready..."

while true; do
  HEALTH_JSON=$(curl -s "${AWS_ENDPOINT_URL}/_localstack/health" || true)
  if [ -n "$HEALTH_JSON" ]; then
    # Check for required services
    dynamodb_status=$(echo "$HEALTH_JSON" | jq -r '.services.dynamodb // "missing"' 2>/dev/null || echo "missing")
    s3_status=$(echo "$HEALTH_JSON" | jq -r '.services.s3 // "missing"' 2>/dev/null || echo "missing")
    lambda_status=$(echo "$HEALTH_JSON" | jq -r '.services.lambda // "missing"' 2>/dev/null || echo "missing")
    apigateway_status=$(echo "$HEALTH_JSON" | jq -r '.services.apigateway // "missing"' 2>/dev/null || echo "missing")
    
    if [[ ("$dynamodb_status" == "running" || "$dynamodb_status" == "available") ]] && \
       [[ ("$s3_status" == "running" || "$s3_status" == "available") ]] && \
       [[ ("$lambda_status" == "running" || "$lambda_status" == "available") ]] && \
       [[ ("$apigateway_status" == "running" || "$apigateway_status" == "available") ]]; then
      echo "✅ All required services are available."
      break
    fi
    echo "⏳ Waiting for services... (dynamodb: $dynamodb_status, s3: $s3_status, lambda: $lambda_status, apigateway: $apigateway_status)"
  else
    echo "Health endpoint not reachable yet..."
  fi

  i=$((i+1))
  if [ "$i" -ge "$MAX_RETRIES" ]; then
    echo "❌ Timed out waiting for LocalStack services after $((MAX_RETRIES * SLEEP_SEC)) seconds."
    exit 1
  fi
  sleep "$SLEEP_SEC"
done

# ---------------------------------------------------------------------------
# Create DynamoDB table
# ---------------------------------------------------------------------------
TABLE_NAME="ShopInventory"
echo "📦 Creating DynamoDB table: ${TABLE_NAME}"

# Check if table exists, create if it doesn't
if $AWS_CMD dynamodb describe-table \
  --table-name "${TABLE_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "✅ DynamoDB table '${TABLE_NAME}' already exists."
else
  echo "   Creating table..."
  $AWS_CMD dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=sku,AttributeType=S \
    --key-schema AttributeName=sku,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" >/dev/null 2>&1
  echo "✅ DynamoDB table '${TABLE_NAME}' created and ready."
fi

# ---------------------------------------------------------------------------
# Create S3 bucket
# ---------------------------------------------------------------------------
BUCKET_NAME="poc-data-bucket"
echo "🗂️  Creating S3 bucket: ${BUCKET_NAME}"

# Check if bucket exists by trying to list it
if $AWS_CMD s3 ls "s3://${BUCKET_NAME}" &>/dev/null; then
  echo "✅ S3 bucket '${BUCKET_NAME}' already exists."
else
  # Create bucket - for us-east-1, don't use LocationConstraint
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    $AWS_CMD s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}" 2>&1 | grep -v "Location" || true
  else
    $AWS_CMD s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}" 2>&1 | grep -v "Location" || true
  fi
  
  # Verify bucket was created
  if $AWS_CMD s3 ls "s3://${BUCKET_NAME}" &>/dev/null; then
    echo "✅ S3 bucket '${BUCKET_NAME}' created successfully."
  else
    echo "⚠️  S3 bucket creation may have failed. Verifying..."
    sleep 2
    if $AWS_CMD s3 ls "s3://${BUCKET_NAME}" &>/dev/null; then
      echo "✅ S3 bucket '${BUCKET_NAME}' verified."
    else
      echo "❌ Failed to create S3 bucket. Please check LocalStack logs."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Create and upload sample.txt
# ---------------------------------------------------------------------------
SAMPLE_FILE="sample.txt"
echo "📄 Creating sample file: ${SAMPLE_FILE}"

cat > "${SAMPLE_FILE}" <<EOF
This is a sample file for LocalStack S3 POC.
Created: $(date)
Purpose: Demonstrate S3 file download functionality via Lambda.
EOF

echo "📤 Uploading ${SAMPLE_FILE} to S3 bucket..."

# Use Python boto3 for reliable LocalStack S3 uploads
# (AWS CLI v2 has compatibility issues with LocalStack's x-amz-trailer header)
python3 <<PYTHON_EOF
import boto3
import os
import sys

s3 = boto3.client(
    's3',
    endpoint_url='${AWS_ENDPOINT_URL}',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='${AWS_REGION}'
)

try:
    with open('${SAMPLE_FILE}', 'rb') as f:
        s3.put_object(
            Bucket='${BUCKET_NAME}',
            Key='${SAMPLE_FILE}',
            Body=f.read(),
            ContentType='text/plain'
        )
    print("✅ File '${SAMPLE_FILE}' uploaded to S3 bucket.")
except FileNotFoundError:
    print(f"❌ Error: File '${SAMPLE_FILE}' not found.")
    sys.exit(1)
except Exception as e:
    print(f"❌ Upload failed: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
  echo "⚠️  Python upload failed. Trying awslocal as fallback..."
  # Fallback to awslocal (may fail due to LocalStack compatibility issues)
  if $AWS_CMD s3api put-object \
    --bucket "${BUCKET_NAME}" \
    --key "${SAMPLE_FILE}" \
    --body "${SAMPLE_FILE}" \
    --content-type "text/plain" \
    --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "✅ File '${SAMPLE_FILE}' uploaded via awslocal (fallback)."
  else
    echo "❌ File upload failed with both methods."
    echo "💡 You can manually upload later using:"
    echo "   python3 -c \"import boto3; s3=boto3.client('s3',endpoint_url='${AWS_ENDPOINT_URL}',aws_access_key_id='test',aws_secret_access_key='test'); s3.put_object(Bucket='${BUCKET_NAME}',Key='${SAMPLE_FILE}',Body=open('${SAMPLE_FILE}','rb').read())\""
    exit 1
  fi
fi

# Clean up local sample file (optional)
rm -f "${SAMPLE_FILE}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--------------------------------------------------------"
echo "✅ LocalStack initialization complete."
echo "📊 Summary:"
echo "   • DynamoDB table  : ${TABLE_NAME}"
echo "   • S3 bucket       : ${BUCKET_NAME}"
echo "   • Sample file     : ${SAMPLE_FILE} (uploaded to S3)"
echo "--------------------------------------------------------"

