#!/bin/bash

# Create layer directory structure
mkdir -p python/lib/python3.11/site-packages

# Create requirements.txt
cat > requirements.txt << EOF
boto3==1.34.0
botocore==1.34.0
python-dateutil==2.8.2
urllib3==2.0.7
EOF

# Install dependencies
pip install -r requirements.txt -t python/lib/python3.11/site-packages/

# Create the layer zip
zip -r lambda-layer.zip python/

# Cleanup
rm -rf python/
rm requirements.txt

echo "Lambda layer created: lambda-layer.zip"
