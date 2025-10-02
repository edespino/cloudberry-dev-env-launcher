# Cloudberry Development Environment Launcher

A Terraform-based infrastructure-as-code solution for deploying Cloudberry Database development environments on AWS.

## Overview

This repository provides Terraform modules and configurations to deploy scalable, secure development environments for Cloudberry Database. It includes automated provisioning of compute resources, networking, monitoring, and database cluster configurations.

## Features

- **Interactive OS Selection**: Choose from 15+ operating systems with guided setup and grouped display
- **Custom Cloudberry AMIs**: Pre-configured images from Synx Data Labs with build dependencies
- **Simple Setup**: Local state files by default - no S3/DynamoDB required
- **Automated Infrastructure**: Complete AWS infrastructure provisioning
- **Multi-OS Support**: Amazon Linux, Rocky Linux, Ubuntu, SUSE, Oracle Linux
- **Database Cluster**: Multi-node Cloudberry Database deployment
- **Cost Optimization**: Spot instances and start/stop functionality
- **Development Tools**: Rich set of aliases and helper functions
- **Monitoring**: Integrated monitoring and alerting
- **Security**: IAM roles, security groups, and encryption
- **Scalability**: Configurable cluster sizes and instance types

## Repository Structure

```
├── bin/                    # Utility scripts
│   ├── os-selector         # Interactive OS selection tool
│   ├── setup-aliases       # Development aliases setup
│   └── spot-check          # Spot instance availability checker
├── docs/                   # Documentation
│   ├── PREREQUISITES.md    # Setup requirements
│   ├── GETTING-STARTED.md  # First deployment guide
│   ├── AMI-DISCOVERY.md    # Dynamic AMI selection
│   └── TROUBLESHOOTING.md  # Common issues & solutions
├── environments/           # Environment configurations
│   ├── multi-os-sample/    # Multi-OS template environment
│   └── TEMPLATE-README.md  # Environment creation guide
├── lib/                    # Shared libraries
│   └── spot-functions.sh   # Spot instance helper functions
├── modules/                # Reusable Terraform modules
│   └── aws/database-cluster/ # Database cluster module
├── LICENSE                 # Apache 2.0 License
├── NOTICE                  # Copyright notices
├── CONTRIBUTING.md         # Contribution guidelines
└── README.md               # This file
```

## Quick Start

### Prerequisites

Before getting started, ensure you have the required tools and AWS configuration:

📋 **[Complete Prerequisites Guide](docs/PREREQUISITES.md)** - Essential setup requirements

**Quick checklist:**
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) v2 with SSO configured
- [direnv](https://direnv.net/) for automatic environment loading
- [jq](https://stedolan.github.io/jq/) for JSON processing
- AWS account with necessary permissions
- S3 bucket for Terraform state storage

### First Deployment

🚀 **[Complete Getting Started Guide](docs/GETTING-STARTED.md)** - Step-by-step deployment walkthrough

**Quick deployment:**

1. **Clone and setup:**
   ```bash
   git clone https://github.com/your-org/cloudberry-dev-env-launcher.git
   cd cloudberry-dev-env-launcher
   ```

2. **Create environment with OS selector:**
   ```bash
   # Interactive OS selection and environment creation
   ./bin/os-selector
   
   # Follow prompts to select OS and directory name
   # Navigate to created environment
   cd environments/your-selected-env
   ```

3. **Configure environment:**
   ```bash
   # Allow direnv to load .envrc
   direnv allow .
   
   # Initialize Terraform (local backend)
   terraform init
   # or: ti
   
   # For team collaboration (S3 backend)
   # tis3
   ```

3. **Deploy:**
   ```bash
   terraform plan
   terraform apply
   ```

4. **Connect:**
   ```bash
   # Wait for SSH and connect
   lw && lssh
   ```

## Configuration

### Dynamic AMI Discovery

The launcher automatically discovers and uses the latest available AMI matching your criteria. This is configured in your environment's `.envrc` file:

```bash
# AMI configuration for Oracle Linux 8.10
AMI_OWNER="679593333241"
AMI_FILTER='cloudimg-oel810-lvm-02-01-2025-prod-*'

# Automatically fetches the latest AMI matching the filter
latest_ami=$(aws ec2 describe-images --region $TF_VAR_region \
 --owners $AMI_OWNER \
 --filters "Name=name,Values=$AMI_FILTER" \
 --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
 --output text)
export TF_VAR_ami=$latest_ami
```

## Development Tools

### OS Selector (`bin/os-selector`)

Interactive tool for creating new environments with your preferred operating system:

```bash
./bin/os-selector
```

**Features:**
- Choose from 8+ supported operating systems
- Automatic AMI configuration for selected OS
- Default directory naming with custom name option
- Navigation between choices (back/forward)
- Default selections for quick setup

**Supported Operating Systems:**

*Cloudberry Packer Custom AMIs* (provided by Synx Data Labs in us-west-2):
- Amazon Linux 2023 - Cloudberry build
- Rocky Linux 8, 9, 10 - Cloudberry build
- Ubuntu 20.04, 22.04 - Cloudberry build

*Base AMIs*:
- Amazon Linux 2023
- Oracle Linux 8.10
- Rocky Linux 8, 9, 10
- OpenSUSE 15.6
- SUSE Linux Enterprise 15 SP6
- Ubuntu 20.04, 22.04, 24.04

### Spot Instance Checker (`bin/spot-check`)

Check spot instance availability and pricing before deployment:

```bash
./bin/spot-check
# or from environment: spot-check
```

**Benefits:**
- ✅ Always uses the latest AMI version
- ✅ No manual AMI ID updates required
- ✅ Automatic validation and error handling
- ✅ Rich status display showing which AMI is selected

📖 **[See detailed AMI Discovery documentation](docs/AMI-DISCOVERY.md)** for advanced configuration and troubleshooting.

### Environment Variables

Key configuration options include:

- `instance_type`: EC2 instance type for database nodes
- `cluster_size`: Number of database nodes
- `availability_zones`: AWS availability zones to use
- `vpc_cidr`: VPC CIDR block

### Customization

Modify the variables in your environment's `variables.tf` file to customize:

- Instance specifications
- Network configuration
- Security settings
- Monitoring preferences

## Modules

### Database Cluster Module

The `database-cluster` module provides:

- **Compute**: EC2 instances with auto-scaling groups
- **Networking**: VPC, subnets, and security groups
- **Storage**: EBS volumes with encryption
- **Monitoring**: CloudWatch metrics and alarms
- **Security**: IAM roles and policies

## Security Considerations

- All data is encrypted at rest and in transit
- Security groups follow least-privilege principles
- IAM roles use minimal required permissions
- Regular security updates through automated patching

## Monitoring

The deployment includes:

- CloudWatch metrics for system and database performance
- Custom alerts for critical thresholds
- Log aggregation and analysis
- Performance dashboards

## Documentation

### 📚 Complete Guides

- **[Prerequisites](docs/PREREQUISITES.md)** - Required tools and AWS setup
- **[Getting Started](docs/GETTING-STARTED.md)** - Step-by-step first deployment
- **[AMI Discovery](docs/AMI-DISCOVERY.md)** - Dynamic AMI selection details
- **[Environment Template](environments/TEMPLATE-README.md)** - Creating custom environments
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### 🛠️ Module Documentation

- **[Database Cluster Module](modules/aws/database-cluster/README.md)** - Detailed module reference

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

For questions, issues, or feature requests, please open an issue on GitHub.

## Acknowledgments

This project builds upon the excellent work of the Cloudberry Database community and leverages various open-source tools and AWS services.