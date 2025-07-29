# Copy monitoring resources from existing monitoring.tf
# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "cpu_alerts" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${var.env_prefix}-cpu-alerts"

  tags = merge(local.common_tags, {
    Name    = "${var.env_prefix}-cpu-alerts"
    Purpose = "Drata Compliance - CPU Monitoring"
  })
}

# Alternative: Automated SQS subscription for processing
resource "aws_sqs_queue" "alert_queue" {
  count                      = var.enable_monitoring ? 1 : 0
  name                       = "${var.env_prefix}-alert-queue"
  visibility_timeout_seconds = 90 # Must be >= Lambda timeout (60s) + buffer

  tags = merge(local.common_tags, {
    Name    = "${var.env_prefix}-alert-queue"
    Purpose = "Drata Compliance - Alert Processing"
  })
}

resource "aws_sns_topic_subscription" "cpu_alerts_sqs" {
  count     = var.enable_monitoring ? 1 : 0
  topic_arn = aws_sns_topic.cpu_alerts[0].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.alert_queue[0].arn
}

# SQS queue policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "alert_queue_policy" {
  count     = var.enable_monitoring ? 1 : 0
  queue_url = aws_sqs_queue.alert_queue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.alert_queue[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_sns_topic.cpu_alerts[0].arn
          }
        }
      }
    ]
  })
}

# CPU Warning Alarms (75%)
resource "aws_cloudwatch_metric_alarm" "high_cpu_warning" {
  count = var.enable_monitoring ? var.vm_count : 0

  alarm_name          = "${var.env_prefix}-instance-${count.index}-cpu-warning-75"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2" # 2 consecutive periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300" # 5 minutes
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors ec2 cpu utilization (Warning: >75%)"
  alarm_actions       = [aws_sns_topic.cpu_alerts[0].arn]
  ok_actions          = [aws_sns_topic.cpu_alerts[0].arn]
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.database_instances[count.index].id
  }

  tags = merge(local.common_tags, {
    Name       = "${var.env_prefix}-instance-${count.index}-cpu-warning"
    Severity   = "Warning"
    Threshold  = "75"
    Instance   = aws_instance.database_instances[count.index].tags.Name
    Compliance = "Drata"
  })
}

# CPU Critical Alarms (90%)
resource "aws_cloudwatch_metric_alarm" "high_cpu_critical" {
  count = var.enable_monitoring ? var.vm_count : 0

  alarm_name          = "${var.env_prefix}-instance-${count.index}-cpu-critical-90"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2" # 2 consecutive periods  
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300" # 5 minutes
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors ec2 cpu utilization (Critical: >90%)"
  alarm_actions       = [aws_sns_topic.cpu_alerts[0].arn]
  ok_actions          = [aws_sns_topic.cpu_alerts[0].arn]
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.database_instances[count.index].id
  }

  tags = merge(local.common_tags, {
    Name       = "${var.env_prefix}-instance-${count.index}-cpu-critical"
    Severity   = "Critical"
    Threshold  = "90"
    Instance   = aws_instance.database_instances[count.index].tags.Name
    Compliance = "Drata"
  })
}

# Instance Status Check Alarms
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  count = var.enable_monitoring ? var.vm_count : 0

  alarm_name          = "${var.env_prefix}-instance-${count.index}-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors ec2 instance status check"
  alarm_actions       = [aws_sns_topic.cpu_alerts[0].arn]
  ok_actions          = [aws_sns_topic.cpu_alerts[0].arn]
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.database_instances[count.index].id
  }

  tags = merge(local.common_tags, {
    Name       = "${var.env_prefix}-instance-${count.index}-status-check"
    Type       = "StatusCheck"
    Instance   = aws_instance.database_instances[count.index].tags.Name
    Compliance = "Drata"
  })
}

# System Status Check Alarms
resource "aws_cloudwatch_metric_alarm" "system_status_check" {
  count = var.enable_monitoring ? var.vm_count : 0

  alarm_name          = "${var.env_prefix}-instance-${count.index}-system-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors ec2 system status check"
  alarm_actions       = [aws_sns_topic.cpu_alerts[0].arn]
  ok_actions          = [aws_sns_topic.cpu_alerts[0].arn]
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.database_instances[count.index].id
  }

  tags = merge(local.common_tags, {
    Name       = "${var.env_prefix}-instance-${count.index}-system-status-check"
    Type       = "SystemStatusCheck"
    Instance   = aws_instance.database_instances[count.index].tags.Name
    Compliance = "Drata"
  })
}

# Lambda function for processing alerts
resource "aws_lambda_function" "alert_processor" {
  count = var.enable_monitoring ? 1 : 0

  filename         = "alert_processor.zip"
  function_name    = "${var.env_prefix}-alert-processor"
  role             = aws_iam_role.lambda_exec[0].arn
  handler          = "alert_processor.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 60

  environment {
    variables = {
      ALERT_EMAIL = var.alert_email
      ENV_PREFIX  = var.env_prefix
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${var.env_prefix}-alert-processor"
    Purpose = "Drata Compliance - Alert Processing"
  })
}

# Lambda execution role
resource "aws_iam_role" "lambda_exec" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${var.env_prefix}-lambda-exec"

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

  tags = local.common_tags
}

# Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.enable_monitoring ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec[0].name
}

# Additional policy for SES sending
resource "aws_iam_role_policy" "lambda_ses" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${var.env_prefix}-lambda-ses"
  role  = aws_iam_role.lambda_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.alert_queue[0].arn
      }
    ]
  })
}

# Event source mapping for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count            = var.enable_monitoring ? 1 : 0
  event_source_arn = aws_sqs_queue.alert_queue[0].arn
  function_name    = aws_lambda_function.alert_processor[0].arn
  batch_size       = 10
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  count       = var.enable_monitoring ? 1 : 0
  type        = "zip"
  output_path = "alert_processor.zip"

  source {
    content  = file("${path.module}/files/alert_processor.py")
    filename = "alert_processor.py"
  }
}

# Cleanup zip file on destroy
resource "null_resource" "cleanup_lambda_zip" {
  count = var.enable_monitoring ? 1 : 0

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f alert_processor.zip"
  }

  triggers = {
    zip_path = "alert_processor.zip"
  }

  depends_on = [data.archive_file.lambda_zip]
}