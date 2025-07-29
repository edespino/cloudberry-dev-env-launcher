terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Use the database-cluster module
module "database_cluster" {
  source = "../../modules/aws/database-cluster"

  # Core Configuration
  region     = var.region
  env_prefix = var.env_prefix
  vm_count   = var.vm_count
  my_ip      = var.my_ip

  # Security Configuration
  allow_remote_ssh_access = var.allow_remote_ssh_access

  # Instance Configuration
  ami              = var.ami
  instance_type    = var.instance_type
  default_username = var.default_username

  # Storage Configuration
  root_disk_size       = var.root_disk_size
  root_disk_iops       = var.root_disk_iops
  root_disk_throughput = var.root_disk_throughput
  data_drive_count     = var.data_drive_count
  data_drive_size      = var.data_drive_size
  data_drive_type      = var.data_drive_type
  iops                 = var.iops
  throughput           = var.throughput

  # Spot Instance Configuration
  use_spot_instances     = var.use_spot_instances
  spot_max_price         = var.spot_max_price
  spot_instance_strategy = var.spot_instance_strategy

  # Monitoring Configuration
  enable_monitoring = var.enable_monitoring
  alert_email       = var.alert_email

  # Legacy Features
  generate_inventory = var.generate_inventory

  # Use default module template (properly handles hostname replacement)
  # cloud_init_template = null  # Uses module's default template

  # Tags
  additional_tags = {
    Project     = "Cloudberry Database Environment"
    Environment = "Development"
    Purpose     = "Database Cluster Testing"
  }
}