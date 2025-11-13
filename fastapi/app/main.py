# fastapi/app/main.py
# FastAPI microservice for Inventory Management
# Works with DynamoDB (via LocalStack) and exposes REST APIs:
#   POST /inventory  -> Add item
#   GET /inventory/{sku} -> Fetch item
#   GET / -> Health check

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import boto3
import os
from botocore.config import Config
from botocore.exceptions import ClientError

app = FastAPI(title="FastAPI Inventory Service (ECS LocalStack POC)")

# ---------- Models ----------
class Item(BaseModel):
    sku: str
    name: str
    qty: int

# ---------- AWS Config ----------
REGION = os.getenv("AWS_REGION", "us-east-1")
ENDPOINT = os.getenv("AWS_ENDPOINT_URL", "http://localstack:4566")
TABLE_NAME = os.getenv("TABLE_NAME", "Inventory")

# Initialize DynamoDB client
dynamodb = boto3.resource(
    "dynamodb",
    region_name=REGION,
    endpoint_url=ENDPOINT,
    config=Config(signature_version="s3v4")  # short signatures for localstack
)
table = dynamodb.Table(TABLE_NAME)

# ---------- Routes ----------

@app.get("/")
async def root():
    return {"message": "FastAPI Inventory Service running on ECS (LocalStack)"}


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