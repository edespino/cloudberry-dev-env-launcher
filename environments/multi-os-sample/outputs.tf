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