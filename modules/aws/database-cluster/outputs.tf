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

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
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

# EBS Data Volumes (if configured)
output "data_volumes" {
  description = "EBS data volume details"
  value = var.data_drive_count > 0 ? {
    volume_ids           = aws_ebs_volume.data_volume[*].id
    volumes_per_instance = var.data_drive_count
    volume_size          = var.data_drive_size
    volume_type          = var.data_drive_type
    total_volumes        = var.vm_count * var.data_drive_count
    } : {
    volume_ids           = []
    volumes_per_instance = 0
    volume_size          = 0
    volume_type          = "none"
    total_volumes        = 0
  }
}

output "volume_attachments" {
  description = "EBS volume attachment details (device names)"
  value = var.data_drive_count > 0 ? [
    for i in range(var.vm_count * var.data_drive_count) : {
      instance_index = floor(i / var.data_drive_count)
      instance_id    = aws_instance.database_instances[floor(i / var.data_drive_count)].id
      volume_id      = aws_ebs_volume.data_volume[i].id
      device_name    = "/dev/sd${element(["f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"], i % var.data_drive_count)}"
    }
  ] : []
}