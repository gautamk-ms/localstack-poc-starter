#!/usr/bin/env bash
# scripts/deploy_lambda.sh
# Deploy FastAPI Lambda Container Image to LocalStack
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
: "${IMAGE_NAME:=fastapi-lambda:latest}"
: "${ECR_REPO:=fastapi-lambda}"

# Check if awslocal is available
if command -v awslocal &> /dev/null; then
  AWS_CMD="awslocal"
else
  # Set dummy credentials for LocalStack when using aws CLI
  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
  export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
  AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT_URL}"
fi

echo "🏗️  Building Lambda container image..."
cd fastapi
docker build -t ${IMAGE_NAME} .
cd ..

echo "⚡ Creating/updating Lambda function..."

# Delete existing function if it exists
$AWS_CMD lambda delete-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} >/dev/null 2>&1 || true

# For LocalStack CE, use the local Docker image directly
# LocalStack can access images from the local Docker daemon
# Remove :latest suffix if already present in IMAGE_NAME
if [[ "${IMAGE_NAME}" == *":latest" ]]; then
  IMAGE_URI="${IMAGE_NAME}"
else
  IMAGE_URI="${IMAGE_NAME}:latest"
fi

echo "📦 Using local Docker image: ${IMAGE_URI}"

$AWS_CMD lambda create-function \
  --function-name ${FUNCTION_NAME} \
  --package-type Image \
  --code ImageUri=${IMAGE_URI} \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{TABLE_NAME=${TABLE_NAME},S3_BUCKET=${S3_BUCKET},AWS_REGION=${AWS_REGION},AWS_ENDPOINT_URL=http://localstack:4566,AWS_ACCESS_KEY_ID=test,AWS_SECRET_ACCESS_KEY=test}" \
  --region ${AWS_REGION}

echo "✅ Lambda function '${FUNCTION_NAME}' deployed successfully!"
echo "📋 Function ARN: arn:aws:lambda:${AWS_REGION}:000000000000:function:${FUNCTION_NAME}"

