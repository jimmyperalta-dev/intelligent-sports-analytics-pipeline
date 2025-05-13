#!/bin/bash

echo "Starting Lambda layer build..."

# Exit on any error
set -e

# Try different pip commands
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v python3 -m pip &> /dev/null; then
    PIP_CMD="python3 -m pip"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo "ERROR: No pip command found. Please install pip."
    exit 1
fi

echo "Using pip command: $PIP_CMD"

# Clean up any existing files
echo "Cleaning up old files..."
rm -rf python lambda-layer.zip requirements.txt

# Create the directory structure
echo "Creating directory structure..."
mkdir -p python/lib/python3.11/site-packages

# Create requirements file
echo "Creating requirements.txt..."
cat > requirements.txt << 'EOF'
boto3==1.34.0
botocore==1.34.0
EOF

# Install packages
echo "Installing packages..."
$PIP_CMD install -r requirements.txt -t python/lib/python3.11/site-packages/ --quiet

# Check if installation succeeded
if [ ! -d "python/lib/python3.11/site-packages/boto3" ]; then
    echo "ERROR: Package installation failed"
    exit 1
fi

# Create the zip file
echo "Creating lambda-layer.zip..."
zip -r9 lambda-layer.zip python/

# Verify the zip file
if [ ! -f lambda-layer.zip ]; then
    echo "ERROR: Failed to create lambda-layer.zip"
    exit 1
fi

# Check file size on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZIP_SIZE=$(stat -f%z lambda-layer.zip)
else
    ZIP_SIZE=$(stat -c%s lambda-layer.zip 2>/dev/null || stat -f%z lambda-layer.zip)
fi

if [ "$ZIP_SIZE" -lt 1000 ]; then
    echo "ERROR: lambda-layer.zip is too small (${ZIP_SIZE} bytes)"
    exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf python requirements.txt

echo "Lambda layer created successfully!"
echo "File: lambda-layer.zip ($(ls -lh lambda-layer.zip | awk '{print $5}'))"
