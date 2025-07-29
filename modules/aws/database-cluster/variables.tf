# Core Configuration
variable "region" {
  description = "The AWS region to create resources in"
  type        = string
}

variable "env_prefix" {
  description = "The environment prefix to use for resource names"
  type        = string
}

variable "vm_count" {
  description = "The number of instances to create"
  type        = number
  default     = 1
}

# Instance Configuration
variable "ami" {
  description = "The AMI to use for the instances"
  type        = string
}

variable "instance_type" {
  description = "The instance type to use for the instances"
  type        = string
}

variable "my_ip" {
  description = "Your current public IP address for SSH access"
  type        = string
}

variable "allow_remote_ssh_access" {
  description = "Allow SSH access from anywhere (0.0.0.0/0) for remote team access"
  type        = bool
  default     = false
}

variable "default_username" {
  description = "The default SSH username for the instances"
  type        = string
  default     = "ec2-user"
}

# Storage Configuration
variable "root_disk_size" {
  description = "The size of the root disk in GB"
  type        = number
  default     = 100
}

variable "root_disk_iops" {
  description = "The IOPS for the root disk (gp3 volumes only, 3000-16000)"
  type        = number
  default     = 8000 # Balanced performance: 2.7x improvement over default 3000
  validation {
    condition     = var.root_disk_iops >= 3000 && var.root_disk_iops <= 16000
    error_message = "Root disk IOPS must be between 3000 and 16000 for gp3 volumes."
  }
}

variable "root_disk_throughput" {
  description = "The throughput in MB/s for the root disk (gp3 volumes only, 125-1000)"
  type        = number
  default     = 500 # Balanced performance: 4x improvement over default 125
  validation {
    condition     = var.root_disk_throughput >= 125 && var.root_disk_throughput <= 1000
    error_message = "Root disk throughput must be between 125 and 1000 MB/s for gp3 volumes."
  }
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

# Spot Instance Configuration
variable "use_spot_instances" {
  description = "Use spot instances for cost savings (60-90% cheaper)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price to pay for spot instances (USD per hour)"
  type        = string
  default     = "0.50" # ~60% of c7i.4xlarge on-demand price
}

variable "spot_instance_strategy" {
  description = "Spot instance strategy: 'all' (all instances), 'workers' (non-master only), 'mixed' (50/50)"
  type        = string
  default     = "all"
  validation {
    condition = contains([
      "all",     # All instances as spot
      "workers", # Only worker nodes (instance-1, instance-2) as spot
      "mixed",   # Random mix of spot/on-demand
      "none"     # All on-demand (same as use_spot_instances = false)
    ], var.spot_instance_strategy)
    error_message = "Spot strategy must be: all, workers, mixed, or none."
  }
}

# Monitoring Configuration
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

# Legacy Features
variable "generate_inventory" {
  description = "Generate Ansible inventory file (legacy feature, disabled by default)"
  type        = bool
  default     = false
}

# Cloud-init Configuration
variable "cloud_init_template" {
  description = "Path to cloud-init template file"
  type        = string
  default     = null
}

variable "hostnames" {
  description = "Custom hostnames for instances (optional, defaults to cdw, sdw1, sdw2, etc.)"
  type        = list(string)
  default     = []
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}