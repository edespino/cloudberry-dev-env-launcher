# Parent resources as resolved at plan time (for review)
output "parent_prefix" {
  description = "Parent environment prefix"
  value       = var.parent_prefix
}

output "parent_vpc_id" {
  description = "Parent VPC resolved by tag"
  value       = data.aws_vpc.parent.id
}

output "parent_subnet_id" {
  description = "Parent subnet resolved by tag"
  value       = data.aws_subnet.parent.id
}

output "parent_subnet_az" {
  description = "Availability zone of the parent subnet"
  value       = data.aws_subnet.parent.availability_zone
}

output "parent_security_group_id" {
  description = "Parent security group resolved by tag"
  value       = data.aws_security_group.parent.id
}

output "parent_key_name" {
  description = "Parent key pair name"
  value       = data.aws_key_pair.parent.key_name
}

# GPU node
output "gpu_name" {
  description = "Name tag of the GPU instance"
  value       = module.gpu_node.name
}

output "gpu_instance_id" {
  description = "GPU instance ID"
  value       = module.gpu_node.instance_id
}

output "gpu_private_ip" {
  description = "GPU private IP (reachable from the parent's instances)"
  value       = module.gpu_node.private_ip
}

output "gpu_public_ip" {
  description = "GPU public IP for laptop SSH. Changes on stop/start."
  value       = module.gpu_node.public_ip
}

output "gpu_availability_zone" {
  description = "GPU availability zone"
  value       = module.gpu_node.availability_zone
}

output "gpu_ssm_start_session" {
  description = "SSM Session Manager command (fallback to SSH)"
  value       = module.gpu_node.ssm_start_session
}

# Ollama exposure
output "ollama_access" {
  description = "Effective Ollama exposure"
  value = {
    bind         = var.ollama_bind
    client_cidrs = var.ollama_client_cidrs
  }
}

output "ollama_security_group_id" {
  description = "Sidecar-owned SG for 11434 (null when no client CIDRs)"
  value       = module.gpu_node.ollama_security_group_id
}

output "ollama_vpc_url" {
  description = "Ollama URL for cdw and other VPC hosts (null when loopback-only)"
  value       = module.gpu_node.ollama_vpc_url
}

output "ollama_public_url" {
  description = "Ollama URL for approved client CIDRs (null when none). Changes on stop/start."
  value       = module.gpu_node.ollama_public_url
}
