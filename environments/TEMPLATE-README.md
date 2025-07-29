# Environment Template

This directory contains template files for creating new Cloudberry Database development environments.

## Recommended: Use OS Selector

The easiest way to create a new environment is using the interactive OS selector:

```bash
# From the repository root
./bin/os-selector

# Follow the prompts to:
# 1. Select your preferred OS (Rocky Linux, Ubuntu, Amazon Linux, etc.)
# 2. Choose directory name (or use default)
# 3. Automatically create configured environment
```

## Manual Setup (Advanced)

If you prefer manual setup or need custom configurations:

### 1. Copy Template

```bash
# From the repository root
cp -r environments/multi-os-sample environments/my-new-env
cd environments/my-new-env
```

### 2. Customize Configuration

Edit the `.envrc` file to match your requirements:

```bash
# Essential customizations
export TF_VAR_instance_type="c7i.4xlarge"    # Choose your instance size
export TF_VAR_vm_count=1                     # Number of instances
export TF_VAR_use_spot_instances="true"      # Cost optimization

# AMI configuration (customize for your AMI source)
AMI_OWNER="679593333241"                     # Your AMI owner account ID
AMI_FILTER='cloudimg-oel810-lvm-*'           # AMI name pattern

# Security settings
export TF_VAR_allow_remote_ssh_access="false"  # Keep restrictive
export TF_VAR_enable_monitoring="true"         # Enable monitoring
```

### 3. Backend Configuration (Optional)

**Default**: Uses local state files (simple, no setup required)

**For team collaboration**, optionally enable S3 backend in `backend.tf`:

1. **Uncomment the S3 backend block**
2. **Update bucket name** to your organization's bucket
3. **Run** `terraform init -migrate-state`

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "environments/my-new-env/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

**When to use S3 backend:**
- ✅ Team collaboration needed
- ✅ State backup/recovery required
- ✅ State locking important
- ❌ Individual development (local is simpler)

### 4. Initialize and Deploy

```bash
# Allow direnv to load environment
direnv allow .

# Initialize Terraform (choose one)
ti      # Local backend (simple)
tis3    # S3 backend (team collaboration)

# Plan and apply
terraform plan
terraform apply
```

## Template Files

### Core Files

| File | Purpose | Customization Needed |
|------|---------|---------------------|
| `main.tf` | Main Terraform configuration | Usually no changes needed |
| `variables.tf` | Variable definitions | Usually no changes needed |
| `outputs.tf` | Output definitions | Usually no changes needed |
| `backend.tf` | Terraform state backend | Update bucket name if different |

### Environment Files

| File | Purpose | Customization Needed |
|------|---------|---------------------|
| `.envrc` | Environment variables and AMI discovery | **Yes - customize for your use case** |
| `.env` | Development aliases and functions | Optional - add your own aliases |

### Backend Aliases

The `.env` file provides convenient aliases for Terraform initialization:

| Alias | Command | Backend | Use Case |
|-------|---------|---------|----------|
| `ti` | `terraform init` | Local | Individual development, testing |
| `tis3` | `terraform init` + S3 config | S3 | Team collaboration, shared state |

**Examples:**
```bash
# Simple local development
ti && terraform plan && terraform apply

# Team collaboration with shared state
tis3 && terraform plan && terraform apply
```

## Common Customizations

### Different Operating Systems

**Ubuntu 22.04:**
```bash
# In .envrc
AMI_OWNER="099720109477"  # Canonical
AMI_FILTER='ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*'
export TF_VAR_default_username="ubuntu"
```

**Amazon Linux 2023:**
```bash
# In .envrc
AMI_OWNER="137112412989"  # Amazon
AMI_FILTER='al2023-ami-*-x86_64'
export TF_VAR_default_username="ec2-user"
```

**RHEL 9:**
```bash
# In .envrc
AMI_OWNER="309956199498"  # Red Hat
AMI_FILTER='RHEL-9.*-x86_64-*'
export TF_VAR_default_username="ec2-user"
```

### Performance Configurations

**Development/Testing:**
```bash
export TF_VAR_instance_type="t3.medium"
export TF_VAR_vm_count=1
export TF_VAR_use_spot_instances="true"
export TF_VAR_root_disk_size=50
```

**Performance Testing:**
```bash
export TF_VAR_instance_type="c7i.4xlarge"
export TF_VAR_vm_count=3
export TF_VAR_use_spot_instances="true"
export TF_VAR_root_disk_size=100
export TF_VAR_root_disk_iops=8000
export TF_VAR_root_disk_throughput=500
```

**Production-like:**
```bash
export TF_VAR_instance_type="c7i.8xlarge"
export TF_VAR_vm_count=5
export TF_VAR_use_spot_instances="false"  # On-demand for stability
export TF_VAR_root_disk_size=200
export TF_VAR_root_disk_iops=12000
export TF_VAR_root_disk_throughput=750
```

### Regional Deployments

For different AWS regions, update both `.envrc` and `backend.tf`:

**.envrc:**
```bash
export TF_VAR_region=us-east-1  # or your preferred region
```

**backend.tf:**
```hcl
terraform {
  backend "s3" {
    region = "us-east-1"  # Match your .envrc region
    # ... other settings
  }
}
```

## Environment Naming

Use descriptive names that indicate:
- **Purpose**: `dev`, `test`, `perf`, `staging`
- **OS**: `ubuntu`, `rhel`, `ol810`
- **Owner**: Your username or team name

**Examples:**
- `john-dev-ubuntu` - John's Ubuntu development environment
- `team-perf-ol810` - Team performance testing on Oracle Linux
- `staging-rhel9` - Staging environment on RHEL 9

## Security Best Practices

### SSH Access

```bash
# Keep SSH restricted to your IP (recommended)
export TF_VAR_allow_remote_ssh_access="false"

# Only enable remote access temporarily when needed
export TF_VAR_allow_remote_ssh_access="true"   # Enable for team access
# ... do work ...
export TF_VAR_allow_remote_ssh_access="false"  # Disable when done
terraform apply
```

### Monitoring

```bash
# Always enable monitoring for cost and security visibility
export TF_VAR_enable_monitoring="true"
export TF_VAR_alert_email="your-email@company.com"
```

## Development Workflow

### Environment Lifecycle

1. **Create**: Copy template and customize
2. **Deploy**: `terraform apply`
3. **Develop**: Use SSH aliases from `.env`
4. **Pause**: `istop` when not in use
5. **Resume**: `istart` when needed
6. **Destroy**: `terraform destroy` when done

### Daily Usage

```bash
# Start your day
cd environments/my-env
istart && lw  # Start instances and wait for SSH

# Development work
lssh          # SSH to main instance
icode         # Open VS Code remote

# End your day
istop         # Stop instances to save costs
```

## Cost Optimization

### Spot Instances

```bash
# Enable spot instances for maximum savings
export TF_VAR_use_spot_instances="true"
export TF_VAR_spot_instance_strategy="all"  # All instances as spot
export TF_VAR_spot_max_price="0.50"        # Maximum hourly price
```

### Right-sizing

Start small and scale up as needed:
1. Begin with `t3.medium` for basic testing
2. Move to `c7i.large` for light development
3. Scale to `c7i.4xlarge` for performance testing
4. Use `c7i.8xlarge` for production-like workloads

## Troubleshooting

### Template Issues

**1. AMI Not Found**
- Verify `AMI_OWNER` and `AMI_FILTER` are correct for your region
- Check AMI availability: `aws ec2 describe-images --owners <AMI_OWNER>`

**2. Backend Access Denied**
- Ensure S3 bucket exists and is accessible
- Verify DynamoDB table exists for state locking
- Check IAM permissions

**3. direnv Not Loading**
```bash
# Allow the environment
direnv allow .

# If still not working, source manually
source .envrc
```

### Getting Help

- **Prerequisites**: Review [PREREQUISITES.md](../docs/PREREQUISITES.md)
- **Setup Guide**: Follow [GETTING-STARTED.md](../docs/GETTING-STARTED.md)
- **AMI Discovery**: See [AMI-DISCOVERY.md](../docs/AMI-DISCOVERY.md)
- **Issues**: Open a GitHub issue with environment details

## Next Steps

Once your environment is configured and deployed:

1. **Follow the [Getting Started Guide](../docs/GETTING-STARTED.md)** for deployment steps
2. **Explore the development aliases** in `.env` for daily workflow
3. **Set up your database** following Cloudberry Database documentation
4. **Configure monitoring** and cost alerts as needed

Happy developing! 🚀