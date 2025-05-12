# terraform.tfvars - Environment-specific variable values

aws_region     = "us-east-1"
environment    = "dev"
project_name   = "giants-analytics"

# Adjust these based on your needs
lambda_timeout = 300
lambda_memory  = 512

# API Gateway configuration
api_gateway_stage_name = "v1"

# Logging configuration
log_retention_days     = 7
enable_xray_tracing    = true
enable_api_gateway_logs = true

# Custom tags
tags = {
  Application = "NY Giants Document Analysis"
  Team        = "DevOps"
  Owner       = "Jimmy Peralta"
  Website     = "deployjimmy.com"
}
