# 🚀 Architecture Migration Summary

## Migration Overview

**From:** `API Gateway (LocalStack) => ECS (Local Docker Container) => DynamoDB (LocalStack)`  
**To:** `API Gateway (LocalStack) => Lambda (LocalStack Container Image) => DynamoDB/S3 (LocalStack)`

---

## ✅ Completed Changes

### 1. FastAPI Application Updates

#### Files Modified:
- **`fastapi/app/main.py`**
  - Added S3 client initialization
  - Added `/file/download/{filename}` route for S3 file downloads
  - Updated environment variable handling (TABLE_NAME, S3_BUCKET)
  - Updated service title to reflect Lambda architecture

#### Files Created:
- **`fastapi/app/lambda_handler.py`** (NEW)
  - Lambda handler using Mangum adapter
  - Bridges FastAPI (ASGI) to AWS Lambda events

#### Files Updated:
- **`fastapi/requirements.txt`**
  - Removed `uvicorn[standard]` (not needed for Lambda)
  - Added `mangum==0.17.0` (ASGI to Lambda adapter)

- **`fastapi/Dockerfile`**
  - Changed from `python:3.10-slim` to `public.ecr.aws/lambda/python:3.10`
  - Updated CMD to use Lambda handler: `app.lambda_handler.lambda_handler`
  - Removed port exposure (not needed for Lambda)

### 2. Infrastructure Changes

#### Files Created:
- **`setup_localstack.sh`** (NEW)
  - Replaces old `init_localstack.sh`
  - Creates DynamoDB table: `ShopInventory`
  - Creates S3 bucket: `poc-data-bucket`
  - Uploads `sample.txt` to S3
  - Uses `awslocal` CLI (best practice)

- **`docker-compose.yml`** (UPDATED)
  - Removed FastAPI service (now runs as Lambda)
  - Updated LocalStack services: `apigateway,lambda,dynamodb,s3`
  - Removed ECS/ECR services
  - Updated LocalStack version to 3.0
  - Added Lambda executor configuration

### 3. Deployment Scripts

#### Files Created:
- **`scripts/deploy_lambda.sh`** (NEW)
  - Builds Lambda container image
  - Creates ECR repository
  - Pushes image to LocalStack ECR
  - Creates/updates Lambda function with environment variables

- **`scripts/setup_apigateway.sh`** (NEW)
  - Creates API Gateway REST API
  - Sets up proxy resource for all paths
  - Integrates API Gateway with Lambda function
  - Deploys API to `dev` stage

#### Files Removed:
- ❌ `init_localstack.sh` (replaced by `setup_localstack.sh`)
- ❌ `scripts/ecs_deploy.sh`
- ❌ `scripts/discover_task_endpoint.sh`
- ❌ `scripts/apigw_setup_for_ecs.sh`
- ❌ `scripts/build_and_push_ecr.sh`

### 4. Documentation Updates

#### Files Updated:
- **`RUNBOOK.md`** (COMPLETELY REWRITTEN)
  - Updated for Lambda architecture
  - Removed all ECS-related steps
  - Added Lambda deployment steps
  - Added S3 testing procedures
  - Updated troubleshooting section
  - Added best practices section

---

## 📋 Key Architecture Differences

| Aspect | Old (ECS) | New (Lambda) |
|--------|-----------|--------------|
| **Compute** | Docker container running 24/7 | Lambda function (on-demand) |
| **Deployment** | Docker Compose | Lambda Container Image |
| **Entry Point** | `uvicorn app.main:app` | `app.lambda_handler.lambda_handler` |
| **Adapter** | None (direct FastAPI) | Mangum (ASGI → Lambda) |
| **Base Image** | `python:3.10-slim` | `public.ecr.aws/lambda/python:3.10` |
| **Networking** | Container networking | Lambda invocation |
| **Scaling** | Manual container scaling | Automatic Lambda scaling |
| **Storage** | DynamoDB only | DynamoDB + S3 |

---

## 🔧 Environment Variables

### Required Variables (`.env` file):

```bash
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_ENDPOINT_URL=http://localhost:4566
TABLE_NAME=ShopInventory
S3_BUCKET=poc-data-bucket
```

### Lambda Function Environment Variables:

- `TABLE_NAME` - DynamoDB table name
- `S3_BUCKET` - S3 bucket name
- `AWS_REGION` - AWS region
- `AWS_ENDPOINT_URL` - LocalStack endpoint
- `AWS_ACCESS_KEY_ID` - Dummy credentials
- `AWS_SECRET_ACCESS_KEY` - Dummy credentials

---

## 🎯 New API Endpoints

All existing endpoints remain unchanged:
- `GET /` - Health check
- `POST /inventory` - Create item
- `GET /inventory/{sku}` - Get item
- `DELETE /inventory/{sku}` - Delete item

**New endpoint:**
- `GET /file/download/{filename}` - Download file from S3

---

## 🚀 Quick Start (New Workflow)

1. **Start LocalStack:**
   ```bash
   docker compose up -d
   ```

2. **Initialize Resources:**
   ```bash
   ./setup_localstack.sh
   ```

3. **Deploy Lambda:**
   ```bash
   ./scripts/deploy_lambda.sh
   ```

4. **Setup API Gateway:**
   ```bash
   ./scripts/setup_apigateway.sh
   ```

5. **Test API:**
   ```bash
   API_ID=$(cat .api_id)
   curl "http://localhost:4566/restapis/$API_ID/dev/_user_request_/"
   ```

---

## 📚 Best Practices Implemented

1. ✅ **awslocal CLI** - Recommended wrapper for LocalStack
2. ✅ **Environment Variables** - Configuration via Lambda env vars
3. ✅ **Lambda Container Images** - Modern deployment pattern
4. ✅ **Mangum Adapter** - Standard ASGI to Lambda bridge
5. ✅ **Minimal Code Changes** - FastAPI logic unchanged
6. ✅ **Clean Separation** - Removed all ECS dependencies
7. ✅ **Automated Scripts** - Simplified deployment process

---

## 🧪 Testing Checklist

- [x] Lambda function creates successfully
- [x] API Gateway integrates with Lambda
- [x] DynamoDB operations work (POST, GET, DELETE)
- [x] S3 file download works
- [x] Environment variables are read correctly
- [x] All endpoints respond correctly via API Gateway

---

## 📝 Notes

- The Lambda function uses a dummy IAM role ARN (`arn:aws:iam::000000000000:role/lambda-role`) which is acceptable for LocalStack
- LocalStack Lambda executor is set to `docker` mode for container image support
- The FastAPI application code remains largely unchanged - only Lambda-specific wrapper was added
- All old ECS-related files and scripts have been removed for a clean architecture

---

## 🎉 Migration Complete!

The project has been successfully migrated from ECS to Lambda architecture. All functionality is preserved, with the addition of S3 support and a more serverless-oriented deployment model.

