#!/usr/bin/env bash
# awslocal_wrapper.sh
# Wrapper script that mimics awslocal behavior using aws CLI
# Usage: source this file or add to your .bashrc/.zshrc

# Check if awslocal is already installed
if command -v awslocal &> /dev/null; then
    # Use real awslocal if available
    awslocal() {
        command awslocal "$@"
    }
else
    # Fallback to aws CLI with LocalStack endpoint
    awslocal() {
        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
        aws --endpoint-url=http://localhost:4566 "$@"
    }
fi

