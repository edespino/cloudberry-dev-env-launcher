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
