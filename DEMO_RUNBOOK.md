# 🎬 DEMO RUNBOOK — AWS Emulation on Bare-Metal

**Project:** Local AWS Emulator POC *(FastAPI Lambda + DynamoDB + S3 + API Gateway)*  
**Goal:** Demonstrate a **fully functional AWS-compatible emulation** running locally — **without any AWS account or cloud costs**.

> 💡 **Core Message:** "Run AWS inside your data center — without paying AWS."  
> This demo shows how bare-metal infrastructure can be transformed into a cost-free, AWS-like environment.

---

## 🎯 Demo Objectives

By the end of this demo, viewers will see:
- ✅ **AWS services running locally** (DynamoDB, S3, Lambda, API Gateway)
- ✅ **Real AWS CLI commands** working against LocalStack
- ✅ **Serverless architecture** in action (API Gateway → Lambda → DynamoDB/S3)
- ✅ **Zero cloud costs** — everything runs on local infrastructure
- ✅ **Production-like behavior** — same APIs, same SDKs, same workflows

---

## 🚀 Quick Start (From Scratch)

### Step 0: Setup Environment (Optional but Recommended)

**Option A: Use Virtual Environment (Recommended)**
```bash
# Create and activate virtual environment with awslocal
source venv_activate.sh
```

This will:
- Create a Python virtual environment (`venv/`)
- Install `awscli-local` in the venv
- Set up `awslocal` command
- Load AWS CLI helpers

**Option B: Use Helper Script Only**
```bash
# If awslocal is not installed, use the helper wrapper
source utils/aws_cli_alias.sh
```

**Verify Setup:**
```bash
# Test awslocal (should work with either option)
awslocal --version 2>&1 | head -1
```

**🎤 Demo Talking Point:**
> "We're using a virtual environment to keep dependencies isolated. The `awslocal` command is a wrapper around AWS CLI that automatically points to LocalStack — same commands as AWS, but local."

---

### Step 1: Start LocalStack (AWS Emulator)

```bash
# Start the AWS emulator
docker compose up -d

# Wait for services to be ready (~1-2 minutes)
watch -n 2 'curl -s http://localhost:4566/_localstack/health | jq ".services | {dynamodb, s3, lambda, apigateway}"'
```

**🎤 Demo Talking Point:**
> "LocalStack emulates 100+ AWS services. We're using DynamoDB, S3, Lambda, and API Gateway — all running locally, no AWS account needed."

---

### Step 2: Initialize AWS Resources

```bash
# Create DynamoDB table and S3 bucket (just like AWS!)
./setup_localstack.sh
```

**Expected Output:**
```
✅ DynamoDB table 'ShopInventory' ready.
✅ S3 bucket 'poc-data-bucket' created.
✅ File 'sample.txt' uploaded to S3 bucket.
```

**💡 Note:** The script automatically uploads `sample.txt` to S3 using Python boto3 (more reliable with LocalStack than AWS CLI). The file upload happens within the setup script, so no manual upload is needed.

---

### Step 3: Show AWS Emulation in Action

#### 🔷 Demonstrate DynamoDB (AWS Service Emulation)

```bash
# List tables (AWS CLI command against LocalStack)
# If using venv: source venv_activate.sh (already done in Step 0)
# Otherwise: source utils/aws_cli_alias.sh
awslocal dynamodb list-tables
```

**🎤 Demo Talking Point:**
> "This is the **real AWS CLI** — same command you'd use in production. But it's talking to LocalStack, not AWS."

**Show Table Details:**
```bash
# Describe the table (shows AWS-like structure)
awslocal dynamodb describe-table \
  --table-name ShopInventory \
  --query 'Table.{TableName:TableName,Status:TableStatus,KeySchema:KeySchema,AttributeDefinitions:AttributeDefinitions,BillingMode:BillingModeSummary.BillingMode,ItemCount:ItemCount}' \
  | jq .
```

**Expected Output:**
```json
{
  "TableName": "ShopInventory",
  "Status": "ACTIVE",
  "KeySchema": [
    {
      "AttributeName": "sku",
      "KeyType": "HASH"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "sku",
      "AttributeType": "S"
    }
  ],
  "BillingMode": "PAY_PER_REQUEST",
  "ItemCount": 0
}
```

**🎤 Demo Talking Point:**
> "Notice the structure — **Partition Key (PK): `sku`**, **No Sort Key (SK)**. This is a simple table design. The `Status: ACTIVE` and `BillingMode: PAY_PER_REQUEST` show we're emulating real AWS DynamoDB behavior."

---

#### 🗂️ Demonstrate S3 (AWS Service Emulation)

```bash
# List S3 buckets (AWS CLI command)
awslocal s3 ls
```

**Expected Output:**
```
2025-11-14 01:42:59 poc-data-bucket
```

**Show S3 Bucket Contents:**
```bash
# List objects in bucket
awslocal s3 ls s3://poc-data-bucket/
```

**Expected Output:**
```
sample.txt
```

**Show S3 Object Details:**
```bash
# Get object metadata (AWS S3 API)
awslocal s3api head-object \
  --bucket poc-data-bucket \
  --key sample.txt \
  --query '{Key:Key,Size:ContentLength,LastModified:LastModified,ETag:ETag}' \
  | jq .
```

**Expected Output:**
```json
{
  "Key": "sample.txt",
  "Size": 147,
  "LastModified": "2025-11-14T01:42:59.000Z",
  "ETag": "\"abc123...\""
}
```

**🎤 Demo Talking Point:**
> "This is **real S3 API behavior** — same metadata, same structure. But it's running on our local machine, not in AWS."

**💡 Manual Upload (if needed):**
If you need to upload additional files to S3, use Python boto3 (AWS CLI has compatibility issues with LocalStack):
```bash
python3 <<EOF
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

with open('your-file.txt', 'rb') as f:
    s3.put_object(
        Bucket='poc-data-bucket',
        Key='your-file.txt',
        Body=f.read(),
        ContentType='text/plain'
    )
print("✅ File uploaded successfully!")
EOF
```

---

### Step 4: Deploy Lambda Function

```bash
# Deploy FastAPI as Lambda function
./scripts/deploy_lambda_zip.sh
```

**Expected Output:**
```
✅ Lambda function 'fastapi-inventory' deployed successfully!
📋 Function ARN: arn:aws:lambda:us-east-1:000000000000:function:fastapi-inventory
```

**Verify Lambda Function:**
```bash
# List Lambda functions (AWS CLI)
awslocal lambda list-functions \
  --query 'Functions[*].{FunctionName:FunctionName,Runtime:Runtime,Handler:Handler,LastModified:LastModified}' \
  | jq .
```

**Expected Output:**
```json
[
  {
    "FunctionName": "fastapi-inventory",
    "Runtime": "python3.10",
    "Handler": "app.lambda_handler.lambda_handler",
    "LastModified": "2025-11-14T01:52:10.233Z"
  }
]
```

**🎤 Demo Talking Point:**
> "We just deployed a **serverless function** — same Lambda runtime, same handler pattern. But it's running in LocalStack, not AWS."

---

### Step 5: Setup API Gateway

```bash
# Create API Gateway and integrate with Lambda
./scripts/setup_apigateway.sh
```

**Expected Output:**
```
✅ API Gateway setup complete!
📋 Invoke URL:
   http://localhost:4566/restapis/e4bspkdjor/dev/_user_request_/
```

**Show API Gateway Details:**
```bash
API_ID=$(cat .api_id)
awslocal apigateway get-rest-api \
  --rest-api-id $API_ID \
  --query '{Name:name,Id:id,CreatedDate:createdDate}' \
  | jq .
```

**Expected Output:**
```json
{
  "Name": "fastapi-lambda-proxy",
  "Id": "e4bspkdjor",
  "CreatedDate": "2025-11-14T01:53:22.000Z"
}
```

**🎤 Demo Talking Point:**
> "API Gateway is now routing requests to our Lambda function — **exactly like AWS**, but running locally."

---

### Step 6: Test the Complete Flow

#### 🔸 Test Health Endpoint

```bash
API_ID=$(cat .api_id)
curl -s "http://localhost:4566/restapis/$API_ID/dev/_user_request_/" | jq .
```

**Expected Output:**
```json
{
  "message": "FastAPI Inventory Service running on Lambda (LocalStack)"
}
```

**🎤 Demo Talking Point:**
> "The request flows: **API Gateway → Lambda → FastAPI**. All running locally, but using AWS-native patterns."

---

#### 🔸 Create Item in DynamoDB via API

```bash
API_ID=$(cat .api_id)
curl -i -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory" \
  -H "Content-Type: application/json" \
  -d '{"sku":"demo-001","name":"Demo Product","qty":10}'
```

**Expected Output:**
```http
HTTP/1.1 200 OK
content-type: application/json

{"status":"created","item":{"sku":"demo-001","name":"Demo Product","qty":10}}
```

**🎤 Demo Talking Point:**
> "We just created an item via our API. Let's verify it's actually in DynamoDB."

---

#### 🔸 Verify Data in DynamoDB (Show AWS Emulation)

```bash
# Get item from DynamoDB (AWS CLI)
awslocal dynamodb get-item \
  --table-name ShopInventory \
  --key '{"sku":{"S":"demo-001"}}' \
  | jq .
```

**Expected Output:**
```json
{
  "Item": {
    "sku": {"S": "demo-001"},
    "name": {"S": "Demo Product"},
    "qty": {"N": "10"}
  }
}
```

**🎤 Demo Talking Point:**
> "**This is the real DynamoDB data structure** — notice the type annotations (`{"S": "..."}` for String, `{"N": "10"}` for Number). This is exactly how AWS DynamoDB stores data. We're seeing the actual AWS API behavior, locally."

**Show All Items:**
```bash
# Scan table (show all items)
./scripts/show_dynamodb_table.sh
```

**Expected Output:**
```
═══════════════════════════════════════════════════════════════
📊 DynamoDB Table: ShopInventory
═══════════════════════════════════════════════════════════════

🔷 Table Structure:
───────────────────────────────────────────────────────────────
{
  "TableName": "ShopInventory",
  "Status": "ACTIVE",
  "KeySchema": [
    {
      "AttributeName": "sku",
      "KeyType": "HASH"
    }
  ],
  "BillingMode": "PAY_PER_REQUEST",
  "ItemCount": 1
}

═══════════════════════════════════════════════════════════════
📦 Table Contents (Items):
═══════════════════════════════════════════════════════════════
SKU: demo-001
Name: Demo Product
Quantity: 10
───────────────────────────────────────────────────────────────
```

---

#### 🔸 Retrieve Item via API

```bash
API_ID=$(cat .api_id)
curl -s "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory/demo-001" | jq .
```

**Expected Output:**
```json
{
  "sku": "demo-001",
  "name": "Demo Product",
  "qty": 10
}
```

---

#### 🔸 Test S3 File Download via API

```bash
API_ID=$(cat .api_id)
curl -i "http://localhost:4566/restapis/$API_ID/dev/_user_request_/file/download/sample.txt"
```

**Expected Output:**
```http
HTTP/1.1 200 OK
content-type: text/plain
Content-Disposition: attachment; filename=sample.txt

This is a sample file for LocalStack S3 POC.
Created: Thu Nov 14 01:42:59 IST 2025
Purpose: Demonstrate S3 file download functionality via Lambda.
```

**🎤 Demo Talking Point:**
> "The Lambda function retrieved a file from S3 and served it through API Gateway. **Complete AWS serverless architecture** — running locally!"

---

#### 🔸 Add More Items and Show Table Growth

```bash
API_ID=$(cat .api_id)

# Add multiple items
for i in {1..3}; do
  curl -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/inventory" \
    -H "Content-Type: application/json" \
    -d "{\"sku\":\"item-$i\",\"name\":\"Product $i\",\"qty\":$((i*5))}"
done

# Show updated table
./scripts/show_dynamodb_table.sh
```

**🎤 Demo Talking Point:**
> "Watch the table grow in real-time. This is **real DynamoDB behavior** — we can see the `ItemCount` increase, just like in AWS."

---

### Step 7: Show AWS Service Integration

**Demonstrate Multiple AWS Services Working Together:**
```bash
# Show all AWS resources we've created
echo "=== DynamoDB Tables ==="
awslocal dynamodb list-tables | jq .

echo -e "\n=== S3 Buckets ==="
awslocal s3 ls

echo -e "\n=== Lambda Functions ==="
awslocal lambda list-functions --query 'Functions[*].FunctionName' | jq .

echo -e "\n=== API Gateway APIs ==="
awslocal apigateway get-rest-apis --query 'items[*].{Name:name,Id:id}' | jq .
```

**Expected Output:**
```json
=== DynamoDB Tables ===
{
  "TableNames": ["ShopInventory"]
}

=== S3 Buckets ===
poc-data-bucket

=== Lambda Functions ===
["fastapi-inventory"]

=== API Gateway APIs ===
[
  {
    "Name": "fastapi-lambda-proxy",
    "Id": "e4bspkdjor"
  }
]
```

**🎤 Demo Talking Point:**
> "**Four AWS services** — DynamoDB, S3, Lambda, and API Gateway — all running locally, all integrated, all using real AWS APIs. This is what **AWS emulation** means."

---

## 🧹 Cleanup (Show Complete Teardown)

### Remove All AWS Resources

```bash
# Delete Lambda function
awslocal lambda delete-function --function-name fastapi-inventory

# Delete API Gateway (get API ID first)
API_ID=$(cat .api_id)
awslocal apigateway delete-rest-api --rest-api-id $API_ID

# Delete DynamoDB table
awslocal dynamodb delete-table --table-name ShopInventory

# Delete S3 bucket and contents
awslocal s3 rm s3://poc-data-bucket --recursive
awslocal s3api delete-bucket --bucket poc-data-bucket

# Stop LocalStack
docker compose down

# Remove deployment artifacts
rm -f lambda_function.zip .api_id

# Remove Virtual Environment (optional)
deactivate 2>/dev/null || true
rm -rf venv/
```

**Verify Cleanup:**
```bash
# Verify all resources are gone
echo "=== Checking DynamoDB ==="
awslocal dynamodb list-tables 2>&1 || echo "LocalStack stopped"

echo -e "\n=== Checking S3 ==="
awslocal s3 ls 2>&1 || echo "LocalStack stopped"
```

**🎤 Demo Talking Point:**
> "Everything is cleaned up — **no AWS resources, no cloud costs, no data left behind**. This is the power of local emulation — instant teardown, zero cost."

---

## 🎯 Key Demo Highlights

### 💰 Cost Savings
- **AWS Cost:** $0 (everything runs locally)
- **Development Time:** Same workflows as production
- **Risk:** Zero (no accidental AWS charges)

### 🔄 AWS Compatibility
- **Same APIs:** Real AWS CLI commands work
- **Same SDKs:** boto3 works identically
- **Same Patterns:** Serverless architecture matches AWS

### 🚀 Developer Experience
- **Offline Development:** No internet required
- **Fast Iteration:** Instant deployments
- **Real Testing:** Production-like environment

---

## 📊 Demo Flow Summary

```
1. Start LocalStack (AWS Emulator)
   ↓
2. Create DynamoDB Table (show AWS structure)
   ↓
3. Create S3 Bucket (show AWS API)
   ↓
4. Deploy Lambda Function (serverless)
   ↓
5. Setup API Gateway (routing)
   ↓
6. Test Complete Flow:
   - API → Lambda → DynamoDB (create item)
   - Show DynamoDB data (AWS format)
   - API → Lambda → S3 (download file)
   ↓
7. Cleanup (instant teardown)
```

---

## 🎤 Presentation Script (Key Talking Points)

### Opening
> "Today I'll demonstrate how we can run **real AWS services** on our local machine — DynamoDB, S3, Lambda, and API Gateway — **without any AWS account or cloud costs**."

### During Setup
> "LocalStack emulates AWS services locally. Notice we're using the **real AWS CLI** — same commands you'd use in production, but pointing to our local emulator."

### When Showing DynamoDB
> "This is **real DynamoDB data structure** — see the type annotations? This is exactly how AWS stores data. We're seeing authentic AWS behavior, locally."

### When Showing Integration
> "Watch this: API Gateway routes to Lambda, which writes to DynamoDB and reads from S3. **Complete AWS serverless architecture** — running on my laptop."

### Closing
> "This demonstrates the power of **AWS emulation on bare-metal** — full AWS compatibility, zero cloud costs, perfect for development, testing, and training."

---

## 🎬 Demo Checklist

- [ ] Python environment set up (venv or awslocal installed)
- [ ] LocalStack running and healthy
- [ ] DynamoDB table created (show structure)
- [ ] S3 bucket created (show contents)
- [ ] Lambda function deployed
- [ ] API Gateway configured
- [ ] API creates item in DynamoDB
- [ ] DynamoDB data shown (AWS format)
- [ ] S3 file download works
- [ ] Multiple AWS services shown together
- [ ] Cleanup demonstrated

---

## 💡 Pro Tips for Demo

1. **Use Two Terminals:**
   - Terminal 1: Run commands
   - Terminal 2: Show `./scripts/show_dynamodb_table.sh` to watch data change

2. **Highlight AWS Emulation:**
   - Always mention "This is the real AWS API"
   - Show AWS CLI commands explicitly
   - Point out AWS data structures

3. **Emphasize Cost Savings:**
   - Mention "$0 AWS cost" multiple times
   - Compare to real AWS pricing if relevant

4. **Show Real-Time Changes:**
   - Add items via API
   - Immediately show DynamoDB table
   - Demonstrate the integration

5. **Cleanup is Important:**
   - Shows instant teardown
   - Emphasizes "no data left in cloud"
   - Demonstrates reproducibility

---

## 🎉 Demo Conclusion

**Key Takeaways:**
- ✅ AWS services can run locally (DynamoDB, S3, Lambda, API Gateway)
- ✅ Real AWS APIs and CLI commands work
- ✅ Zero cloud costs for development/testing
- ✅ Production-like behavior for training and demos
- ✅ Perfect for FinOps — eliminate dev/test AWS spending

**Next Steps:**
- Extend to more AWS services (SQS, SNS, etc.)
- Integrate with CI/CD pipelines
- Use for team training and workshops

---

> **"If the cloud is expensive, emulate it.  
> If innovation is the goal, democratize it."** 🌩️

