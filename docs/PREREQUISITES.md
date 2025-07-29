# Prerequisites

Before using the Cloudberry Development Environment Launcher, ensure you have the following tools and configurations in place.

## Required Tools

### 1. **Terraform** (>= 1.0)

**macOS (Homebrew):**
```bash
brew install terraform
```

**Linux:**
```bash
# Download and install latest version
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
```

**Windows:**
Download from [terraform.io/downloads](https://www.terraform.io/downloads.html)

### 2. **AWS CLI v2**

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download from [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### 3. **direnv** (Recommended)

Automatically loads environment variables from `.envrc` files.

**macOS:**
```bash
brew install direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install direnv

# Add to shell profile
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc
```

### 4. **jq** (JSON processor)

Required by `.envrc` for AMI discovery and status display.

**macOS:**
```bash
brew install jq
```

**Linux:**
```bash
sudo apt-get install jq
```

**Windows:**
Download from [stedolan.github.io/jq](https://stedolan.github.io/jq/)

### 5. **Additional Utilities**

**macOS/Linux:**
```bash
# For SSH connectivity testing
# Usually pre-installed, verify with:
which nc curl ssh
```

## AWS Configuration

### 1. **AWS Account Requirements**

You need an AWS account with the following permissions:

- **EC2 Full Access** (or specific permissions listed below)
- **VPC Management**
- **IAM Role Creation**
- **S3 Access** (for Terraform state)
- **CloudWatch** (if monitoring enabled)
- **SES** (if email alerts enabled)

### 2. **Required AWS Permissions**

Minimum required permissions for the service account:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:PassRole",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DeleteAlarms",
                "sns:CreateTopic",
                "sns:DeleteTopic",
                "sns:Subscribe",
                "sns:Unsubscribe",
                "sqs:CreateQueue",
                "sqs:DeleteQueue",
                "sqs:GetQueueAttributes",
                "sqs:SetQueueAttributes",
                "lambda:CreateFunction",
                "lambda:DeleteFunction",
                "lambda:UpdateFunctionCode",
                "ses:SendEmail",
                "ses:VerifyEmailIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. **AWS SSO Setup**

This repository assumes AWS SSO configuration. Set up your AWS SSO:

```bash
# Configure AWS SSO (one-time setup)
aws configure sso

# Example configuration:
# SSO start URL: https://your-org.awsapps.com/start
# SSO region: us-east-1
# Account ID: 123456789012
# Role name: AdministratorAccess
# CLI default client region: us-west-2
# CLI default output format: json
# CLI profile name: your-profile-name
```

### 4. **Terraform Backend** (Optional)

**By default, Terraform uses local state files** - no additional setup required!

**For team collaboration**, you can optionally configure S3 backend:

1. **S3 Bucket**: Create your own bucket for shared state
2. **DynamoDB Table**: `terraform-lock` (for state locking)
3. **Update backend.tf**: Uncomment S3 configuration

**S3 Backend Setup (Optional):**
```bash
# Create S3 bucket for shared Terraform state
aws s3 mb s3://your-terraform-state-bucket --region us-west-2

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-west-2

# Migrate existing local state to S3
terraform init -migrate-state
```

## Verification

### Test Your Setup

Run these commands to verify your setup:

```bash
# 1. Check tool versions
terraform version
aws --version
direnv version
jq --version

# 2. Test AWS access
aws sts get-caller-identity

# 3. Test AMI discovery
aws ec2 describe-images --region us-west-2 \
  --owners 679593333241 \
  --filters "Name=name,Values=cloudimg-oel810-lvm-*" \
  --query 'Images[0].[Name,ImageId]' \
  --output text

# 4. Test S3 access (only if using S3 backend)
# aws s3 ls s3://your-terraform-state-bucket/
```

### Expected Output

If everything is configured correctly:
- `terraform version` shows >= 1.0
- `aws sts get-caller-identity` shows your AWS account details  
- AMI discovery returns an AMI name and ID
- S3 bucket is accessible (only if using S3 backend)

## Troubleshooting

### Common Issues

**1. AWS SSO Token Expired**
```bash
aws sso login --sso-session your-sso-session
```

**2. direnv Not Loading .envrc**  
```bash
# In your environment directory
direnv allow .
```

**3. AMI Not Found**
- Check AMI_OWNER and AMI_FILTER in `.envrc`
- Verify region matches AMI availability
- Ensure AWS credentials have EC2 permissions

**4. S3 Backend Access Denied**
- Verify S3 bucket exists and is accessible
- Check IAM permissions for S3 operations
- Ensure bucket region matches configuration

**5. Terraform State Lock Issues**
```bash
# If needed, force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Security Considerations

- **Never commit AWS credentials** to version control
- **Use AWS SSO** instead of long-term access keys
- **Enable MFA** on your AWS account
- **Regularly rotate credentials**
- **Review IAM permissions** - use least privilege principle
- **Monitor AWS CloudTrail** for unexpected activity

## Next Steps

Once prerequisites are installed and configured, proceed to [Getting Started](GETTING-STARTED.md) for your first deployment.