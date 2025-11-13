# utils/aws_cli_alias.sh
# Helper script to simplify AWS CLI commands against LocalStack
# Usage:
#   source utils/aws_cli_alias.sh
#   awsls dynamodb list-tables
#
# This alias ensures all commands automatically target LocalStack (port 4566).

# Default endpoint
export AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-http://localhost:4566}
export AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}

# Define shortcut alias for AWS CLI against LocalStack
alias awsls="aws --endpoint-url=${AWS_ENDPOINT_URL} --region=${AWS_REGION}"

echo "✅ LocalStack AWS CLI alias loaded. Example usage:"
echo "   awsls dynamodb list-tables"
echo "   awsls ecr describe-repositories"