# fastapi/Dockerfile
# Dockerfile for FastAPI microservice as Lambda Container Image
# Uses AWS Lambda Python base image with Runtime Interface Client (RIC)

FROM public.ecr.aws/lambda/python:3.10

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy dependency file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy FastAPI application code
COPY app ./app

# Set Lambda handler
CMD ["app.lambda_handler.lambda_handler"]