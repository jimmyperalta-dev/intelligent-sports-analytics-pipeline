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
