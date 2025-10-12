# Getting Started

This guide walks you through deploying your first Cloudberry Database development environment.

## Quick Start Checklist

- ✅ [Prerequisites installed](PREREQUISITES.md)
- ✅ AWS SSO configured
- ✅ Repository cloned

**Note**: S3 backend setup is now **optional** - local state files work out of the box!

## Step 1: Clone and Setup

### Clone the Repository

```bash
git clone https://github.com/edespino/cloudberry-dev-env-launcher.git
cd cloudberry-dev-env-launcher
```

### Create Environment with OS Selector (Recommended)

Use the interactive OS selector to create a new environment:

```bash
# Launch interactive environment creation
./bin/os-selector
```

The selector will guide you through:
1. **OS Selection**: Choose from 15+ operating systems
2. **Subdirectory**: Optional single-level subdirectory (e.g., `apache`, `experimental`)
3. **Directory Name**: Use default or specify custom name
4. **Instance Type**: Select from C7i, C6i, or C5 generations (vertical menu)
5. **Spot Instances**: Choose between on-demand or spot instances
6. **Confirmation**: Review and confirm your selections

**Subdirectory Organization:**
- **No subdirectory** (default): Creates `environments/rl9-apache-polaris/`
- **With subdirectory**: Creates `environments/apache/rl9-polaris-test/`
- Shows existing subdirectories for easy reuse
- Only single-level subdirectories supported (no nested paths like `apache/experimental`)
- Automatically adjusts:
  - Terraform module paths (`main.tf`)
  - REPO_ROOT calculations (`.env`)
  - Environment path references (`.envrc`)

### OR Copy Sample Environment (Manual)

Alternatively, create your own environment based on the sample:

```bash
# Copy the sample environment
cp -r environments/ol810-sample-test environments/my-dev-env
cd environments/my-dev-env
```

## Step 2: Configure Your Environment

### Customize .envrc

**If you used os-selector**: Your `.envrc` is already pre-configured with your selections (OS, instance type, spot instances). You may skip to Step 3.

**If you copied manually**: Edit the `.envrc` file for your needs:

```bash
# Edit environment configuration
nano .envrc
```

**Key settings to customize:**

```bash
# Instance configuration
export TF_VAR_instance_type="c7i.4xlarge"  # Adjust size as needed
export TF_VAR_vm_count=1                   # Start with 1 for testing

# AMI configuration - customize for your AMI source
AMI_OWNER="679593333241"                   # Your AMI owner ID
AMI_FILTER='cloudimg-oel810-lvm-*'         # Your AMI naming pattern

# Cost optimization
export TF_VAR_use_spot_instances="true"    # Use spot instances for savings

# Security
export TF_VAR_allow_remote_ssh_access="false"  # Keep restrictive for security

# Monitoring
export TF_VAR_enable_monitoring="true"     # Enable CloudWatch monitoring
```

### Backend Configuration (Optional)

**Default**: Local state files (no setup required)

**For team collaboration**, you have two options:

#### Option 1: Quick S3 Backend (Recommended)
Use the `tis3` alias for instant S3 backend:
```bash
# Initialize with S3 backend (requires S3 bucket setup)
tis3
```

#### Option 2: Permanent S3 Backend
Edit `backend.tf` and uncomment the S3 configuration:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "environments/my-dev-env/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```
Then: `terraform init -migrate-state`

## Step 3: Initialize Environment

### Load Environment Variables

```bash
# If using direnv (recommended)
direnv allow .

# If not using direnv, source manually
source .envrc
```

You should see the environment status display:

```
======================================================================
🔧 Environment: my-dev-env | Status: 🔴 UNINITIALIZED
----------------------------------------------------------------------
 - AMI Name: cloudimg-oel810-lvm-02-01-2025-prod-v1.2.3
 - AMI Description: Oracle Linux 8.10 with Cloudberry Database
 - AMI ID: ami-0abcd1234efgh5678
 - Region: us-west-2
 - Instance Type: c7i.4xlarge
 - VM Count: 1
 - Default User: ec2-user
 - User IP: 203.0.113.1
 - Spot Instances: 🟢 ENABLED
 - SSH Access: 🔒 RESTRICTED (203.0.113.1/32)
 - Monitoring: 📊 ENABLED
======================================================================
```

### Initialize Terraform

```bash
# Option 1: Local backend (default)
terraform init
# or use alias: ti

# Option 2: S3 backend (team collaboration)
tis3
```

## Step 4: Plan and Deploy

### Review the Plan

```bash
# See what will be created
terraform plan
```

Expected resources:
- VPC with public subnet
- Security groups
- EC2 instances (1 by default)
- SSH key pair
- IAM roles and policies
- CloudWatch monitoring (if enabled)

### Deploy Infrastructure

```bash
# Deploy the infrastructure
terraform apply
```

Type `yes` when prompted. Deployment typically takes 5-10 minutes.

### Verify Deployment

After successful deployment, you'll see outputs:

```
instance_ips = [
  "54.123.45.67",
]
hostnames = [
  "cdw",
]
ssh_key = "my-dev-env_generated_key.pem"
```

## Step 5: Connect to Your Environment

### Wait for Instance Readiness

```bash
# Use the built-in wait function (from .env aliases)
lw
```

This will wait for SSH to become available.

### SSH into Your Instance

```bash
# SSH to the main instance
lssh

# Or use standard SSH
ssh -i my-dev-env_generated_key.pem ec2-user@54.123.45.67
```

### Setup gpadmin User (for Cloudberry Database)

```bash
# Copy SSH key to gpadmin user
lgw

# SSH as gpadmin
lgssh
```

## Step 6: Environment Management

### Check Instance Status

```bash
# View instance state
istate

# Get comprehensive environment info
iinfo
```

### Start/Stop Instances (Cost Savings)

```bash
# Stop instances when not in use
istop

# Start instances when needed
istart

# Check current status
istatus
```

### File Transfer

```bash
# Copy file to instance
lcopyto /path/to/local/file /remote/path

# Copy file from instance
lcopyfrom /remote/path /local/path

# For gpadmin user
lgcopyto /path/to/local/file /home/gpadmin/
```

## Step 7: Development Workflow

### VS Code Remote Development

```bash
# Open VS Code connected to the instance
icode

# Open specific directory
icode /home/gpadmin/cloudberry
```

### Monitor System Resources

```bash
# View system metrics
itop

# Check disk usage
idisk

# View system logs
ilogs
```

### Performance Testing

```bash
# Run performance tests (if available)
itest
```

## Cost Management

### Monitor Costs

Your environment uses several cost optimization features:

- **Spot Instances**: 60-90% savings on compute costs
- **Stop/Start**: Only pay when instances are running
- **Right-sizing**: Choose appropriate instance types

### Estimated Monthly Costs

**Single c7i.4xlarge instance:**
- **On-demand**: ~$350/month (if running 24/7)
- **Spot instance**: ~$35-140/month (depending on availability)
- **With stop/start**: ~$8-35/month (8 hours/day usage)

### Cost Optimization Tips

1. **Use spot instances** for development/testing
2. **Stop instances** when not in use (`istop`)
3. **Right-size instances** - start small and scale up if needed
4. **Monitor usage** through AWS Cost Explorer

## Cleanup

### Destroy Environment

When you're done with the environment:

```bash
# Destroy all resources
terraform destroy
```

Type `yes` when prompted. This will delete all AWS resources and stop billing.

### Backup State (Recommended)

Before destroying, backup your state file:

```bash
# Backup state file
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
```

### Cleanup Local Files

```bash
# Remove generated SSH keys and Terraform state
rm -f *.pem
rm -rf .terraform
rm -f terraform.tfstate*
```

## Troubleshooting

### Common Issues

**1. AMI Not Found**
```bash
# Check AMI availability
aws ec2 describe-images --region us-west-2 \
  --owners 679593333241 \
  --filters "Name=name,Values=cloudimg-oel810-lvm-*" \
  --query 'Images[*].[Name,ImageId,CreationDate]' \
  --output table
```

**2. SSH Connection Refused**
```bash
# Wait for instance to be fully ready
lw

# Check instance status
istate

# Verify security group allows your IP
echo "Your IP: $(curl -s https://api.ipify.org)"
```

**3. Terraform Backend Issues**
```bash
# Re-initialize backend
terraform init -reconfigure

# Check S3 bucket access
aws s3 ls s3://your-terraform-state-bucket/
```

**4. Spot Instance Interruption**
```bash
# Check if spot instance was terminated
istate

# If needed, redeploy
terraform apply
```

**5. Monitoring Not Working**
- Verify SES email address is verified in AWS console
- Check CloudWatch alarms in AWS console
- Review Lambda function logs

### Getting Help

- **Check logs**: Use `ilogs` to view system logs
- **Validate setup**: Re-run prerequisite checks from [PREREQUISITES.md](PREREQUISITES.md)
- **AWS Support**: Check AWS CloudTrail for API errors
- **Community**: Open an issue on GitHub

## Next Steps

### Development Environment Ready!

Your Cloudberry Database development environment is now ready. You can:

1. **Install Cloudberry Database** following the official documentation
2. **Configure your database cluster** using the provided instances
3. **Develop and test** your database applications
4. **Scale up** by increasing `vm_count` in `.envrc`

### Advanced Configuration

- **Multi-region deployments**: Create environments in different regions
- **Custom AMIs**: Build your own AMIs with pre-installed software
- **Monitoring dashboards**: Set up CloudWatch dashboards
- **Automated backups**: Configure automated database backups

### Contributing

Found an issue or want to contribute? See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Security Reminders

- 🔒 **Keep SSH access restricted** (`allow_remote_ssh_access = false`)
- 🔑 **Protect your SSH keys** - never commit them to version control
- 👀 **Monitor AWS costs** regularly
- 🛡️ **Review security groups** periodically
- 📊 **Use monitoring** to detect unusual activity
