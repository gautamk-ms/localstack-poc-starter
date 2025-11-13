# utils/aws_cli_alias.sh
# Helper script to simplify AWS CLI commands against LocalStack
# Usage:
#   source utils/aws_cli_alias.sh
#   awslocal dynamodb list-tables
#   awsls dynamodb list-tables
#
# This script provides both 'awslocal' function and 'awsls' alias for LocalStack.

# Default endpoint
export AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-http://localhost:4566}
export AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}

# Check if awslocal is already a function (from previous sourcing)
# Use 'whence -w' for zsh compatibility, fallback to 'type -t' for bash
if command -v whence &> /dev/null; then
    AWSLOCAL_TYPE=$(whence -w awslocal 2>/dev/null | cut -d: -f2 | xargs)
else
    AWSLOCAL_TYPE=$(type -t awslocal 2>/dev/null || echo "")
fi

if [ "$AWSLOCAL_TYPE" = "function" ]; then
    # Already defined as function, skip
    :
# Check if real awslocal command is installed and works
elif command -v awslocal &> /dev/null 2>&1 && awslocal --version &> /dev/null 2>&1; then
    # Use real awslocal if available and working
    echo "✅ Using installed awslocal command"
else
    # Create awslocal function as wrapper (handles paths with spaces better)
    awslocal() {
        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
        aws --endpoint-url=${AWS_ENDPOINT_URL} --region=${AWS_REGION} "$@"
    }
    echo "✅ Created awslocal function (using aws CLI wrapper - handles paths with spaces)"
fi

# Define shortcut alias for AWS CLI against LocalStack
alias awsls="aws --endpoint-url=${AWS_ENDPOINT_URL} --region=${AWS_REGION}"

echo "✅ LocalStack AWS CLI helpers loaded. Example usage:"
echo "   awslocal dynamodb list-tables"
echo "   awslocal s3 ls"
echo "   awsls ecr describe-repositories"