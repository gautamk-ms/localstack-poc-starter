# scripts/ecs_deploy.sh
#!/usr/bin/env bash
# Register ECS Task Definition and run it in LocalStack
set -euo pipefail

IMAGE_URI=${1:-localhost:4566/fastapi-inventory:latest}
TASK_DEF_NAME=${2:-fastapi-task}
AWS_ENDPOINT=${AWS_ENDPOINT_URL:-http://localhost:4566}
REGION=${AWS_REGION:-us-east-1}

echo "📋 Registering ECS Task Definition: $TASK_DEF_NAME"

read -r -d '' TASK_DEF_JSON <<EOF
{
  "family": "$TASK_DEF_NAME",
  "networkMode": "bridge",
  "containerDefinitions": [
    {
      "name": "fastapi-container",
      "image": "$IMAGE_URI",
      "essential": true,
      "portMappings": [
        { "containerPort": 8000, "hostPort": 0 }
      ],
      "environment": [
        {"name":"AWS_REGION","value":"$REGION"},
        {"name":"AWS_ENDPOINT_URL","value":"$AWS_ENDPOINT"}
      ]
    }
  ]
}
EOF

aws --endpoint-url=$AWS_ENDPOINT ecs register-task-definition --cli-input-json "$TASK_DEF_JSON" --region $REGION >/dev/null
echo "✅ Task definition registered."

echo "🚀 Running ECS task..."
RUN_RESP=$(aws --endpoint-url=$AWS_ENDPOINT ecs run-task --cluster default --task-definition $TASK_DEF_NAME --region $REGION)
echo "$RUN_RESP" | jq .

sleep 10

# Find container port mapping
CON_ID=$(docker ps --filter ancestor=$IMAGE_URI --format '{{.ID}}' | head -n1)
if [ -z "$CON_ID" ]; then
  echo "⚠️ Could not find container. Trying fallback filter..."
  CON_ID=$(docker ps --filter ancestor=localhost:4566/fastapi-inventory --format '{{.ID}}' | head -n1)
fi

if [ -z "$CON_ID" ]; then
  echo "❌ ERROR: FastAPI container not found after ECS run."
  exit 2
fi

HOST_PORT=$(docker port "$CON_ID" 8000 | sed -n 's/.*:\\([0-9]*\\)/\\1/p')
echo "🌐 Container running at localhost:$HOST_PORT"

echo "localhost:$HOST_PORT" > .ecs_task_endpoint
echo "✅ Saved endpoint to .ecs_task_endpoint"