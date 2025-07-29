import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    """
    Process CloudWatch alarm notifications from SQS and send formatted emails via SES
    """
    ses_client = boto3.client('ses')
    alert_email = os.environ['ALERT_EMAIL']
    
    for record in event['Records']:
        try:
            # Parse the SNS message from SQS
            message_body = json.loads(record['body'])
            sns_message = json.loads(message_body['Message'])
            
            # Extract alarm details
            alarm_name = sns_message.get('AlarmName', 'Unknown Alarm')
            alarm_description = sns_message.get('AlarmDescription', 'No description')
            new_state = sns_message.get('NewStateValue', 'Unknown')
            old_state = sns_message.get('OldStateValue', 'Unknown')
            reason = sns_message.get('NewStateReason', 'No reason provided')
            timestamp = sns_message.get('StateChangeTime', datetime.utcnow().isoformat())
            
            # Get instance information if available
            trigger = sns_message.get('Trigger', {})
            instance_id = trigger.get('Dimensions', [{}])[0].get('value', 'Unknown')
            metric_name = trigger.get('MetricName', 'Unknown')
            threshold = trigger.get('Threshold', 'Unknown')
            
            # Determine severity and subject
            severity = "CRITICAL" if "critical" in alarm_name.lower() else "WARNING"
            subject = f"[{severity}] {alarm_name} - {new_state}"
            
            # Create formatted email body
            email_body = f"""
Drata Compliance Alert - CloudWatch Alarm Notification

ALARM DETAILS:
- Name: {alarm_name}
- Description: {alarm_description}
- State Change: {old_state} → {new_state}
- Timestamp: {timestamp}
- Severity: {severity}

INSTANCE INFORMATION:
- Instance ID: {instance_id}
- Metric: {metric_name}
- Threshold: {threshold}

REASON:
{reason}

This is an automated alert from the Drata compliance monitoring system.
Environment: {os.environ.get('AWS_LAMBDA_FUNCTION_NAME', '').replace('-alert-processor', '')}

--
Cloudberry Database - Automated Monitoring System
            """.strip()

            # Send email via SES
            response = ses_client.send_email(
                Source=alert_email,  # Must be verified in SES
                Destination={'ToAddresses': [alert_email]},
                Message={
                    'Subject': {'Data': subject},
                    'Body': {'Text': {'Data': email_body}}
                }
            )
            
            print(f"Email sent successfully for alarm: {alarm_name}, MessageId: {response['MessageId']}")
            
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            print(f"Record: {json.dumps(record, indent=2)}")
            # Don't raise exception to avoid message reprocessing
    
    return {'statusCode': 200, 'body': 'Processed successfully'}