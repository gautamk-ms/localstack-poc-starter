# scripts/apigw_setup_for_ecs.sh
#!/usr/bin/env bash
# Create API Gateway and integrate with ECS task endpoint
set -euo pipefail

AWS_ENDPOINT=${AWS_ENDPOINT_URL:-http://localhost:4566}
REGION=${AWS_REGION:-us-east-1}
API_NAME=${1:-fastapi-ecs-proxy}
PATH_PART=${2:-inventory}

if [ ! -f .ecs_task_endpoint ]; then
  echo "❌ .ecs_task_endpoint not found. Run ecs_deploy.sh first."
  exit 1
fi

ENDPT=$(cat .ecs_task_endpoint)

echo "🌐 Creating API Gateway REST API: $API_NAME"
API_ID=$(aws --endpoint-url=$AWS_ENDPOINT apigateway create-rest-api \
  --name "$API_NAME" --region $REGION --query 'id' --output text)
echo "✅ API created with ID: $API_ID"

ROOT_ID=$(aws --endpoint-url=$AWS_ENDPOINT apigateway get-resources \
  --rest-api-id $API_ID --region $REGION --query "items[?path=='/'].id" --output text)

RES_ID=$(aws --endpoint-url=$AWS_ENDPOINT apigateway create-resource \
  --rest-api-id $API_ID --parent-id $ROOT_ID --path-part $PATH_PART --region $REGION \
  --query 'id' --output text)
echo "✅ Resource created: /$PATH_PART"

aws --endpoint-url=$AWS_ENDPOINT apigateway put-method \
  --rest-api-id $API_ID --resource-id $RES_ID --http-method POST \
  --authorization-type "NONE" --region $REGION >/dev/null

INTEGRATION_URI="http://$ENDPT/$PATH_PART"

aws --endpoint-url=$AWS_ENDPOINT apigateway put-integration \
  --rest-api-id $API_ID --resource-id $RES_ID --http-method POST \
  --type HTTP --integration-http-method POST --uri $INTEGRATION_URI --region $REGION >/dev/null

aws --endpoint-url=$AWS_ENDPOINT apigateway create-deployment \
  --rest-api-id $API_ID --stage-name dev --region $REGION >/dev/null

echo "✅ API deployed successfully!"
echo "Invoke URL:"
echo "http://localhost:4566/restapis/$API_ID/dev/_user_request_/$PATH_PART"