# Changelog

All notable changes to the Cloudberry Development Environment Launcher will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### DBaaS Platform Module
- **New Module**: `modules/aws/dbaas-platform/` - Optional cloud-native infrastructure for database-as-a-service deployment
  - **Amazon EKS**: Kubernetes cluster (v1.34) with auto-scaling node groups (1-8 nodes)
  - **Amazon S3**: Two buckets (storage + backups) with encryption, versioning, and lifecycle policies
  - **Networking**: Private subnets across multiple AZs, NAT Gateway, and route tables
  - **Security**: IRSA-based IAM roles for secure S3 access without long-lived credentials
  - **Cost Optimization**: Spot instance support, auto-scaling, S3 lifecycle management (~$245-285/month)

- **OS Selector Enhancement**: Added interactive prompt for DBaaS platform deployment
  - New step in workflow: "Deploy DBaaS Platform Infrastructure?"
  - Shows cost estimate (~$250/month for full platform)
  - Automatically configures environment files with deployment flag
  - Seamless integration between database cluster and DBaaS platform

- **Template Updates**: Enhanced `multi-os-sample` environment template
  - Added conditional `dbaas_platform` module block in `main.tf`
  - Added 7 new variables for EKS and S3 configuration in `variables.tf`
  - Added 7 conditional outputs for DBaaS platform resources in `outputs.tf`
  - Updated `.envrc` template with `TF_VAR_deploy_dbaas_services` placeholder

#### Module Features
- **EKS Cluster**:
  - Configurable Kubernetes version (default: 1.34)
  - Auto-scaling node groups with spot instance support
  - Comprehensive logging (API, audit, authenticator, controller, scheduler)
  - OIDC provider for IAM Roles for Service Accounts (IRSA)

- **S3 Storage**:
  - Primary storage bucket with encryption and versioning
  - Backup bucket with separate retention policies
  - Lifecycle policies (30-day object expiration, 7-day version cleanup)
  - Public access completely blocked

- **Networking**:
  - Private subnets (10.0.10.0/24, 10.0.11.0/24) for EKS worker nodes
  - NAT Gateway for outbound internet access
  - Multi-AZ subnet distribution
  - Kubernetes-specific subnet tagging

- **Security**:
  - IRSA-based S3 access (token-based authentication, no static credentials)
  - Least privilege IAM policies scoped to specific buckets
  - Encrypted S3 buckets (AES256 server-side encryption)
  - Network isolation via private subnets

#### Documentation
- Comprehensive module README with architecture diagrams, usage examples, and troubleshooting
- Integration guide for DBaaS application deployment
- Cost optimization strategies and monthly cost estimates
- Post-deployment setup instructions (kubectl configuration, IRSA setup, testing)
- Updated main repository README with DBaaS platform information

### Changed
- **OS Selector**: Enhanced workflow from 6 to 7 steps to include DBaaS platform selection
- **Environment Creation**: Automatically configures `deploy_dbaas_services` variable based on user selection
- **Repository Structure**: Added `dbaas-platform` module under `modules/aws/`

### Technical Details
- **Module Files**: 10 Terraform files (main, variables, outputs, locals, eks, iam-eks, iam-s3, s3, networking, README)
- **Integration**: Seamlessly integrates with existing `database-cluster` module
- **Dependency Management**: Uses VPC and subnet from database cluster module
- **Terraform Version**: >= 1.0 required
- **AWS Provider**: ~> 5.0

### Use Cases
- Deploy database-as-a-service applications alongside Cloudberry databases
- Kubernetes-based service orchestration for database operations
- Cloud-native storage integration for data and backups
- Development and testing of DBaaS features and workflows
- Multi-tenant database service deployment

---

## Historical Changes

Previous changes were not formally tracked in a changelog. This file was created to document the DBaaS Platform Module addition and will track future changes going forward.
