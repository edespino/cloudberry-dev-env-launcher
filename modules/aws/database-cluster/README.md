# Database Cluster Terraform Module

This module creates an optimized AWS infrastructure for database clusters with advanced performance features, cost optimization, and monitoring capabilities.

## Features

- **Optimized Cluster Discovery**: 2-minute timeout with dynamic sleep intervals
- **High-Performance Networking**: Placement groups for 10+ Gbps bandwidth and <0.5ms latency
- **SSH Configuration**: No host key verification prompts for seamless connectivity
- **Cost Optimization**: Configurable spot instances (60-90% savings)
- **EBS Performance**: Configurable root disk IOPS and throughput (up to 2.67x IOPS, 4x throughput improvement)
- **Additional EBS Volumes**: Attach multiple data volumes per instance (up to 11 drives per instance)
- **Advanced Monitoring**: CloudWatch alarms with SQS + Lambda processing and SES email notifications (Drata compliant)
- **Complete Networking**: VPC with public subnet, security groups, and S3 VPC endpoint
- **Automated SSH Keys**: RSA 4096-bit key generation and management
- **Legacy Support**: Optional Ansible inventory generation

## Usage

### Option 1: With .envrc (Recommended)

Create a `.envrc` file for automatic environment configuration:

```bash
# .envrc - Automatically sourced when entering directory (requires direnv)
CURRENT_DIR=${PWD##*/}
export TF_VAR_env_prefix=${USER}-$CURRENT_DIR
export TF_VAR_region=us-west-2

# Dynamic AMI discovery
AMI_OWNER="703671893074"
AMI_FILTER='cloudberry-ol810-*'
latest_ami=$(aws ec2 describe-images --region $TF_VAR_region \
 --owners $AMI_OWNER \
 --filters "Name=name,Values=$AMI_FILTER" \
 --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
 --output text)
export TF_VAR_ami=$latest_ami

# Other configuration
export TF_VAR_my_ip=$(curl -s https://api.ipify.org)
export TF_VAR_instance_type="c7i.4xlarge"
export TF_VAR_vm_count=3
```

Then use the module with minimal configuration:

```hcl
module "database_cluster" {
  source = "../modules/database-cluster"

  # Core Configuration (from .envrc)
  region     = var.region
  env_prefix = var.env_prefix
  vm_count   = var.vm_count
  my_ip      = var.my_ip
  ami        = var.ami
  instance_type = var.instance_type

  # Performance Optimization
  use_spot_instances      = true
  spot_instance_strategy  = "all"
  root_disk_iops         = 8000   # 2.67x improvement
  root_disk_throughput   = 500    # 4x improvement

  # Optional Features
  enable_monitoring    = true
  alert_email         = "ops@company.com"
  generate_inventory  = false

  # Custom Tags
  additional_tags = {
    Project = "Database Migration"
    Owner   = "DBA Team"
  }
}
```

### Option 2: Direct Configuration

```hcl
module "database_cluster" {
  source = "../modules/database-cluster"

  # Core Configuration
  region     = "us-west-2"
  env_prefix = "my-env"
  vm_count   = 3
  my_ip      = "1.2.3.4"

  # Instance Configuration
  ami           = "ami-07db6695238caa4ca"  # Oracle Linux 8.10
  instance_type = "c7i.4xlarge"

  # Performance Optimization
  use_spot_instances      = true
  spot_instance_strategy  = "all"
  root_disk_iops         = 8000   # 2.67x improvement
  root_disk_throughput   = 500    # 4x improvement

  # Additional EBS Data Volumes
  data_drive_count  = 2           # 2 additional drives per instance
  data_drive_size   = 500         # 500 GB per drive
  data_drive_type   = "gp3"       # EBS volume type
  iops              = 3000        # For io1/io2 volumes
  throughput        = 125         # For gp3 volumes

  # Optional Features
  enable_monitoring    = true
  alert_email         = "ops@company.com"
  generate_inventory  = false

  # Custom Tags
  additional_tags = {
    Project = "Database Migration"
    Owner   = "DBA Team"
  }
}
```

## Performance Optimizations

### 1. Cluster Discovery (60% faster)
- **2-minute timeout**: Reduced from 5 minutes
- **Dynamic sleep intervals**: 3s (first 6 attempts) → 5s (next 6) → 7s (final attempts)
- **Partial discovery**: Adds available instances after 60 seconds if not all found
- **IAM role**: EC2 instances can discover cluster members via AWS API
- **Hostname mapping**: Automatic cdw/sdw1/sdw2/etc hostname assignment

### 2. High-Performance Networking
- AWS placement groups provide:
  - 10+ Gbps bandwidth between instances
  - <0.5ms latency
  - Optimal for database clusters

### 3. Spot Instance Strategies
- **all**: All instances as spot (maximum savings)
- **workers**: Only worker nodes as spot (master stability)
- **mixed**: 50/50 spot/on-demand distribution
- **none**: All on-demand instances

### 4. EBS Performance
- **Root disk optimization**: Configurable gp3 volumes with custom IOPS and throughput
- **Balanced defaults**: 8K IOPS, 500 MB/s throughput
- **Cost**: ~$53/month per 100GB volume
- **Performance**: 2.67x IOPS, 4x throughput vs default
- **Dynamic disk discovery**: Cloud-init script automatically formats and mounts additional NVMe devices

### 5. Additional EBS Data Volumes
- **Multiple volumes per instance**: Attach up to 11 data drives per instance
- **Flexible configuration**: Configure size, type (gp2, gp3, io1, io2, st1, sc1), IOPS, and throughput
- **Automatic device naming**: Volumes are attached as /dev/sdf through /dev/sdp
- **Distribution logic**: Volumes are evenly distributed across all instances in the cluster
- **Volume types**:
  - **gp3**: General Purpose SSD with configurable IOPS (3000-16000) and throughput (125-1000 MiB/s)
  - **io1/io2**: Provisioned IOPS SSD for high-performance workloads
  - **st1**: Throughput-optimized HDD for big data workloads
  - **sc1**: Cold HDD for infrequent access
- **Default**: No additional volumes (set `data_drive_count > 0` to enable)

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| region | AWS region | string | - | yes |
| env_prefix | Environment prefix for resource names | string | - | yes |
| vm_count | Number of instances to create | number | 1 | no |
| ami | AMI ID to use | string | - | yes |
| instance_type | EC2 instance type | string | - | yes |
| my_ip | Your public IP for SSH access | string | - | yes |
| allow_remote_ssh_access | Allow SSH from anywhere (0.0.0.0/0) | bool | false | no |
| default_username | SSH username for instances | string | "ec2-user" | no |
| root_disk_size | Root disk size in GB | number | 100 | no |
| root_disk_iops | Root disk IOPS (3000-16000) | number | 8000 | no |
| root_disk_throughput | Root disk throughput MB/s (125-1000) | number | 500 | no |
| data_drive_count | Number of additional data drives per instance | number | 0 | no |
| data_drive_size | Size of each data drive in GB | number | 250 | no |
| data_drive_type | EBS volume type (gp2, gp3, io1, io2, st1, sc1) | string | "gp3" | no |
| iops | IOPS for io1/io2 volumes | number | 3000 | no |
| throughput | Throughput in MiB/s for gp3 volumes | number | 125 | no |
| use_spot_instances | Use spot instances for cost savings | bool | false | no |
| spot_max_price | Maximum price for spot instances (USD/hour) | string | "0.50" | no |
| spot_instance_strategy | Spot strategy: all/workers/mixed/none | string | "all" | no |
| enable_monitoring | Enable CloudWatch monitoring | bool | false | no |
| alert_email | Email for monitoring alerts | string | "ops@company.com" | no |
| generate_inventory | Generate Ansible inventory | bool | false | no |
| cloud_init_template | Path to custom cloud-init template | string | null | no |
| hostnames | Custom hostnames for instances | list(string) | [] | no |
| additional_tags | Additional tags for resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_public_ips | Public IP addresses of instances |
| instance_hostnames | Instance hostnames (cdw, sdw1, sdw2, etc.) |
| ssh_private_key_path | Path to generated SSH private key |
| vpc_id | VPC ID for integration/debugging |
| instance_ids | EC2 instance IDs |
| monitoring_summary | Monitoring configuration (if enabled) |
| data_volumes | EBS data volume details (volume IDs, size, type, count) |
| volume_attachments | EBS volume attachment details (instance mapping, device names) |

## Cost Analysis

### Monthly Cost Comparison (3 instances)
- **Without optimizations**: $1,742/month
- **With optimizations**: $865/month
- **Savings**: 50% ($877/month)

### Cost Breakdown
- **Spot instances**: 60-90% savings on compute
- **EBS optimization**: +$30/month per instance for performance
- **Placement groups**: No additional cost
- **Monitoring**: ~$5/month for CloudWatch alarms

## Infrastructure Components

### Networking
- **VPC**: 10.0.0.0/16 CIDR with DNS support enabled
- **Public Subnet**: 10.0.1.0/24 in first availability zone
- **Internet Gateway**: For public internet access
- **Security Group**: Configured ports:
  - SSH (22): Your IP + optional remote access (0.0.0.0/0)
  - HTTP (80): Your IP + VPC internal
  - HTTPS (443): Your IP + VPC internal  
  - PostgreSQL (5432): Your IP + VPC internal
  - Application (8080): Your IP + VPC internal
  - Internal TCP (0-65535): VPC internal only
  - ICMP: VPC internal for ping
- **VPC Endpoint**: S3 access without internet gateway
- **Placement Group**: Cluster strategy for high-performance networking

### Monitoring Architecture (when enabled)
- **CloudWatch Alarms**: CPU warning (75%), CPU critical (90%), instance status checks, system status checks
- **SNS Topic**: Receives CloudWatch alarm notifications
- **SQS Queue**: Buffers alarm messages for processing
- **Lambda Function**: Processes alarms and sends formatted emails via SES
- **IAM Roles**: Lambda execution role with SES and SQS permissions

### Security Features

#### SSH Key Management
- **RSA 4096-bit keys**: Auto-generated for secure access
- **Local PEM file**: Created with proper permissions (400)
- **SSH config**: No host key verification for cluster IPs

#### Remote SSH Access
For temporary remote team access, set `allow_remote_ssh_access = true`. This opens SSH (port 22) to `0.0.0.0/0`.

**⚠️ Security Warning**: Only enable when needed and disable immediately after use.

```bash
# In .envrc file
export TF_VAR_allow_remote_ssh_access="true"   # Enable remote access
terraform apply

# After remote work is complete
export TF_VAR_allow_remote_ssh_access="false"  # Disable remote access
terraform apply
```

## Requirements

- Terraform >= 1.0
- AWS Provider ~> 5.0
- TLS Provider ~> 4.0 (for SSH key generation)
- Local Provider ~> 2.0 (for file management)
- Null Provider ~> 3.0 (for local-exec provisioners)
- Archive Provider ~> 2.0 (for Lambda deployment packages)
- Valid AWS credentials
- SSH key pair (auto-generated)

## Examples

### Basic 3-Node Cluster
```hcl
module "test_cluster" {
  source = "../modules/database-cluster"
  
  region     = "us-west-2"
  env_prefix = "test-db"
  vm_count   = 3
  ami        = "ami-07db6695238caa4ca"
  instance_type = "c7i.4xlarge"
  my_ip      = "203.0.113.1"
}
```

### Production Cluster with Monitoring
```hcl
module "prod_cluster" {
  source = "../modules/database-cluster"
  
  region     = "us-east-1"
  env_prefix = "prod-db"
  vm_count   = 5
  ami        = "ami-12345678"
  instance_type = "c7i.8xlarge"
  my_ip      = "203.0.113.1"
  
  # Performance optimizations
  use_spot_instances     = true
  spot_instance_strategy = "workers"  # Keep master on-demand
  root_disk_iops        = 12000
  root_disk_throughput  = 750
  root_disk_size        = 200

  # Additional data volumes
  data_drive_count = 4            # 4 additional drives per instance
  data_drive_size  = 1000         # 1TB per drive
  data_drive_type  = "gp3"
  iops             = 5000
  throughput       = 250

  # Monitoring
  enable_monitoring = true
  alert_email      = "dba@company.com"
  
  additional_tags = {
    Environment = "Production"
    Compliance  = "SOC2"
  }
}
```

## Contributing

This module is designed to be reusable across multiple database environments. When making changes:

1. Update the features list in README
2. Update README with new variables/outputs  
3. Test with multiple environments
4. Ensure monitoring lambda function works with SES configuration
5. Validate cloud-init scripts work with different AMIs

## License

Apache License 2.0 - see [LICENSE](../../LICENSE) file for details