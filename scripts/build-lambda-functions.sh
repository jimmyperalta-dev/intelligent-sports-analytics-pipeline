#!/bin/bash

echo "Starting Lambda functions build..."

# Exit on any error
set -e

# Check if the lambda_functions directory exists
if [ ! -d "lambda_functions" ]; then
    echo "ERROR: lambda_functions directory not found"
    echo "Current directory: $(pwd)"
    echo "Contents: $(ls -la)"
    exit 1
fi

# Check if there are Python files
PYTHON_FILES=$(find lambda_functions -name "*.py" | wc -l)
if [ "$PYTHON_FILES" -eq 0 ]; then
    echo "ERROR: No Python files found in lambda_functions directory"
    exit 1
fi

# Clean up old zip file
echo "Cleaning up old files..."
rm -f lambda-functions.zip

# Create the zip file
echo "Creating lambda-functions.zip..."
cd lambda_functions
zip -r9 ../lambda-functions.zip *.py
cd ..

# Verify the zip file
if [ ! -f lambda-functions.zip ]; then
    echo "ERROR: Failed to create lambda-functions.zip"
    exit 1
fi

# Check file size on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZIP_SIZE=$(stat -f%z lambda-functions.zip)
else
    ZIP_SIZE=$(stat -c%s lambda-functions.zip 2>/dev/null || stat -f%z lambda-functions.zip)
fi

if [ "$ZIP_SIZE" -lt 100 ]; then
    echo "ERROR: lambda-functions.zip is too small (${ZIP_SIZE} bytes)"
    exit 1
fi

echo "Lambda functions packaged successfully!"
echo "File: lambda-functions.zip ($(ls -lh lambda-functions.zip | awk '{print $5}'))"
echo "Contents:"
unzip -l lambda-functions.zip
