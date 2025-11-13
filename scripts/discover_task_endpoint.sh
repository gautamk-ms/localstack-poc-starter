# scripts/discover_task_endpoint.sh
#!/usr/bin/env bash
# Reads endpoint info written by ecs_deploy.sh
set -euo pipefail

if [ ! -f .ecs_task_endpoint ]; then
  echo "❌ .ecs_task_endpoint not found. Run ecs_deploy.sh first."
  exit 1
fi

echo "📡 Discovered ECS task endpoint:"
cat .ecs_task_endpoint