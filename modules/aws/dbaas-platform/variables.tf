# Required Variables
variable "region" {
  description = "AWS region for DBaaS resources"
  type        = string
}

variable "env_prefix" {
  description = "Environment prefix for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the database cluster module"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for NAT Gateway (from database cluster)"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID from database cluster module"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use for EKS subnets"
  type        = list(string)
  default     = []
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "eks_desired_capacity" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "eks_max_capacity" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 8
}

variable "eks_min_capacity" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_disk_size" {
  description = "Disk size in GB for EKS worker nodes"
  type        = number
  default     = 50
}

variable "use_spot_instances" {
  description = "Use spot instances for EKS worker nodes (inherited from database cluster)"
  type        = bool
  default     = false
}

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days" {
  description = "Days to retain objects in S3 before expiration"
  type        = number
  default     = 30
}

variable "s3_noncurrent_version_days" {
  description = "Days to retain noncurrent versions of S3 objects"
  type        = number
  default     = 7
}

# Tagging
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Service Account Configuration
variable "service_account_namespace" {
  description = "Kubernetes namespace for the DBaaS service account"
  type        = string
  default     = "dbaas"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for S3 access (IRSA)"
  type        = string
  default     = "dbaas-s3-access"
}

# IAM User Configuration (Fallback for applications that don't support IRSA)
variable "create_iam_user" {
  description = "Create IAM user with static credentials (fallback when IRSA not supported by application)"
  type        = bool
  default     = true  # Default to true since synxdb-dbaas-integration v1.1.0 does not support IRSA
}

# RDS PostgreSQL Configuration
variable "rds_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "16.11"
}

variable "rds_instance_class" {
  description = "Instance class for RDS database"
  type        = string
##  default     = "db.t3.medium"
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage in GB for RDS autoscaling"
  type        = number
  default     = 100
}

variable "rds_storage_type" {
  description = "Storage type for RDS (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

variable "rds_storage_encrypted" {
  description = "Enable storage encryption for RDS"
  type        = bool
  default     = true
}

variable "rds_database_name" {
  description = "Name of the PostgreSQL database to create"
  type        = string
  default     = "dbaas"
}

variable "rds_master_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "dbaasadmin"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights for RDS"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
  default     = false
}

variable "rds_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "rds_apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window"
  type        = bool
  default     = false
}

variable "rds_max_connections" {
  description = "Maximum number of database connections"
  type        = string
  default     = "200"
}

# External Access Configuration
variable "enable_alb_ingress" {
  description = "Enable ALB with AWS Load Balancer Controller for external access to DBaaS UI"
  type        = bool
  default     = true
}

variable "dbaas_namespace" {
  description = "Kubernetes namespace where DBaaS application is deployed"
  type        = string
  default     = "dbaas"
}

variable "dbaas_service_name" {
  description = "Kubernetes service name for DBaaS application"
  type        = string
  default     = "dbaas-integration"
}

variable "dbaas_service_port" {
  description = "Port number for DBaaS application service"
  type        = number
  default     = 8030
}

# Domain and DNS Configuration
variable "dbaas_domain_name" {
  description = "Domain name for DBaaS UI (e.g., synxdb-elastic.synxdata.com). If empty, auto-generates using domain_prefix and env_prefix"
  type        = string
  default     = ""
}

variable "domain_prefix" {
  description = "Prefix for auto-generated domain name (e.g., 'synxdb' creates synxdb-{env_prefix}.synxdata.com)"
  type        = string
  default     = "synxdb"
}

variable "domain_suffix" {
  description = "Suffix for auto-generated domain name"
  type        = string
  default     = "synxdata.com"
}

# SSL/TLS Configuration
variable "enable_tls" {
  description = "Enable TLS/SSL for ingress"
  type        = bool
  default     = false
}

variable "enable_ssl_redirect" {
  description = "Force SSL redirect (HTTP to HTTPS)"
  type        = bool
  default     = false
}

variable "tls_secret_name" {
  description = "Name of Kubernetes secret containing TLS certificate"
  type        = string
  default     = "dbaas-tls-secret"
}

# Cloudflare Configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS records"
  type        = string
  default     = ""
}

variable "enable_cloudflare_dns" {
  description = "Enable automatic Cloudflare DNS record creation"
  type        = bool
  default     = true
}

variable "cloudflare_proxy_enabled" {
  description = "Enable Cloudflare proxy (orange cloud) for SSL and DDoS protection"
  type        = bool
  default     = false
}

variable "cloudflare_dns_ttl" {
  description = "TTL for Cloudflare DNS records (1 = auto, must be 1 if proxied)"
  type        = number
  default     = 1
}

variable "enable_cloudflare_firewall" {
  description = "Enable Cloudflare firewall rules for IP-based access control"
  type        = bool
  default     = false
}

variable "cloudflare_allowed_ips" {
  description = "List of IP addresses/CIDRs allowed through Cloudflare firewall"
  type        = list(string)
  default     = []
}
