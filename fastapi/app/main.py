# fastapi/app/main.py
# FastAPI microservice for Inventory Management
# Works with DynamoDB and S3 (via LocalStack) and exposes REST APIs:
#   POST /inventory  -> Add item
#   GET /inventory/{sku} -> Fetch item
#   DELETE /inventory/{sku} -> Delete item
#   GET /file/download/{filename} -> Download file from S3
#   GET / -> Health check

from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel
import boto3
import os
from botocore.config import Config
from botocore.exceptions import ClientError

app = FastAPI(title="FastAPI Inventory Service (Lambda LocalStack POC)")

# ---------- Models ----------
class Item(BaseModel):
    sku: str
    name: str
    qty: int

# ---------- AWS Config ----------
REGION = os.getenv("AWS_REGION", "us-east-1")
ENDPOINT = os.getenv("AWS_ENDPOINT_URL", "http://localstack:4566")
TABLE_NAME = os.getenv("TABLE_NAME", "ShopInventory")
S3_BUCKET = os.getenv("S3_BUCKET", "poc-data-bucket")

# Initialize DynamoDB client
dynamodb = boto3.resource(
    "dynamodb",
    region_name=REGION,
    endpoint_url=ENDPOINT,
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID", "test"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY", "test"),
    config=Config(signature_version="s3v4")  # short signatures for localstack
)
table = dynamodb.Table(TABLE_NAME)

# Initialize S3 client
s3 = boto3.client(
    "s3",
    region_name=REGION,
    endpoint_url=ENDPOINT,
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID", "test"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY", "test"),
    config=Config(signature_version="s3v4")
)

# ---------- Routes ----------

@app.get("/")
async def root():
    return {"message": "FastAPI Inventory Service running on Lambda (LocalStack)"}


@app.post("/inventory")
async def create_item(item: Item):
    """Add or update an item in DynamoDB table."""
    try:
        table.put_item(Item=item.dict())
        return {"status": "created", "item": item}
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/inventory/{sku}")
async def get_item(sku: str):
    """Fetch an item by SKU."""
    try:
        response = table.get_item(Key={"sku": sku})
        if "Item" not in response:
            raise HTTPException(status_code=404, detail=f"Item with SKU '{sku}' not found")
        return response["Item"]
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/inventory/{sku}")
async def delete_item(sku: str):
    """Delete an item by SKU."""
    try:
        response = table.delete_item(Key={"sku": sku})
        return {"status": "deleted", "sku": sku}
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/file/download/{filename}")
async def download_file(filename: str):
    """Download a file from S3 bucket."""
    try:
        response = s3.get_object(Bucket=S3_BUCKET, Key=filename)
        file_content = response["Body"].read()
        content_type = response.get("ContentType", "application/octet-stream")
        
        return Response(
            content=file_content,
            media_type=content_type,
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "Unknown")
        if error_code == "NoSuchKey":
            raise HTTPException(status_code=404, detail=f"File '{filename}' not found in bucket")
        raise HTTPException(status_code=500, detail=str(e))