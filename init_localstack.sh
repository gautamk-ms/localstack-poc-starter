#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# init_localstack.sh
# -----------------------------------------------------------------------------
# Purpose:
#   Initialize a LocalStack-based AWS emulator environment for your POC.
#   - Waits until key services (DynamoDB, API Gateway) are ready
#   - Creates DynamoDB table "Inventory"
#   - Ensures ECS cluster "default"
#   - Ensures ECR repo "fastapi-inventory"
#
# Works with: LocalStack Community Edition on macOS
# -----------------------------------------------------------------------------

set -euo pipefail

# Load environment variables from .env if present
if [ -f .env ]; then
  source .env
fi

# Default fallback values
: "${AWS_REGION:=us-east-1}"
: "${AWS_ENDPOINT_URL:=http://localhost:4566}"
: "${ECR_REPO_NAME:=fastapi-inventory}"
: "${DYNAMO_TABLE:=Inventory}"

# Only check for available core services in LocalStack Community
REQUIRED_SERVICES=(dynamodb apigateway)

MAX_RETRIES=60
SLEEP_SEC=2
i=0

echo "🔍 Waiting for LocalStack services to be ready: ${REQUIRED_SERVICES[*]}"

while true; do
  HEALTH_JSON=$(curl -s "${AWS_ENDPOINT_URL}/_localstack/health" || true)
  if [ -n "$HEALTH_JSON" ]; then
    all_ok=true
    for svc in "${REQUIRED_SERVICES[@]}"; do
      status=$(echo "$HEALTH_JSON" | jq -r --arg svc "$svc" '.services[$svc] // "missing"' 2>/dev/null || echo "missing")
      if [ "$status" != "available" ] \&\& \[ "$status" != "running" \]; then
        all_ok=false
        break
      fi
    done
    if $all_ok; then
      echo "✅ All required services are available."
      break
    fi
    echo "⏳ Not ready yet; current statuses:"
    echo "$HEALTH_JSON" | jq '.services'
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
# Create or verify DynamoDB table
# ---------------------------------------------------------------------------
echo "📦 Ensuring DynamoDB table: ${DYNAMO_TABLE}"
aws --endpoint-url="${AWS_ENDPOINT_URL}" dynamodb describe-table \
  --table-name "${DYNAMO_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
aws --endpoint-url="${AWS_ENDPOINT_URL}" dynamodb create-table \
  --table-name "${DYNAMO_TABLE}" \
  --attribute-definitions AttributeName=sku,AttributeType=S \
  --key-schema AttributeName=sku,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}"

echo "✅ DynamoDB table '${DYNAMO_TABLE}' ready."
aws --endpoint-url="${AWS_ENDPOINT_URL}" dynamodb list-tables --region "${AWS_REGION}"

# ---------------------------------------------------------------------------
# Create ECS cluster (for later ECS task demo)
# ---------------------------------------------------------------------------
CLUSTER_NAME=default
echo "⚙️  Ensuring ECS cluster: ${CLUSTER_NAME}"
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecs describe-clusters \
  --clusters "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecs create-cluster \
  --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}"
echo "✅ ECS cluster '${CLUSTER_NAME}' ensured."
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecs list-clusters --region "${AWS_REGION}"

# ---------------------------------------------------------------------------
# Create ECR repository (for storing FastAPI Docker image)
# ---------------------------------------------------------------------------
echo "🗂️  Ensuring ECR repository: ${ECR_REPO_NAME}"
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecr describe-repositories \
  --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecr create-repository \
  --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}"
echo "✅ ECR repository '${ECR_REPO_NAME}' ensured."
aws --endpoint-url="${AWS_ENDPOINT_URL}" ecr describe-repositories \
  --region "${AWS_REGION}" | jq -r '.repositories[].repositoryName'

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--------------------------------------------------------"
echo "✅ LocalStack initialization complete."
echo "📊 Summary:"
echo "   • DynamoDB table  : ${DYNAMO_TABLE}"
echo "   • ECS cluster     : ${CLUSTER_NAME}"
echo "   • ECR repository  : ${ECR_REPO_NAME}"
echo "--------------------------------------------------------"
EOF