# Essential Connection Information
output "instance_public_ips" {
  description = "Public IP addresses for SSH access"
  value       = aws_instance.database_instances[*].public_ip
}

output "instance_hostnames" {
  description = "Instance hostnames for cluster configuration"
  value       = local.hostnames
}

output "ssh_private_key_path" {
  description = "Path to SSH private key file"
  value       = "${var.env_prefix}_generated_key.pem"
}

# Infrastructure IDs (for integration/debugging)
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.database_instances[*].id
}

# Monitoring (if enabled)
output "monitoring_summary" {
  description = "Monitoring status and configuration"
  value = var.enable_monitoring ? {
    alert_email         = var.alert_email
    instances_monitored = length(aws_instance.database_instances)
    sns_topic_arn       = aws_sns_topic.cpu_alerts[0].arn
    } : {
    monitoring_enabled = false
    message            = "Monitoring disabled. Set enable_monitoring=true to enable."
  }
}