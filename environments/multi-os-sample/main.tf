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

# DBaaS Platform Module (optional EKS + S3 infrastructure)
module "dbaas_platform" {
  count  = var.deploy_dbaas_services ? 1 : 0
  source = "../../modules/aws/dbaas-platform"

  # Core Configuration (from database cluster)
  region           = var.region
  env_prefix       = var.env_prefix
  vpc_id           = module.database_cluster.vpc_id
  public_subnet_id = module.database_cluster.subnet_id

  # EKS Configuration
  eks_cluster_version     = var.eks_cluster_version
  eks_node_instance_types = var.eks_node_instance_types
  eks_desired_capacity    = var.eks_desired_capacity
  eks_max_capacity        = var.eks_max_capacity
  use_spot_instances      = var.use_spot_instances

  # S3 Configuration
  enable_s3_versioning = var.enable_s3_versioning
  s3_lifecycle_days    = var.s3_lifecycle_days

  # Tags
  common_tags = {
    Project     = "Cloudberry Database Environment"
    Environment = "Development"
    Purpose     = "DBaaS Platform Infrastructure"
    ManagedBy   = "Terraform"
  }
}