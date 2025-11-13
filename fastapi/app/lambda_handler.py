# fastapi/app/lambda_handler.py
# Lambda handler for FastAPI application using Mangum adapter

from mangum import Mangum
from app.main import app

# Create Mangum handler instance
handler = Mangum(app, lifespan="off")

# Lambda entry point
def lambda_handler(event, context):
    """AWS Lambda handler entry point."""
    return handler(event, context)

