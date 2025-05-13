# Technical Evidence - NY Giants Analytics Platform

This document provides technical evidence of the deployed infrastructure and services for the NY Giants Analytics Platform.

## AWS Infrastructure Overview

### Lambda Functions
![Lambda Functions](evidence/aws-lambda-functions.png)
- Document processor function for AI analysis
- API handler function for REST endpoints
- Both running Python 3.11 runtime

### API Gateway
![API Gateway](evidence/aws-api-gateway.png)
- RESTful API with three main endpoints
- Proper resource structure for document management
- Stage v1 deployed and active

### DynamoDB Database
![DynamoDB Table](evidence/aws-dynamodb-table.png)
- On-demand billing for cost optimization
- Metadata storage for document processing
- Point-in-time recovery enabled

### S3 Storage
![S3 Buckets](evidence/aws-s3-buckets.png)
- Three purpose-specific buckets:
  - Documents bucket for uploads
  - Processed bucket for AI analysis results
  - Website bucket for static hosting

### CloudWatch Monitoring
![CloudWatch Logs](evidence/aws-cloudwatch-logs.png)
- Log groups for all services
- Configured retention policies
- Ready for production monitoring

### CloudFront CDN
![CloudFront Distribution](evidence/aws-cloudfront-distribution.png)
- Global content delivery
- HTTPS enabled
- Optimized for North America and Europe

## Deployment Details

- **Region**: US East (N. Virginia) us-east-1
- **Deployment Date**: May 12, 2025
- **Infrastructure as Code**: Terraform
- **Free Tier Optimized**: Yes

## AI Services Configuration

The platform is configured to use:
- **Amazon Textract**: Document OCR and text extraction
- **Amazon Comprehend**: Natural language processing for entity detection and sentiment analysis

### AI Services Permissions

![IAM AI Permissions](evidence/aws-iam-ai-permissions.png)
- ** Lambda execution role configured with Textract permissions
- **Comprehend access for natural language processing
- **Proper IAM policies for AI service integration
- **Following AWS best practices for least privilege access

## Security Features

- IAM roles with least privilege access
- S3 bucket policies restricting public access
- HTTPS enforcement through CloudFront
- Secure API Gateway endpoints
