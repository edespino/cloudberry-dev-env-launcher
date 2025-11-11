# EKS Cluster Outputs
output "eks_cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.dbaas_cluster.id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.dbaas_cluster.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster API server"
  value       = aws_eks_cluster.dbaas_cluster.endpoint
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.dbaas_cluster.arn
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.dbaas_cluster.version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.dbaas_cluster.vpc_config[0].cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "eks_oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks_oidc.url
}

output "eks_node_group_id" {
  description = "ID of the EKS node group"
  value       = aws_eks_node_group.dbaas_workers.id
}

output "eks_node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.dbaas_workers.status
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${local.eks_cluster_name}"
}

# S3 Bucket Outputs
output "s3_storage_bucket_id" {
  description = "ID of the primary storage S3 bucket"
  value       = aws_s3_bucket.dbaas_storage.id
}

output "s3_storage_bucket_arn" {
  description = "ARN of the primary storage S3 bucket"
  value       = aws_s3_bucket.dbaas_storage.arn
}

output "s3_backup_bucket_id" {
  description = "ID of the backup S3 bucket"
  value       = aws_s3_bucket.dbaas_backups.id
}

output "s3_backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  value       = aws_s3_bucket.dbaas_backups.arn
}

# IAM Outputs
output "dbaas_s3_role_arn" {
  description = "ARN of the IAM role for S3 access from EKS (IRSA)"
  value       = aws_iam_role.dbaas_s3_access.arn
}

output "dbaas_s3_role_name" {
  description = "Name of the IAM role for S3 access"
  value       = aws_iam_role.dbaas_s3_access.name
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_role.arn
}

# Networking Outputs
output "eks_private_subnet_ids" {
  description = "IDs of the private subnets used by EKS"
  value       = aws_subnet.eks_private[*].id
}

output "eks_private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.eks_private[*].cidr_block
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# Service Account Information
output "service_account_namespace" {
  description = "Kubernetes namespace for the DBaaS service account"
  value       = var.service_account_namespace
}

output "service_account_name" {
  description = "Name of the Kubernetes service account for S3 access"
  value       = var.service_account_name
}

output "service_account_annotation" {
  description = "Annotation to add to Kubernetes service account for IRSA"
  value       = "eks.amazonaws.com/role-arn=${aws_iam_role.dbaas_s3_access.arn}"
}

# Summary Output
output "dbaas_platform_summary" {
  description = "Summary of all DBaaS platform resources"
  value = {
    eks_cluster = {
      name            = aws_eks_cluster.dbaas_cluster.name
      endpoint        = aws_eks_cluster.dbaas_cluster.endpoint
      version         = aws_eks_cluster.dbaas_cluster.version
      arn             = aws_eks_cluster.dbaas_cluster.arn
      private_subnets = aws_subnet.eks_private[*].id
    }
    s3_buckets = {
      storage_bucket = aws_s3_bucket.dbaas_storage.id
      backup_bucket  = aws_s3_bucket.dbaas_backups.id
    }
    networking = {
      nat_gateway_id = aws_nat_gateway.main.id
      nat_public_ip  = aws_eip.nat.public_ip
    }
    iam_roles = {
      s3_access_role_arn = aws_iam_role.dbaas_s3_access.arn
      oidc_provider_arn  = aws_iam_openid_connect_provider.eks_oidc.arn
    }
    service_account = {
      namespace  = var.service_account_namespace
      name       = var.service_account_name
      annotation = "eks.amazonaws.com/role-arn=${aws_iam_role.dbaas_s3_access.arn}"
    }
  }
}
