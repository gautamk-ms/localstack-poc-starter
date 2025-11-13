#!/usr/bin/env bash
# scripts/setup_apigateway.sh
# Create API Gateway and integrate with Lambda function
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  source .env
fi

: "${AWS_REGION:=us-east-1}"
: "${AWS_ENDPOINT_URL:=http://localhost:4566}"
: "${FUNCTION_NAME:=fastapi-inventory}"
: "${API_NAME:=fastapi-lambda-proxy}"

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

LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:000000000000:function:${FUNCTION_NAME}"

echo "🌐 Creating API Gateway REST API: ${API_NAME}"
API_ID=$($AWS_CMD apigateway create-rest-api \
  --name "${API_NAME}" \
  --region ${AWS_REGION} \
  --query 'id' --output text)

echo "✅ API created with ID: ${API_ID}"

# Save API ID for later use
echo "${API_ID}" > .api_id

ROOT_ID=$($AWS_CMD apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ${AWS_REGION} \
  --query "items[?path=='/'].id" --output text)

echo "📁 Root Resource ID: ${ROOT_ID}"

# Create proxy resource for all paths
echo "🔀 Creating proxy resource..."
PROXY_ID=$($AWS_CMD apigateway create-resource \
  --rest-api-id ${API_ID} \
  --parent-id ${ROOT_ID} \
  --path-part '{proxy+}' \
  --region ${AWS_REGION} \
  --query 'id' --output text)

echo "✅ Proxy Resource ID: ${PROXY_ID}"

# Setup ANY method on proxy resource
echo "🔧 Setting up ANY method on proxy resource..."
$AWS_CMD apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${PROXY_ID} \
  --http-method ANY \
  --authorization-type "NONE" \
  --region ${AWS_REGION} >/dev/null

$AWS_CMD apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${PROXY_ID} \
  --http-method ANY \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
  --region ${AWS_REGION} >/dev/null

# Setup ANY method on root resource
echo "🔧 Setting up ANY method on root resource..."
$AWS_CMD apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${ROOT_ID} \
  --http-method ANY \
  --authorization-type "NONE" \
  --region ${AWS_REGION} >/dev/null

$AWS_CMD apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${ROOT_ID} \
  --http-method ANY \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
  --region ${AWS_REGION} >/dev/null

# Deploy API
echo "🚀 Deploying API..."
$AWS_CMD apigateway create-deployment \
  --rest-api-id ${API_ID} \
  --stage-name dev \
  --region ${AWS_REGION} >/dev/null

echo "✅ API Gateway setup complete!"
echo ""
echo "📋 Invoke URL:"
echo "   http://localhost:4566/restapis/${API_ID}/dev/_user_request_/"
echo ""
echo "🧪 Test with:"
echo "   curl http://localhost:4566/restapis/${API_ID}/dev/_user_request_/"

