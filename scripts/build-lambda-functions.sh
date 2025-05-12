#!/bin/bash

# Clean up previous builds
rm -f lambda-functions.zip

# Create the zip file with all Lambda functions
cd lambda_functions
zip -r ../lambda-functions.zip *.py
cd ..

echo "Lambda functions packaged: lambda-functions.zip"
