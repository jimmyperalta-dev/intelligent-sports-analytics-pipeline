import json
import boto3
import os
import base64
from datetime import datetime, timezone
import uuid

# Initialize AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
DOCUMENTS_BUCKET = os.environ['DOCUMENTS_BUCKET']
PROCESSED_BUCKET = os.environ['PROCESSED_BUCKET']
METADATA_TABLE = os.environ['METADATA_TABLE']

# DynamoDB table
metadata_table = dynamodb.Table(METADATA_TABLE)

def lambda_handler(event, context):
    """Handle API requests"""
    try:
        path = event['resource']
        method = event['httpMethod']
        
        # CORS headers
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        }
        
        # Handle different endpoints
        if path == '/documents/upload' and method == 'POST':
            return handle_upload(event, headers)
        elif path == '/documents/analyze' and method == 'GET':
            return handle_get_analysis(event, headers)
        elif path == '/search' and method == 'GET':
            return handle_search(event, headers)
        else:
            return {
                'statusCode': 404,
                'headers': headers,
                'body': json.dumps({'error': 'Not found'})
            }
            
    except Exception as e:
        print(f"Error in API handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
            },
            'body': json.dumps({'error': str(e)})
        }

def handle_upload(event, headers):
    """Handle document upload"""
    try:
        body = json.loads(event['body'])
        filename = body.get('filename', 'document.pdf')
        content_type = body.get('contentType', 'application/pdf')
        
        # Generate unique key
        document_id = str(uuid.uuid4())
        key = f"uploads/{document_id}/{filename}"
        
        # Create presigned URL for upload
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': DOCUMENTS_BUCKET,
                'Key': key,
                'ContentType': content_type
            },
            ExpiresIn=3600
        )
        
        # Store initial metadata
        metadata_table.put_item(
            Item={
                'document_id': document_id,
                'filename': filename,
                'upload_status': 'pending',
                'created_at': datetime.now(timezone.utc).isoformat(),
                'ttl': int((datetime.now(timezone.utc).timestamp())) + 86400
            }
        )
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'documentId': document_id,
                'uploadUrl': presigned_url,
                'key': key
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_get_analysis(event, headers):
    """Get document analysis results"""
    try:
        # Get document ID from query parameters
        document_id = event['queryStringParameters'].get('documentId')
        
        if not document_id:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'documentId parameter required'})
            }
        
        # Get metadata from DynamoDB
        response = metadata_table.get_item(Key={'document_id': document_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': headers,
                'body': json.dumps({'error': 'Document not found'})
            }
        
        metadata = response['Item']
        
        # If document is processed, get the analysis
        if metadata.get('status') == 'completed' and metadata.get('processed_key'):
            try:
                analysis_response = s3.get_object(
                    Bucket=PROCESSED_BUCKET,
                    Key=metadata['processed_key']
                )
                analysis = json.loads(analysis_response['Body'].read())
                
                return {
                    'statusCode': 200,
                    'headers': headers,
                    'body': json.dumps({
                        'documentId': document_id,
                        'status': metadata.get('status', 'unknown'),
                        'analysis': analysis
                    })
                }
            except:
                pass
        
        # Return metadata only if not processed
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'documentId': document_id,
                'status': metadata.get('status', 'processing'),
                'metadata': metadata
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }

def handle_search(event, headers):
    """Search documents"""
    try:
        query_params = event.get('queryStringParameters', {})
        search_query = query_params.get('q', '')
        search_type = query_params.get('type', 'all')
        
        # For demo purposes, we'll return sample Giants data
        sample_results = get_sample_giants_results(search_query, search_type)
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'query': search_query,
                'type': search_type,
                'results': sample_results,
                'totalResults': len(sample_results)
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }

def get_sample_giants_results(query, search_type):
    """Return sample Giants search results"""
    # Sample Giants data for demo
    all_results = [
        {
            'documentId': 'sample-001',
            'title': 'NY Giants 2023 Season Review',
            'type': 'season_report',
            'excerpt': 'The Giants finished the 2023 season with a 6-11 record under head coach Brian Daboll...',
            'date': '2024-01-15',
            'relevance': 0.95
        },
        {
            'documentId': 'sample-002',
            'title': 'Saquon Barkley Career Statistics',
            'type': 'player_stats',
            'excerpt': 'Running back Saquon Barkley has accumulated over 5,000 rushing yards...',
            'date': '2024-02-20',
            'relevance': 0.88
        },
        {
            'documentId': 'sample-003',
            'title': 'Giants Draft Analysis 2024',
            'type': 'draft_report',
            'excerpt': 'The Giants selected LSU wide receiver Malik Nabers with the 6th overall pick...',
            'date': '2024-04-26',
            'relevance': 0.92
        },
        {
            'documentId': 'sample-004',
            'title': 'MetLife Stadium Attendance Report',
            'type': 'stadium_report',
            'excerpt': 'Average attendance at MetLife Stadium for Giants games was 78,204...',
            'date': '2024-01-30',
            'relevance': 0.75
        },
        {
            'documentId': 'sample-005',
            'title': 'Daniel Jones Contract Extension Details',
            'type': 'contract_news',
            'excerpt': 'Quarterback Daniel Jones signed a 4-year, $160 million extension...',
            'date': '2023-03-07',
            'relevance': 0.83
        }
    ]
    
    # Filter by type if specified
    if search_type != 'all':
        all_results = [r for r in all_results if r['type'] == search_type]
    
    # Simple query matching (case-insensitive)
    if query:
        query_lower = query.lower()
        filtered_results = []
        for result in all_results:
            if (query_lower in result['title'].lower() or 
                query_lower in result['excerpt'].lower()):
                filtered_results.append(result)
        return filtered_results
    
    return all_results
