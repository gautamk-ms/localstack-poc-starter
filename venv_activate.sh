#!/usr/bin/env bash
# venv_activate.sh
# Activate the virtual environment and set up awslocal
# Usage: source venv_activate.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

if [ ! -d "${VENV_DIR}" ]; then
    echo "❌ Virtual environment not found. Creating it..."
    python3 -m venv "${VENV_DIR}"
    source "${VENV_DIR}/bin/activate"
    pip install --upgrade pip
    pip install awscli-local
    echo "✅ Virtual environment created and awslocal installed!"
else
    source "${VENV_DIR}/bin/activate"
    echo "✅ Virtual environment activated!"
fi

# Use the helper script for awslocal (works better with paths containing spaces)
# The real awslocal is installed in venv, but we use the wrapper for convenience
if [ -f "${SCRIPT_DIR}/utils/aws_cli_alias.sh" ]; then
    source "${SCRIPT_DIR}/utils/aws_cli_alias.sh"
    echo "✅ AWS CLI helpers loaded (using wrapper for awslocal)"
else
    # Fallback: try to use venv's awslocal directly
    if [ -f "${VENV_DIR}/bin/awslocal" ]; then
        export PATH="${VENV_DIR}/bin:${PATH}"
        echo "✅ awslocal available from venv"
    fi
fi

