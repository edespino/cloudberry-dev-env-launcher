# Essential outputs for daily use
output "instance_ips" {
  description = "Public IP addresses for SSH access"
  value       = module.database_cluster.instance_public_ips
}

output "hostnames" {
  description = "Instance hostnames"
  value       = module.database_cluster.instance_hostnames
}

output "ssh_key" {
  description = "SSH private key file"
  value       = module.database_cluster.ssh_private_key_path
}

# DBaaS Platform Outputs (conditional)
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].eks_cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].eks_cluster_endpoint : null
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].eks_kubeconfig_command : null
}

output "s3_storage_bucket" {
  description = "S3 bucket for DBaaS storage"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].s3_storage_bucket_id : null
}

output "s3_backup_bucket" {
  description = "S3 bucket for DBaaS backups"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].s3_backup_bucket_id : null
}

output "dbaas_s3_role_arn" {
  description = "ARN of the IAM role for S3 access from EKS"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].dbaas_s3_role_arn : null
}

output "dbaas_platform_summary" {
  description = "Summary of DBaaS platform resources"
  value       = var.deploy_dbaas_services ? module.dbaas_platform[0].dbaas_platform_summary : null
}