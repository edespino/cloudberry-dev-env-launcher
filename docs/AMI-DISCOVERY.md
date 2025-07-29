# Dynamic AMI Discovery

The Cloudberry Development Environment Launcher features intelligent AMI discovery that automatically selects the latest available AMI matching your criteria, eliminating the need for manual AMI ID management.

## How It Works

### 1. Configuration

AMI discovery is configured in your environment's `.envrc` file:

```bash
# AMI configuration for Oracle Linux 8.10
AMI_OWNER="679593333241"
AMI_FILTER='cloudimg-oel810-lvm-02-01-2025-prod-*'
```

### 2. Automatic Discovery

When you enter the environment directory (with `direnv` installed), the system automatically:

```bash
# Fetch latest AMI matching the criteria
latest_ami=$(aws ec2 describe-images --region $TF_VAR_region \
 --owners $AMI_OWNER \
 --filters "Name=name,Values=$AMI_FILTER" \
 --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
 --output text)

# Validate the AMI exists
if [ "$latest_ami" = 'None' ]; then
 echo "Error: No AMI found matching specified criteria"
 return 1
fi

# Export for Terraform
export TF_VAR_ami=$latest_ami
```

### 3. Rich Status Display

The environment provides detailed information about the selected AMI:

```
======================================================================
🔧 Environment: ol810-sample-test | Status: 🟢 ACTIVE
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

## Benefits

### 🚀 **Always Current**
- Automatically uses the latest AMI version
- No manual intervention required for AMI updates
- Consistent deployments across team members

### 🛡️ **Error Prevention**
- Validates AMI exists before deployment
- Clear error messages if AMI lookup fails
- Prevents deployment failures due to invalid AMI IDs

### 👥 **Team Collaboration**
- Team members always get the same (latest) AMI
- No need to share AMI IDs in documentation
- Consistent environments across development/testing

### 🔍 **Full Visibility**
- Shows exactly which AMI is being used
- Displays AMI metadata for verification
- Status display includes all relevant information

## Customization

### Different OS Versions

To use different AMI patterns, modify the configuration in `.envrc`:

```bash
# For Ubuntu 22.04
AMI_OWNER="099720109477"  # Canonical
AMI_FILTER='ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*'

# For Amazon Linux 2023
AMI_OWNER="137112412989"  # Amazon
AMI_FILTER='al2023-ami-*-x86_64'

# For RHEL 9
AMI_OWNER="309956199498"  # Red Hat
AMI_FILTER='RHEL-9.*-x86_64-*'
```

### Multiple Environments

Each environment can have its own AMI configuration:

```
environments/
├── ubuntu-dev/
│   └── .envrc          # Ubuntu AMI config
├── rhel-prod/
│   └── .envrc          # RHEL AMI config
└── ol810-test/
    └── .envrc          # Oracle Linux AMI config
```

## Troubleshooting

### AMI Not Found

If you see "No AMI found matching specified criteria":

1. **Check AWS credentials**: Ensure you have proper AWS access
2. **Verify AMI owner**: Confirm the `AMI_OWNER` ID is correct
3. **Check filter pattern**: Ensure `AMI_FILTER` matches existing AMIs
4. **Validate region**: AMIs are region-specific

### Debug AMI Discovery

To manually test AMI discovery:

```bash
# Test the AMI query
aws ec2 describe-images --region us-west-2 \
 --owners 679593333241 \
 --filters "Name=name,Values=cloudimg-oel810-lvm-*" \
 --query 'Images[*].[Name,ImageId,CreationDate]' \
 --output table
```

### AWS CLI Requirements

Ensure you have:
- AWS CLI v2 installed
- Valid AWS credentials configured
- Appropriate EC2 permissions:
  - `ec2:DescribeImages`
  - `ec2:DescribeInstances` (for status checking)

## Integration with Terraform

The dynamic AMI discovery seamlessly integrates with Terraform through environment variables:

```hcl
# In your Terraform configuration
module "database_cluster" {
  source = "../../modules/aws/database-cluster"
  
  ami = var.ami  # Automatically set via TF_VAR_ami
  # ... other configuration
}
```

This approach ensures your Terraform configurations remain clean and portable while benefiting from intelligent AMI management.