
# 🧭 RUNBOOK — LocalStack POC Starter Setup

**Project:** Local AWS Emulator POC *(FastAPI + DynamoDB + API Gateway)*  
**Goal:** Build a **fully local, cost-free AWS simulation** using **LocalStack** and **Docker**, integrating a FastAPI service that interacts with DynamoDB through API Gateway.

---

## 📋 Table of Contents

1. [Prerequisites](#-1-prerequisites)
2. [Environment Setup](#️-2-environment-setup)
3. [Initialize AWS Resources](#-3-initialize-aws-resources)
4. [Run FastAPI Locally](#-4-run-fastapi-locally)
5. [Create API Gateway Integration](#-5-create-api-gateway-integration)
6. [Test API Functionality](#-6-test-api-functionality)
7. [Expected Timings](#-7-expected-timings)
8. [Cleanup](#-8-cleanup)
9. [Troubleshooting](#-9-troubleshooting)
10. [Verification Summary](#-10-verification-summary)

---

## 📦 1. Prerequisites

Before starting, confirm your system meets the following requirements.

### 🧰 Tools Required

| Tool | Version | Purpose |
|------|---------|----------|
| **Docker Desktop** | 4.x+ | Required for running containers |
| **Docker Compose** | v2+ | Orchestrates LocalStack + FastAPI services |
| **AWS CLI** | v2+ | Interact with LocalStack AWS APIs |
| **jq** | Latest | For parsing and formatting JSON |
| **curl** | Built-in | API endpoint testing |
| **git** | Latest | To clone and update the repository |

### ✅ Validate Tools

```bash
docker --version
docker compose version
aws --version
jq --version
curl --version
git --version
```

> **🧠 Note:** LocalStack uses dummy credentials — no real AWS account or billing is involved.

---

## ⚙️ 2. Environment Setup

### 🪣 2.1 Clone the Repository

```bash
git clone <your-repo-url> localstack-poc-starter
cd localstack-poc-starter
```

### 🧾 2.2 Create .env File

Create a new `.env` file at the project root:

```bash
cat > .env <<EOF
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
LOCALSTACK_HOST=localstack
LOCALSTACK_EDGE_PORT=4566
AWS_ENDPOINT_URL=http://localhost:4566
EOF
```

### 🐳 2.3 Start Containers

```bash
docker compose up -d
```

This will:
- Launch LocalStack (AWS emulator)
- Build and start the FastAPI container

> **⏱ Expected Delay:** LocalStack initialization may take 1–2 minutes.

### 🩺 Check Container Status

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

### ✅ Verify LocalStack Health

```bash
curl -s http://localhost:4566/_localstack/health | jq .
```

You should see:

```json
{
  "services": {
    "dynamodb": "running",
    "apigateway": "available",
    ...
  }
}
```

---

## 🧱 3. Initialize AWS Resources

Run the resource initialization script to create the DynamoDB table and mock ECS setup.

```bash
chmod +x init_localstack.sh
./init_localstack.sh
```

### Verify DynamoDB Table

```bash
aws --endpoint-url=http://localhost:4566 dynamodb list-tables --region us-east-1 | jq .
```

✅ **Expected output:**

```json
{
  "TableNames": ["Inventory"]
}
```

---

## 🚀 4. Run FastAPI Locally

If FastAPI isn't already running from Docker Compose, start it manually:

```bash
docker run -d --name fastapi-ecs-run \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_ENDPOINT_URL=http://host.docker.internal:4566 \
  -e TABLE_NAME=Inventory \
  -p 8000:8000 \
  fastapi-inventory:latest
```

### Check FastAPI Container

```bash
docker ps --filter name=fastapi-ecs-run --format "table {{.ID}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
```

### Health Check

```bash
curl -s http://localhost:8000/ | jq .
```

**Expected:**

```json
{"message": "FastAPI Inventory Service running on ECS (LocalStack)"}
```

---

## 🔗 5. Create API Gateway Integration

Integrate API Gateway → FastAPI container → DynamoDB.

```bash
echo "host.docker.internal:8000" > .ecs_task_endpoint
chmod +x ./scripts/apigw_setup_for_ecs.sh
./scripts/apigw_setup_for_ecs.sh fastapi-ecs-proxy inventory
```

✅ **Example output:**

```
🌐 Creating API Gateway REST API: fastapi-ecs-proxy
✅ API created with ID: abcd1234
✅ Resource created: /inventory
✅ API deployed successfully!
Invoke URL:
http://localhost:4566/restapis/abcd1234/dev/_user_request_/inventory
```

---

## 🧪 6. Test API Functionality

### 🔸 Direct FastAPI Call

```bash
curl -i -X POST http://localhost:8000/inventory \
  -H "Content-Type: application/json" \
  -d '{"sku":"sku-local-1","name":"local-test","qty":3}'
```

### 🔸 Verify Data in DynamoDB

```bash
aws --endpoint-url=http://localhost:4566 dynamodb get-item \
  --table-name Inventory \
  --key '{"sku":{"S":"sku-local-1"}}' \
  --region us-east-1 | jq .
```

✅ **Expected:**

```json
{
  "Item": {
    "sku": {"S": "sku-local-1"},
    "name": {"S": "local-test"},
    "qty": {"N": "3"}
  }
}
```

### 🔸 Test via API Gateway

```bash
API_URL="http://localhost:4566/restapis/<API_ID>/dev/_user_request_/inventory"

curl -i -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"sku":"sku-via-api-1","name":"gateway-test","qty":6}'
```

Then verify again with the DynamoDB query above.

---

## 🕒 7. Expected Timings

| Step | Duration |
|------|----------|
| Docker Compose startup | ~1–2 min |
| LocalStack init | 60–90 sec |
| FastAPI boot | <10 sec |
| DynamoDB setup | Instant |
| API Gateway setup | 15–30 sec |
| **Total Setup Time** | **≈ 5 minutes** |

---

## 🧹 8. Cleanup

When finished, tear down your environment cleanly.

### Stop & Remove Containers

```bash
docker stop fastapi-ecs-run localstack || true
docker rm fastapi-ecs-run localstack || true
```

### Remove Docker Images (optional)

```bash
docker rmi fastapi-inventory:latest localstack/localstack:1.4 || true
```

### Remove Networks & Volumes

```bash
docker network prune -f
docker volume prune -f
```

### Verify Cleanup

```bash
docker ps -a
docker images
```

---

## 🧩 9. Troubleshooting

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| NoCredentialsError | Missing dummy AWS credentials | Restart container with test credentials |
| Connection refused (API Gateway) | LocalStack can't access localhost | Use `host.docker.internal:8000` |
| ECS CreateCluster InternalFailure | ECS not available in CE | Safe to ignore |
| Table not found | Init script didn't run | Re-run `./init_localstack.sh` |
| API Gateway POST 400 | FastAPI not running | Restart `fastapi-ecs-run` |

> **💡 Pro Tip:** Use `docker logs <container>` to inspect detailed logs for both LocalStack and FastAPI.

---

## 🧾 10. Verification Summary

| Component | Command | Expected Result |
|-----------|---------|-----------------|
| LocalStack | `curl -s http://localhost:4566/_localstack/health \| jq .` | Services show as "running" |
| DynamoDB | `aws --endpoint-url=http://localhost:4566 dynamodb list-tables` | Inventory table present |
| FastAPI | `curl http://localhost:8000/` | JSON health message |
| API Gateway | `curl -i $API_URL` | 200 OK with JSON payload |

---

## 🎉 Result

You now have a fully functional, cost-free AWS emulation running locally, featuring:

- 🧩 API Gateway → FastAPI → DynamoDB
- 💸 Zero AWS cost  
- 🧪 Local reproducibility for demos, tests, and CI/CD pipelines

---
