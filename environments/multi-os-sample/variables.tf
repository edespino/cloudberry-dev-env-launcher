# Required variables
variable "my_ip" {
  description = "Your current public IP address for SSH access"
  type        = string
}

# Environment-specific overrides
variable "region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "us-west-2"
}

variable "env_prefix" {
  description = "The environment prefix to use for resource names"
  type        = string
}

variable "ami" {
  description = "The AMI to use for the instances"
  type        = string
}

variable "default_username" {
  description = "The default SSH username for the instances"
  type        = string
}

# Commonly customized variables
variable "vm_count" {
  description = "The number of instances to create"
  type        = number
}

variable "instance_type" {
  description = "The instance type to use for the instances"
  type        = string
}

variable "use_spot_instances" {
  description = "Use spot instances for cost savings (60-90% cheaper)"
  type        = bool
  default     = false
}

variable "allow_remote_ssh_access" {
  description = "Allow SSH access from anywhere (0.0.0.0/0) for remote team access"
  type        = bool
  default     = false
}

# Variables that pass through module defaults (no customization needed)
variable "root_disk_size" {
  description = "The size of the root disk in GB"
  type        = number
  default     = 100
}

variable "root_disk_iops" {
  description = "The IOPS for the root disk (gp3 volumes only, 3000-16000)"
  type        = number
  default     = 8000
}

variable "root_disk_throughput" {
  description = "The throughput in MB/s for the root disk (gp3 volumes only, 125-1000)"
  type        = number
  default     = 500
}

variable "data_drive_count" {
  description = "The number of data disks to attach to each instance"
  type        = number
  default     = 0
}

variable "data_drive_size" {
  description = "The size of the data disks in GB"
  type        = number
  default     = 250
}

variable "data_drive_type" {
  description = "The type of the EBS volume (gp2, gp3, io1, io2, st1, sc1)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "The IOPS for provisioned IOPS volumes (only applicable for io1 and io2)"
  type        = number
  default     = 3000
}

variable "throughput" {
  description = "The throughput in MiB/s for gp3 volumes"
  type        = number
  default     = 125
}

variable "spot_max_price" {
  description = "Maximum price to pay for spot instances (USD per hour)"
  type        = string
  default     = "0.50"
}

variable "spot_instance_strategy" {
  description = "Spot instance strategy: 'all', 'workers', 'mixed', 'none'"
  type        = string
  default     = "all"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alerting system"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = "ops@company.com"
}

variable "generate_inventory" {
  description = "Generate Ansible inventory file (legacy feature, disabled by default)"
  type        = bool
  default     = false
}

# DBaaS-specific variables
variable "deploy_dbaas_services" {
  description = "Whether to deploy DBaaS-specific resources (EKS, S3)"
  type        = bool
  default     = false
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

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days" {
  description = "Days to retain objects in S3"
  type        = number
  default     = 30
}
