output "name" {
  description = "Name tag of the GPU instance (<name_prefix>-<node_name>)."
  value       = local.name
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IPv4 address inside the parent VPC."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address. Changes on every stop/start (no EIP)."
  value       = aws_instance.this.public_ip
}

output "availability_zone" {
  description = "Availability zone (inherited from the subnet)."
  value       = aws_instance.this.availability_zone
}

output "iam_role_name" {
  description = "SSM-only IAM role attached to the instance."
  value       = aws_iam_role.this.name
}

output "ssm_start_session" {
  description = "SSM Session Manager command (fallback to SSH)."
  value       = "aws ssm start-session --region ${data.aws_region.current.name} --target ${aws_instance.this.id}"
}

output "ollama_security_group_id" {
  description = "Sidecar-owned SG for 11434/tcp, or null when ollama_client_cidrs is empty."
  value       = one(aws_security_group.ollama[*].id)
}

output "ollama_vpc_url" {
  description = "Ollama API URL for clients inside the VPC (cdw), or null when Ollama is loopback-only."
  value       = var.ollama_bind == "all" ? "http://${aws_instance.this.private_ip}:11434" : null
}

output "ollama_public_url" {
  description = "Ollama API URL for approved client CIDRs over the public IP, or null. Changes on stop/start."
  value       = length(var.ollama_client_cidrs) > 0 ? "http://${aws_instance.this.public_ip}:11434" : null
}
