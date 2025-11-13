#!/usr/bin/env bash
# scripts/deploy_lambda_zip.sh
# Deploy FastAPI Lambda as ZIP package (for LocalStack Community Edition)
# Note: Container images require LocalStack Pro
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  source .env
fi

: "${AWS_REGION:=us-east-1}"
: "${AWS_ENDPOINT_URL:=http://localhost:4566}"
: "${TABLE_NAME:=ShopInventory}"
: "${S3_BUCKET:=poc-data-bucket}"
: "${FUNCTION_NAME:=fastapi-inventory}"
: "${ZIP_FILE:=lambda_function.zip}"

# Try to load AWS CLI helper (creates awslocal function if not already available)
# This handles paths with spaces better than venv's awslocal script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../utils/aws_cli_alias.sh" ]; then
  source "${SCRIPT_DIR}/../utils/aws_cli_alias.sh" 2>/dev/null || true
fi

# Check if awslocal function exists (from helper script), otherwise use aws CLI
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

echo "📦 Creating Lambda deployment package..."

# Use Docker to build package in Linux environment (ensures compatibility)
echo "🐳 Building package in Docker container (Linux environment)..."

docker run --rm \
  --platform linux/amd64 \
  --entrypoint /bin/bash \
  -v "$(pwd)/fastapi:/var/task/fastapi:ro" \
  -v "$(pwd):/var/output" \
  -w /var/task \
  public.ecr.aws/lambda/python:3.10 \
  -c "
    # Install zip if not available
    yum install -y zip >/dev/null 2>&1 || apt-get update && apt-get install -y zip >/dev/null 2>&1 || true
    
    # Create temp directory
    TEMP_DIR=\$(mktemp -d)
    
    # Copy application code
    cp -r fastapi/app \${TEMP_DIR}/
    
    # Install dependencies
    pip install -r fastapi/requirements.txt -t \${TEMP_DIR}/ --quiet --no-cache-dir
    
    # Create ZIP file using Python (works even without zip command)
    python3 -c \"
import zipfile
import os
import sys

zip_path = '/var/output/lambda_function.zip'
temp_dir = '\${TEMP_DIR}'

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(temp_dir):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, temp_dir)
            zipf.write(file_path, arcname)
\"
    
    # Cleanup
    rm -rf \${TEMP_DIR}
    
    echo '✅ Package created successfully'
  "

echo "⚡ Creating/updating Lambda function..."

# Delete existing function if it exists
$AWS_CMD lambda delete-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} >/dev/null 2>&1 || true

# Create Lambda function with ZIP package
$AWS_CMD lambda create-function \
  --function-name ${FUNCTION_NAME} \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --handler app.lambda_handler.lambda_handler \
  --zip-file fileb://${ZIP_FILE} \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{TABLE_NAME=${TABLE_NAME},S3_BUCKET=${S3_BUCKET},AWS_REGION=${AWS_REGION},AWS_ENDPOINT_URL=http://localstack:4566,AWS_ACCESS_KEY_ID=test,AWS_SECRET_ACCESS_KEY=test}" \
  --region ${AWS_REGION}

echo "✅ Lambda function '${FUNCTION_NAME}' deployed successfully!"
echo "📋 Function ARN: arn:aws:lambda:${AWS_REGION}:000000000000:function:${FUNCTION_NAME}"
echo "💡 Note: Using ZIP package (Container images require LocalStack Pro)"

