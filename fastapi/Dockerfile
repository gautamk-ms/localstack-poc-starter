# fastapi/Dockerfile
# Dockerfile for FastAPI microservice that interacts with DynamoDB via LocalStack (AWS emulator)

FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Copy dependency file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy FastAPI application code
COPY app ./app

# Expose FastAPI default port
EXPOSE 8000

# Start FastAPI using uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]