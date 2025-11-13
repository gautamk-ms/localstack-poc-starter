#!/usr/bin/env bash
# scripts/show_dynamodb_table.sh
# Display DynamoDB table structure and contents for demo purposes
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  source .env
fi

: "${AWS_REGION:=us-east-1}"
: "${AWS_ENDPOINT_URL:=http://localhost:4566}"
: "${TABLE_NAME:=ShopInventory}"

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
elif command -v awslocal &> /dev/null 2>&1; then
  # Try to use awslocal command if available (but may fail with spaces in path)
  if awslocal --version &> /dev/null 2>&1; then
    AWS_CMD="awslocal"
  else
    # Fallback if awslocal command exists but doesn't work (e.g., broken shebang)
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
    AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT_URL}"
  fi
else
  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
  export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
  AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT_URL}"
fi

echo "═══════════════════════════════════════════════════════════════"
echo "📊 DynamoDB Table: ${TABLE_NAME}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Show table structure
echo "🔷 Table Structure:"
echo "───────────────────────────────────────────────────────────────"
$AWS_CMD dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Table.{TableName:TableName,Status:TableStatus,KeySchema:KeySchema,AttributeDefinitions:AttributeDefinitions,BillingMode:BillingModeSummary.BillingMode,ItemCount:ItemCount,TableSize:TableSizeBytes}' \
  | jq .

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📦 Table Contents (Items):"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Scan table and show items in readable format
ITEMS=$($AWS_CMD dynamodb scan \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Items' \
  | jq -r '.[] | "SKU: \(.sku.S // .sku.N // "N/A")\nName: \(.name.S // "N/A")\nQuantity: \(.qty.N // .qty.S // "N/A")\n───────────────────────────────────────────────────────────────"')

if [ -z "$ITEMS" ] || [ "$ITEMS" = "null" ]; then
  echo "⚠️  Table is empty (no items found)"
  echo ""
  echo "💡 Tip: Add items using the API:"
  echo "   curl -X POST http://localhost:4566/restapis/<API_ID>/dev/_user_request_/inventory \\"
  echo "     -H 'Content-Type: application/json' \\"
  echo "     -d '{\"sku\":\"demo-001\",\"name\":\"Demo Product\",\"qty\":10}'"
else
  echo "$ITEMS"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📈 Summary:"
echo "═══════════════════════════════════════════════════════════════"

# Get item count
COUNT=$($AWS_CMD dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Table.ItemCount' \
  --output text)

echo "Total Items: ${COUNT}"
echo ""

