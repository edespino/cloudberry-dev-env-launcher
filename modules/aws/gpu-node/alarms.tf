# CPU alarm for the node, published to an existing SNS topic in the account.
# The topic is looked up by name, so its ARN follows the provider's region and
# account. Off when cpu_alarm_topic_name is empty; a name with no matching
# topic fails the plan instead of creating an alarm that notifies nobody.

data "aws_sns_topic" "cpu_alarm" {
  count = var.cpu_alarm_topic_name != "" ? 1 : 0
  name  = var.cpu_alarm_topic_name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.cpu_alarm_topic_name != "" ? 1 : 0

  alarm_name          = "${local.name}-cpu-high"
  alarm_description   = "Average CPU above 90% for 15 minutes on ${local.name}"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 90
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.cpu_alarm[0].arn]

  dimensions = {
    InstanceId = aws_instance.this.id
  }

  tags = local.common_tags
}
