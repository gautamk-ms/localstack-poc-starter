# scripts/build_and_push_ecr.sh
#!/usr/bin/env bash
# Build and push FastAPI image to LocalStack ECR
set -euo pipefail

IMAGE=${1:-fastapi-inventory:latest}
AWS_ENDPOINT=${AWS_ENDPOINT_URL:-http://localhost:4566}
REGION=${AWS_REGION:-us-east-1}
REPO_NAME=$(echo $IMAGE | cut -d ':' -f1)

echo "🛠️ Building Docker image: $IMAGE"
docker build -t $IMAGE -f fastapi/Dockerfile fastapi

echo "📦 Creating ECR repository: $REPO_NAME (if not exists)"
aws --endpoint-url=$AWS_ENDPOINT ecr create-repository --repository-name $REPO_NAME --region $REGION >/dev/null 2>&1 || true

echo "🔐 Logging in to LocalStack ECR"
aws --endpoint-url=$AWS_ENDPOINT ecr get-login-password --region $REGION | docker login --username AWS --password-stdin localhost:4566

TAGGED="localhost:4566/$IMAGE"
echo "🏷️ Tagging image as $TAGGED"
docker tag $IMAGE $TAGGED

echo "📤 Pushing image to LocalStack ECR"
docker push $TAGGED

echo "✅ Image pushed: $TAGGED"
echo "$TAGGED"