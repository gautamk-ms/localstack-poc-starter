# 🧭 RUNBOOK — LocalStack Lambda POC Setup

**Project:** Local AWS Emulator POC *(FastAPI Lambda + DynamoDB + S3 + API Gateway)*  
**Goal:** Build a **fully local, cost-free AWS serverless simulation** using **LocalStack Community Edition** and **Lambda ZIP packages**, integrating a FastAPI service that interacts with DynamoDB and S3 through API Gateway.

> **💡 Note:** This guide uses **ZIP package deployment** for Lambda (required for LocalStack CE). Container images require LocalStack Pro.

---

## 📋 Table of Contents

1. [Prerequisites](#-1-prerequisites)
2. [Environment Setup](#️-2-environment-setup)
3. [Prepare Lambda Deployment Package](#-3-prepare-lambda-deployment-package)
4. [Initialize AWS Resources](#-4-initialize-aws-resources)
5. [Create Lambda Function](#-5-create-lambda-function)
6. [Create API Gateway Integration](#-6-create-api-gateway-integration)
7. [Test API Functionality](#-7-test-api-functionality)
8. [Expected Timings](#-8-expected-timings)
9. [Cleanup](#-9-cleanup)
10. [Troubleshooting](#-10-troubleshooting)
11. [Verification Summary](#-11-verification-summary)

---

## 📦 1. Prerequisites

Before starting, confirm your system meets the following requirements.

### 🧰 Tools Required

| Tool | Version | Purpose |
|------|---------|----------|
| **Docker Desktop** | 4.x+ | Required for running containers and building Lambda images |
| **Docker Compose** | v2+ | Orchestrates LocalStack service |
| **AWS CLI** | v2+ | Interact with LocalStack AWS APIs |
| **awslocal** (optional) | Latest | Recommended CLI wrapper for LocalStack (installs via pip) |
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

### 📦 Install awslocal (Recommended)

**Option 1: Virtual Environment (Recommended for Isolation)**

```bash
# Create virtual environment and install awslocal
source venv_activate.sh
```

This script will:
- Create a Python virtual environment (`venv/`) if it doesn't exist
- Install `awscli-local` in the virtual environment
- Set up `awslocal` command via helper wrapper
- Load AWS CLI alias helpers

**Option 2: System-wide Installation**

```bash
# Using pipx (recommended for system-wide)
pipx install awscli-local

# Or using pip with --user flag
pip install --user awscli-local

# Or using pip in a virtual environment
python3 -m venv venv
source venv/bin/activate
pip install awscli-local
```

**Option 3: Use Helper Wrapper (No Installation Required)**

If `awslocal` is not installed, you can use the helper script:

```bash
source utils/aws_cli_alias.sh
```

This creates an `awslocal` function that wraps `aws` CLI with LocalStack endpoint.

> **🧠 Note:** LocalStack uses dummy credentials — no real AWS account or billing is involved.  
> **Best Practice:** Use `awslocal` instead of `aws --endpoint-url=http://localhost:4566` for cleaner commands.  
> **💡 Tip:** The virtual environment approach (`venv_activate.sh`) is recommended as it keeps dependencies isolated and works reliably across different systems.

### 📋 Python Dependencies

The `fastapi/requirements.txt` includes all necessary dependencies:
- `fastapi` - Web framework
- `mangum` - ASGI to Lambda adapter
- `boto3` / `botocore` - AWS SDK
- `pydantic` - Data validation (requires `pydantic_core` native extension)
- `exceptiongroup` - Required for Python 3.10 compatibility with pydantic

> **💡 Note:** The deployment script automatically installs all dependencies in a Linux x86_64 environment to ensure compatibility.

---

## ⚙️ 2. Environment Setup

### 🪣 2.1 Clone the Repository

```bash
git clone <your-repo-url> localstack-poc-starter
cd localstack-poc-starter
```

### 🔧 2.1.1 Setup Python Environment (Optional but Recommended)

**Using Virtual Environment:**
```bash
# Activate virtual environment and install awslocal
source venv_activate.sh
```

**Or manually:**
```bash
# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install awslocal
pip install awscli-local

# Load AWS CLI helpers
source utils/aws_cli_alias.sh
```

> **💡 Note:** The `venv/` directory is in `.gitignore` and won't be committed to version control.

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
TABLE_NAME=ShopInventory
S3_BUCKET=poc-data-bucket
EOF
```

### 🐳 2.3 Start LocalStack

```bash
docker compose up -d
```

This will:
- Launch LocalStack (AWS emulator) with services: `apigateway`, `lambda`, `dynamodb`, `s3`

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
    "s3": "running",
    "lambda": "running",
    "apigateway": "available"
  }
}
```

---

## 🏗️ 3. Prepare Lambda Deployment Package

> **📦 Deployment Method:** For LocalStack Community Edition, we use **ZIP package deployment**. Container images require LocalStack Pro.

The Lambda deployment script (`deploy_lambda_zip.sh`) will automatically:
- Build the package in a Linux x86_64 Docker container (ensures correct architecture)
- Package the FastAPI application code
- Install all dependencies (including native extensions like `pydantic_core`)
- Create a deployment ZIP file with correct architecture binaries
- Deploy to LocalStack

> **💡 Important:** The script uses Docker with `--platform linux/amd64` to ensure native extensions (like `pydantic_core`) are compiled for x86_64 architecture, which matches Lambda's runtime environment. This is critical on ARM-based systems (Apple Silicon, etc.).

> **💡 Optional:** If you want to build the container image for testing (requires LocalStack Pro):
> ```bash
> cd fastapi
> docker build -t fastapi-lambda:latest .
> cd ..
> ```

---

## 🧱 4. Initialize AWS Resources

Run the resource initialization script to create the DynamoDB table and S3 bucket:

```bash
chmod +x setup_localstack.sh
./setup_localstack.sh
```

This script will:
- Wait for LocalStack services to be ready
- Create DynamoDB table: `ShopInventory`
- Create S3 bucket: `poc-data-bucket`
- Upload `sample.txt` to S3 bucket

> **💡 Note:** The script automatically handles AWS credentials. If `awslocal` is not installed, it will use `aws` CLI with dummy credentials (`test`/`test`) and the LocalStack endpoint.

### Verify Resources

**DynamoDB Table:**
```bash
awslocal dynamodb list-tables
# Or: aws --endpoint-url=http://localhost:4566 dynamodb list-tables --region us-east-1
```

✅ **Expected output:**
```json
{
  "TableNames": ["ShopInventory"]
}
```

**S3 Bucket:**
```bash
awslocal s3 ls
# Or: aws --endpoint-url=http://localhost:4566 s3 ls --region us-east-1
```

✅ **Expected output:**
```
poc-data-bucket
```

**S3 File:**
```bash
awslocal s3 ls s3://poc-data-bucket/
# Or: aws --endpoint-url=http://localhost:4566 s3 ls s3://poc-data-bucket/ --region us-east-1
```

✅ **Expected output:**
```
sample.txt
```

---

## ⚡ 5. Create Lambda Function

> **🚀 Quick Option (Recommended):** Use the automated ZIP deployment script:
> ```bash
> ./scripts/deploy_lambda_zip.sh
> ```
> This script packages and deploys the Lambda function automatically. Skip to section 5.4 if using the script.
>
> **📦 Note:** For LocalStack Community Edition, use ZIP packages. Container images require LocalStack Pro.

### 5.1 Create Lambda Deployment Package (Manual)

> **⚠️ Warning:** Manual package creation on macOS/ARM systems may result in architecture mismatches. Use the automated script (`deploy_lambda_zip.sh`) which handles this automatically.

If not using the automated script, create the ZIP package manually using Docker to ensure correct architecture:

```bash
# Use Docker to build package in Linux x86_64 environment
docker run --rm \
  --platform linux/amd64 \
  --entrypoint /bin/bash \
  -v "$(pwd)/fastapi:/var/task/fastapi:ro" \
  -v "$(pwd):/var/output" \
  -w /var/task \
  public.ecr.aws/lambda/python:3.10 \
  -c "
    TEMP_DIR=\$(mktemp -d)
    cp -r fastapi/app \${TEMP_DIR}/
    pip install -r fastapi/requirements.txt -t \${TEMP_DIR}/ --quiet --no-cache-dir
    python3 -c \"
import zipfile
import os
zip_path = '/var/output/lambda_function.zip'
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk('\${TEMP_DIR}'):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, '\${TEMP_DIR}')
            zipf.write(file_path, arcname)
\"
    rm -rf \${TEMP_DIR}
  "
```

> **💡 Note:** The `--platform linux/amd64` flag ensures native extensions are compiled for x86_64, matching Lambda's runtime.

### 5.2 Create Lambda Function

```bash
awslocal lambda create-function \
  --function-name fastapi-inventory \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --handler app.lambda_handler.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{TABLE_NAME=ShopInventory,S3_BUCKET=poc-data-bucket,AWS_REGION=us-east-1,AWS_ENDPOINT_URL=http://localstack:4566,AWS_ACCESS_KEY_ID=test,AWS_SECRET_ACCESS_KEY=test}"
```

> **💡 Note:** The role ARN is a dummy value for LocalStack. The environment variables configure the Lambda to connect to LocalStack services.

### 5.4 Verify Lambda Function

```bash
awslocal lambda list-functions
# Or: aws --endpoint-url=http://localhost:4566 lambda list-functions --region us-east-1
```

✅ **Expected:** Function `fastapi-inventory` should appear in the list.

### 5.5 Test Lambda Directly (Optional)

```bash
# Create a test event file
echo '{"httpMethod":"GET","path":"/","headers":{},"body":null,"isBase64Encoded":false}' > test_event.json

# Invoke Lambda
awslocal lambda invoke \
  --function-name fastapi-inventory \
  --payload file://test_event.json \
  response.json

cat response.json | jq .
```

---

## 🔗 6. Create API Gateway Integration

> **🚀 Quick Option:** Use the automated setup script instead of manual steps:
> ```bash
> ./scripts/setup_apigateway.sh
> ```
> This script automates all steps below (6.1-6.8). The API ID will be saved to `.api_id` file. Skip to section 7 if using the script.

Create API Gateway REST API and integrate it with the Lambda function.

### 6.1 Create REST API

```bash
API_ID=$(awslocal apigateway create-rest-api \
  --name fastapi-lambda-proxy \
  --region us-east-1 \
  --query 'id' --output text)

echo "API ID: $API_ID"
```

### 6.2 Get Root Resource ID

```bash
ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id $API_ID \
  --region us-east-1 \
  --query "items[?path=='/'].id" --output text)

echo "Root Resource ID: $ROOT_ID"
```

### 6.3 Create Proxy Resource (Catch-all)

```bash
PROXY_ID=$(awslocal apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part '{proxy+}' \
  --region us-east-1 \
  --query 'id' --output text)

echo "Proxy Resource ID: $PROXY_ID"
```

### 6.4 Create ANY Method on Proxy Resource

```bash
awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $PROXY_ID \
  --http-method ANY \
  --authorization-type "NONE" \
  --region us-east-1
```

### 6.5 Create Integration with Lambda

```bash
awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $PROXY_ID \
  --http-method ANY \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:fastapi-inventory/invocations" \
  --region us-east-1
```

### 6.6 Create Method on Root Resource (for root path)

```bash
awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method ANY \
  --authorization-type "NONE" \
  --region us-east-1

awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method ANY \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:fastapi-inventory/invocations" \
  --region us-east-1
```

### 6.7 Deploy API

```bash
awslocal apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev \
  --region us-east-1
```

### 6.8 Get Invoke URL

```bash
echo "Invoke URL:"
echo "http://localhost:4566/restapis/$API_ID/dev/_user_request_/"
```

Save the API_ID for testing:
```bash
echo $API_ID > .api_id
```

---

## 🧪 7. Test API Functionality

### 🔸 Test Health Endpoint

```bash
API_ID=$(cat .api_id)
curl -s "http://localhost:4566/restapis/$API_ID/dev/_user_request_/" | jq .
```

✅ **Expected:**
```json
{
  "message": "FastAPI Inventory Service running on Lambda (LocalStack)"
}
```

### 🔸 Test POST /inventory (Create Item)

```bash
API_ID=$(cat .api_id)
curl -i -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory" \
  -H "Content-Type: application/json" \
  -d '{"sku":"sku-001","name":"Test Product","qty":10}'
```

✅ **Expected:** HTTP 200 with created item JSON

### 🔸 Test GET /inventory/{sku} (Get Item)

```bash
API_ID=$(cat .api_id)
curl -s "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory/sku-001" | jq .
```

✅ **Expected:**
```json
{
  "sku": "sku-001",
  "name": "Test Product",
  "qty": 10
}
```

### 🔸 Verify Data in DynamoDB

```bash
awslocal dynamodb get-item \
  --table-name ShopInventory \
  --key '{"sku":{"S":"sku-001"}}' | jq .
```

✅ **Expected:**
```json
{
  "Item": {
    "sku": {"S": "sku-001"},
    "name": {"S": "Test Product"},
    "qty": {"N": "10"}
  }
}
```

### 🔸 Test GET /file/download/{filename} (S3 Download)

```bash
API_ID=$(cat .api_id)
curl -i "http://localhost:4566/restapis/$API_ID/dev/_user_request_/file/download/sample.txt"
```

✅ **Expected:** HTTP 200 with file content (text file)

### 🔸 Test DELETE /inventory/{sku} (Delete Item)

```bash
API_ID=$(cat .api_id)
curl -i -X DELETE "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory/sku-001"
```

✅ **Expected:** HTTP 200 with deletion confirmation

---

## 🕒 8. Expected Timings

| Step | Duration |
|------|----------|
| Docker Compose startup | ~1–2 min |
| LocalStack init | 60–90 sec |
| Package Lambda ZIP (Docker build) | 60–120 sec |
| Resource setup (DynamoDB, S3) | <10 sec |
| Lambda function creation | 10–20 sec |
| API Gateway setup | 15–30 sec |
| **Total Setup Time** | **≈ 5–7 minutes** |

---

## 🧹 9. Cleanup

When finished, tear down your environment cleanly.

### Stop LocalStack

```bash
docker compose down
```

### Remove Lambda Function

```bash
awslocal lambda delete-function --function-name fastapi-inventory
```

### Remove Lambda ZIP Package (optional)

```bash
rm -f lambda_function.zip
```

### Remove Docker Images (optional, if built)

```bash
docker rmi fastapi-lambda:latest || true
```

### Remove LocalStack Data (optional)

```bash
rm -rf localstack_data/
```

### Remove Virtual Environment (optional)

```bash
# Deactivate venv if active
deactivate 2>/dev/null || true

# Remove venv directory
rm -rf venv/
```

### Verify Cleanup

```bash
docker ps -a
docker images
```

---

## 🧩 10. Troubleshooting

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| Lambda function not found | Function not created | Re-run Lambda creation step |
| Connection refused (Lambda) | LocalStack not running | Check `docker compose ps` |
| Table not found | Setup script didn't run | Re-run `./setup_localstack.sh` |
| S3 file not found | File not uploaded | Check S3 bucket contents |
| API Gateway 502 | Lambda integration error | Check Lambda logs: `awslocal logs tail /aws/lambda/fastapi-inventory` |
| Lambda timeout | Function taking too long | Increase timeout in Lambda config |
| "Unable to locate credentials" | AWS CLI needs credentials | Scripts auto-export credentials; if running manually, set `AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test` |
| "Container images are a Pro feature" | Using container images in CE | Use ZIP package deployment instead (`deploy_lambda_zip.sh`) |
| Lambda function in Pending state | Function still initializing | Wait 5-10 seconds and retry |
| "No module named 'exceptiongroup'" | Missing dependency | Ensure `exceptiongroup>=1.0.0` is in `requirements.txt` |
| "No module named 'pydantic_core._pydantic_core'" | Architecture mismatch | Rebuild package with `--platform linux/amd64` in Docker (use `deploy_lambda_zip.sh`) |
| ImportModuleError with native extensions | Wrong architecture binaries | Package must be built in Linux x86_64 environment (script handles this automatically) |

> **💡 Pro Tip:** Use `docker logs localstack` to inspect LocalStack logs for detailed error messages.

### View Lambda Logs

```bash
awslocal logs tail /aws/lambda/fastapi-inventory --follow
```

---

## 🧾 11. Verification Summary

| Component | Command | Expected Result |
|-----------|---------|-----------------|
| LocalStack | `curl -s http://localhost:4566/_localstack/health \| jq .` | Services show as "running" |
| DynamoDB | `awslocal dynamodb list-tables` | ShopInventory present |
| S3 | `awslocal s3 ls` | poc-data-bucket present |
| Lambda | `awslocal lambda list-functions` | fastapi-inventory function present |
| API Gateway | `curl -s $API_URL/` | JSON health message |
| Inventory API | `curl -X POST $API_URL/inventory -d '{"sku":"test","name":"test","qty":1}'` | 200 OK |
| S3 Download | `curl $API_URL/file/download/sample.txt` | File content returned |

---

## 🎉 Result

You now have a fully functional, cost-free AWS serverless emulation running locally, featuring:

- 🧩 **API Gateway → Lambda → DynamoDB/S3**
- ⚡ **Serverless architecture** (no ECS/EC2)
- 💸 **Zero AWS cost**
- 🧪 **Local reproducibility** for demos, tests, and CI/CD pipelines
- 📦 **Lambda ZIP package** deployment (LocalStack CE compatible)

---

## 📚 Best Practices Followed

1. ✅ **awslocal CLI** - Recommended wrapper for LocalStack interactions (with automatic fallback to `aws` CLI)
2. ✅ **Environment Variables** - Configuration via Lambda environment variables
3. ✅ **Lambda ZIP Packages** - Compatible with LocalStack Community Edition
4. ✅ **Architecture Compatibility** - Docker builds ensure x86_64 native extensions for Lambda runtime
5. ✅ **Mangum Adapter** - ASGI to Lambda event bridge
6. ✅ **Minimal Changes** - FastAPI code remains largely unchanged
7. ✅ **Clean Architecture** - Removed all ECS/EC2 dependencies
8. ✅ **Automated Scripts** - Deployment scripts handle credentials, architecture, and error cases automatically
9. ✅ **Credential Handling** - Scripts automatically export dummy credentials when `awslocal` is not available
10. ✅ **Dependency Management** - All required dependencies (including `exceptiongroup`) are properly included

---
