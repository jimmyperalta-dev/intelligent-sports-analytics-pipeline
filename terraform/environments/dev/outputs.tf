# outputs.tf - Output values for intelligent sports analytics pipeline

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_deployment.api.invoke_url
}

output "document_bucket_name" {
  description = "Name of the S3 bucket for document storage"
  value       = aws_s3_bucket.documents.id
}

output "processed_bucket_name" {
  description = "Name of the S3 bucket for processed data"
  value       = aws_s3_bucket.processed.id
}

output "metadata_table_name" {
  description = "Name of the DynamoDB table for metadata"
  value       = aws_dynamodb_table.document_metadata.name
}

output "document_upload_function_name" {
  description = "Name of the document upload Lambda function"
  value       = aws_lambda_function.document_processor.function_name
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL for the web interface"
  value       = "https://${aws_cloudfront_distribution.web_distribution.domain_name}"
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB metadata table"
  value       = aws_dynamodb_table.document_metadata.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "document_bucket_arn" {
  description = "ARN of the documents S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed.arn
}
