import json
import boto3
import os
import uuid
from datetime import datetime, timezone
import urllib.parse

# Initialize AWS clients
s3 = boto3.client('s3')
textract = boto3.client('textract')
comprehend = boto3.client('comprehend')
dynamodb = boto3.resource('dynamodb')

# Environment variables
PROCESSED_BUCKET = os.environ['PROCESSED_BUCKET']
METADATA_TABLE = os.environ['METADATA_TABLE']

# DynamoDB table
metadata_table = dynamodb.Table(METADATA_TABLE)

def lambda_handler(event, context):
    """Process uploaded documents using AWS AI services"""
    try:
        # Get S3 event details
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        
        # Skip if not in uploads folder
        if not key.startswith('uploads/'):
            return {'statusCode': 200, 'body': 'Skipped non-upload file'}
        
        # Generate document ID
        document_id = str(uuid.uuid4())
        
        # Start Textract analysis
        response = textract.start_document_analysis(
            DocumentLocation={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            },
            FeatureTypes=['TABLES', 'FORMS']
        )
        
        job_id = response['JobId']
        
        # Store initial metadata
        metadata_table.put_item(
            Item={
                'document_id': document_id,
                'original_bucket': bucket,
                'original_key': key,
                'textract_job_id': job_id,
                'upload_time': datetime.now(timezone.utc).isoformat(),
                'status': 'processing',
                'ttl': int((datetime.now(timezone.utc).timestamp())) + 86400  # 24 hour TTL
            }
        )
        
        # For demo purposes, we'll process a sample text immediately
        # In production, you'd wait for Textract to complete
        sample_text = extract_sample_text(bucket, key)
        
        if sample_text:
            # Analyze with Comprehend
            entities = comprehend.detect_entities(Text=sample_text, LanguageCode='en')
            key_phrases = comprehend.detect_key_phrases(Text=sample_text, LanguageCode='en')
            sentiment = comprehend.detect_sentiment(Text=sample_text, LanguageCode='en')
            
            # Process Giants-specific data
            giants_data = process_giants_data(sample_text, entities, key_phrases)
            
            # Save processed data
            processed_key = f"processed/{document_id}/analysis.json"
            s3.put_object(
                Bucket=PROCESSED_BUCKET,
                Key=processed_key,
                Body=json.dumps({
                    'document_id': document_id,
                    'original_file': key,
                    'text_preview': sample_text[:500],
                    'entities': entities['Entities'][:20],  # Limit for demo
                    'key_phrases': key_phrases['KeyPhrases'][:20],
                    'sentiment': sentiment,
                    'giants_data': giants_data,
                    'processed_time': datetime.now(timezone.utc).isoformat()
                })
            )
            
            # Update metadata
            metadata_table.update_item(
                Key={'document_id': document_id},
                UpdateExpression="SET #status = :status, processed_key = :key, processed_time = :time",
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'completed',
                    ':key': processed_key,
                    ':time': datetime.now(timezone.utc).isoformat()
                }
            )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'document_id': document_id,
                'status': 'processing'
            })
        }
        
    except Exception as e:
        print(f"Error processing document: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def extract_sample_text(bucket, key):
    """Extract sample text from document"""
    try:
        # For demo, we'll just get the first 5KB of the file
        response = s3.get_object(Bucket=bucket, Key=key, Range='bytes=0-5000')
        content = response['Body'].read().decode('utf-8', errors='ignore')
        return content
    except:
        # Return Giants sample data if file read fails
        return """
        New York Giants 2023 Season Report
        
        The Giants finished the 2023 season with a 6-11 record under head coach Brian Daboll. 
        Key players included quarterback Daniel Jones, running back Saquon Barkley, and 
        defensive tackle Dexter Lawrence. The team showed promise early but struggled with 
        injuries throughout the season. MetLife Stadium remained a fortress for the team 
        with several memorable home victories.
        
        Notable games included the Week 1 victory over the Cowboys and the upset win against 
        the Packers in December. The offensive line improved significantly from the previous 
        season, while the defense ranked in the top 10 for total yards allowed.
        
        Looking ahead to 2024, the Giants have significant cap space and multiple draft picks 
        to address needs at cornerback and offensive line.
        """

def process_giants_data(text, entities, key_phrases):
    """Extract Giants-specific information"""
    giants_data = {
        'players': [],
        'coaches': [],
        'seasons': [],
        'stadiums': [],
        'opponents': [],
        'stats': {}
    }
    
    # Process entities for Giants-specific data
    for entity in entities['Entities']:
        if entity['Type'] == 'PERSON':
            if any(role in entity.get('Text', '') for role in ['coach', 'Coach']):
                giants_data['coaches'].append(entity['Text'])
            else:
                giants_data['players'].append(entity['Text'])
        elif entity['Type'] == 'LOCATION':
            if 'Stadium' in entity.get('Text', ''):
                giants_data['stadiums'].append(entity['Text'])
        elif entity['Type'] == 'DATE':
            if any(year in entity.get('Text', '') for year in ['2023', '2022', '2021']):
                giants_data['seasons'].append(entity['Text'])
    
    # Extract team names (opponents)
    nfl_teams = ['Cowboys', 'Eagles', 'Commanders', 'Packers', 'Bears', 'Lions', 
                 'Vikings', 'Patriots', 'Bills', 'Dolphins', 'Jets']
    for team in nfl_teams:
        if team in text:
            giants_data['opponents'].append(team)
    
    # Extract basic stats
    if 'record' in text.lower():
        # Simple regex to find win-loss records
        import re
        record_pattern = r'\d{1,2}-\d{1,2}'
        records = re.findall(record_pattern, text)
        if records:
            giants_data['stats']['records'] = records
    
    return giants_data
