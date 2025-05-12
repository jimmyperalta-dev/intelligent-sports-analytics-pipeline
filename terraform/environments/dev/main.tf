# main.tf - Main Terraform configuration for intelligent sports analytics pipeline

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.74"  # Latest as of November 2024
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  
  # Optional: Configure backend for state storage
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "intelligent-sports-analytics/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "intelligent-sports-analytics"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Jimmy Peralta"
      CreatedDate = timestamp()
    }
  }
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket for document storage
resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-documents-${random_id.suffix.hex}"
}

# S3 bucket for processed data
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${random_id.suffix.hex}"
}

# Block public access for documents bucket
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access for processed bucket
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on documents bucket
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for metadata
resource "aws_dynamodb_table" "document_metadata" {
  name           = "${var.project_name}-metadata-${random_id.suffix.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "document_id"
  
  attribute {
    name = "document_id"
    type = "S"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
}
# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda to access S3, DynamoDB, and AI services
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*",
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.document_metadata.arn
      },
      {
        Effect = "Allow"
        Action = [
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectEntities",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectSentiment",
          "comprehend:DetectDominantLanguage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda layer for shared dependencies
resource "aws_lambda_layer_version" "dependencies" {
  filename   = "../../scripts/lambda-layer.zip"
  layer_name = "${var.project_name}-dependencies"

  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  
  depends_on = [null_resource.build_lambda_layer]
}

# Build Lambda layer
resource "null_resource" "build_lambda_layer" {
  triggers = {
    build_script = filemd5("../../scripts/build-lambda-layer.sh")
  }

  provisioner "local-exec" {
    command = "cd ../../scripts && ./build-lambda-layer.sh"
  }
}

# Lambda function for document processing
resource "aws_lambda_function" "document_processor" {
  filename         = "../../scripts/lambda-functions.zip"
  function_name    = "${var.project_name}-processor-${random_id.suffix.hex}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "document_processor.lambda_handler"
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.id
      METADATA_TABLE   = aws_dynamodb_table.document_metadata.name
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  depends_on = [null_resource.build_lambda_functions]
}

# Build Lambda functions
resource "null_resource" "build_lambda_functions" {
  triggers = {
    build_script = filemd5("../../scripts/build-lambda-functions.sh")
  }

  provisioner "local-exec" {
    command = "cd ../../scripts && ./build-lambda-functions.sh"
  }
}

# Lambda function for API handler
resource "aws_lambda_function" "api_handler" {
  filename         = "../../scripts/lambda-functions.zip"
  function_name    = "${var.project_name}-api-${random_id.suffix.hex}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "api_handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DOCUMENTS_BUCKET = aws_s3_bucket.documents.id
      PROCESSED_BUCKET = aws_s3_bucket.processed.id
      METADATA_TABLE   = aws_dynamodb_table.document_metadata.name
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]
}

# S3 bucket notification for document processing
resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.document_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents.arn
}

# CloudWatch log groups
resource "aws_cloudwatch_log_group" "document_processor" {
  name              = "/aws/lambda/${aws_lambda_function.document_processor.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "api_handler" {
  name              = "/aws/lambda/${aws_lambda_function.api_handler.function_name}"
  retention_in_days = var.log_retention_days
}
# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api-${random_id.suffix.hex}"
  description = "API for sports document analysis"

  endpoint_configuration {
    types = ["EDGE"]
  }

  binary_media_types = ["*/*"]
}

# API Gateway resources
resource "aws_api_gateway_resource" "documents" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.documents.id
  path_part   = "upload"
}

resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.documents.id
  path_part   = "analyze"
}

resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "search"
}

# Upload document method
resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_post" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# Get document analysis method
resource "aws_api_gateway_method" "analyze_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.documentId" = true
  }
}

resource "aws_api_gateway_integration" "analyze_get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.analyze_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# Search documents method
resource "aws_api_gateway_method" "search_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.q" = false
    "method.request.querystring.type" = false
  }
}

resource "aws_api_gateway_integration" "search_get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_gateway_stage_name

  depends_on = [
    aws_api_gateway_integration.upload_post,
    aws_api_gateway_integration.analyze_get,
    aws_api_gateway_integration.search_get
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# API Gateway stage
resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.api_gateway_stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      requestTimeEpoch = "$context.requestTimeEpoch"
      path           = "$context.path"
      method         = "$context.httpMethod"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray_tracing

  depends_on = [aws_cloudwatch_log_group.api_gateway]
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${random_id.suffix.hex}"
  retention_in_days = var.log_retention_days
}

# CORS configuration for API Gateway
resource "aws_api_gateway_method" "cors_upload" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.cors_upload.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "cors_upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.cors_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "cors_upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.cors_upload.http_method
  status_code = aws_api_gateway_method_response.cors_upload.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
