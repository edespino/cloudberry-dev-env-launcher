# RDS PostgreSQL Integration for DBaaS Platform

## Overview

The DBaaS Platform module now includes support for Amazon RDS PostgreSQL as the backend database for storing DBaaS platform metadata and state. This provides a production-ready, managed database solution with automatic backups, monitoring, and high availability options.

## Features

- **Managed PostgreSQL Database**: AWS RDS PostgreSQL 16.10 (configurable)
- **Automatic Backups**: 7-day retention by default
- **Security**: Encrypted storage, private subnets, security group isolation
- **Monitoring**: CloudWatch logs, Performance Insights, Enhanced Monitoring
- **Secrets Management**: Credentials stored in AWS Secrets Manager
- **High Availability**: Optional Multi-AZ deployment
- **Auto-scaling Storage**: Automatic storage scaling from 20GB to 100GB (configurable)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       EKS Cluster                       │
│  ┌────────────────────────────────────────────────┐    │
│  │         DBaaS Application Pod                  │    │
│  │  (synxdb4-elastic-dbaas)                      │    │
│  │                                                │    │
│  │  - PostgreSQL JDBC Driver ✓                   │    │
│  │  - Liquibase Migrations ✓                     │    │
│  │  - Spring Boot 3.4.5 ✓                        │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │ PostgreSQL 5432                      │
│                   │ (Private Network)                    │
└───────────────────┼──────────────────────────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │  RDS Security Group  │
         │  (Port 5432)         │
         │  - EKS Cluster SG    │
         │  - EKS Private CIDR  │
         └──────────┬───────────┘
                    │
                    ▼
      ┌─────────────────────────────┐
      │   RDS PostgreSQL Instance   │
      │   - Private Subnets         │
      │   - Encrypted Storage       │
      │   - Automated Backups       │
      │   - Performance Insights    │
      └─────────────────────────────┘
```

## Configuration

### Terraform Variables

The module exposes comprehensive configuration options:

```hcl
# Database Instance
rds_engine_version       = "16.10"          # PostgreSQL version
rds_instance_class       = "db.t3.medium"  # Instance type
rds_database_name        = "dbaas"         # Database name
rds_master_username      = "dbaasadmin"    # Master user

# Storage
rds_allocated_storage     = 20             # Initial size (GB)
rds_max_allocated_storage = 100            # Max auto-scale (GB)
rds_storage_type          = "gp3"          # Storage type
rds_storage_encrypted     = true           # Encryption

# High Availability
rds_multi_az = false                       # Multi-AZ deployment

# Backups
rds_backup_retention_days = 7              # Backup retention
rds_backup_window         = "03:00-04:00"  # Backup window (UTC)
rds_maintenance_window    = "sun:04:00-sun:05:00"  # Maintenance

# Monitoring
rds_performance_insights_enabled = true    # Performance Insights

# Protection
rds_deletion_protection   = false          # Deletion protection
rds_skip_final_snapshot   = false          # Skip final snapshot

# Performance
rds_max_connections = "200"                # Max connections
```

### Example Usage

```hcl
module "dbaas_platform" {
  source = "../../../modules/aws/dbaas-platform"

  region           = "us-west-2"
  env_prefix       = "my-env"
  vpc_id           = module.database_cluster.vpc_id
  public_subnet_id = module.database_cluster.subnet_id

  # RDS Configuration
  rds_instance_class       = "db.t3.large"
  rds_multi_az             = true
  rds_deletion_protection  = true
  rds_backup_retention_days = 14
}
```

## Deployment

### 1. Deploy Infrastructure

```bash
cd environments/synx/rl9-hashdata-elastic
terraform apply
```

The RDS instance will be created with:
- Randomly generated secure password (32 characters)
- Security group allowing access from EKS cluster
- DB subnet group using EKS private subnets
- Secrets Manager secret with all connection details

### 2. Retrieve RDS Credentials

```bash
# Get individual values
terraform output -raw rds_endpoint
terraform output -raw rds_database_name
terraform output -raw rds_master_username
terraform output -raw rds_master_password  # Sensitive
terraform output -raw rds_jdbc_url

# Get Secrets Manager ARN (for applications that support it)
terraform output -raw rds_secrets_manager_arn
```

### 3. Configure DBaaS Application

#### Option A: Manual Configuration

Edit `example/dbaas-values.yaml`:

```yaml
applicationConfig:
  spring:
    datasource:
      url: jdbc:postgresql://my-env-dbaas-postgres.xxx.us-west-2.rds.amazonaws.com:5432/dbaas
      username: dbaasadmin
      password: <from terraform output>
      driver-class-name: org.postgresql.Driver
    liquibase:
      enabled: true
```

#### Option B: Automated Script

Use the provided helper script:

```bash
cd example
./populate-rds-credentials.sh
```

This creates `dbaas-values-with-rds.yaml` with credentials automatically populated.

### 4. Deploy DBaaS Application

```bash
helm upgrade --install dbaas <chart-path> \
  -f example/dbaas-values-with-rds.yaml \
  --namespace dbaas \
  --create-namespace
```

## Security

### Network Security

- **Private Subnets**: RDS instance deployed in private subnets (no internet access)
- **Security Groups**: Restricts access to EKS cluster only
- **Encrypted Storage**: Data encrypted at rest using AWS KMS
- **Encrypted Transit**: PostgreSQL SSL/TLS connections supported

### Credentials Management

- **Secrets Manager**: Credentials stored in AWS Secrets Manager
- **Random Password**: 32-character secure password auto-generated
- **IAM Authentication**: Can be enabled for additional security (future enhancement)

### Security Group Rules

```hcl
# Ingress: Only from EKS cluster
- Source: EKS Cluster Security Group
  Port: 5432
  Protocol: TCP

- Source: EKS Private Subnet CIDRs
  Port: 5432
  Protocol: TCP
```

## Monitoring and Operations

### CloudWatch Logs

The RDS instance exports logs to CloudWatch:
- PostgreSQL logs
- Upgrade logs

### Performance Insights

Enabled by default with 7-day retention:
- Query performance metrics
- Wait events analysis
- Top SQL queries

### Enhanced Monitoring

Enhanced monitoring enabled at 60-second intervals:
- OS-level metrics
- Process list
- Resource utilization

### Backups

- **Automated Backups**: Daily during backup window
- **Retention**: 7 days (configurable)
- **Final Snapshot**: Created before deletion (configurable)
- **Point-in-Time Recovery**: Enabled with automated backups

## Database Schema Management

The DBaaS application uses Liquibase for database schema migrations:

1. **Initial Deployment**: Liquibase creates all required tables
2. **Upgrades**: Liquibase applies pending migrations automatically
3. **Rollback**: Manual rollback supported via Liquibase

## High Availability

### Single-AZ (Default)

- **RTO**: 5-10 minutes (automatic instance replacement)
- **RPO**: 5 minutes (automated backups every 5 minutes)
- **Cost**: Lower cost option

### Multi-AZ (Optional)

Enable with `rds_multi_az = true`:

- **RTO**: 1-2 minutes (automatic failover)
- **RPO**: 0 (synchronous replication)
- **Cost**: ~2x single-AZ cost
- **Availability**: 99.95% SLA

## Cost Optimization

### Development/Testing

```hcl
rds_instance_class        = "db.t3.medium"
rds_multi_az              = false
rds_backup_retention_days = 1
rds_performance_insights_enabled = false
```

**Estimated Cost**: ~$50-70/month (us-west-2)

### Production

```hcl
rds_instance_class        = "db.r6g.xlarge"
rds_multi_az              = true
rds_backup_retention_days = 30
rds_performance_insights_enabled = true
```

**Estimated Cost**: ~$800-1000/month (us-west-2)

## Migration from H2 to PostgreSQL

### For New Deployments

Simply configure PostgreSQL from the start. Liquibase will create the schema.

### For Existing H2 Deployments

1. **Export H2 Data** (if needed):
   ```bash
   # Connect to pod with H2 database
   kubectl exec -it dbaas-pod -- /bin/bash
   # Export data using H2 tools or SQL dumps
   ```

2. **Deploy RDS**: Apply Terraform configuration

3. **Update Configuration**: Point to PostgreSQL

4. **Import Data** (if needed):
   ```bash
   psql -h <rds-endpoint> -U dbaasadmin -d dbaas < data.sql
   ```

5. **Restart Application**: Apply new Helm values

## Troubleshooting

### Connection Issues

1. **Check Security Group**:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <rds-sg-id>
   ```

2. **Verify Connectivity from EKS**:
   ```bash
   kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
     psql -h <rds-endpoint> -U dbaasadmin -d dbaas
   ```

3. **Check RDS Logs**:
   ```bash
   aws rds download-db-log-file-portion \
     --db-instance-identifier <instance-id> \
     --log-file-name error/postgresql.log
   ```

### Performance Issues

1. **Check Performance Insights**: AWS Console → RDS → Performance Insights

2. **Review Parameter Group**: Check `max_connections` and other settings

3. **Analyze Slow Queries**:
   ```sql
   SELECT * FROM pg_stat_statements
   ORDER BY total_exec_time DESC
   LIMIT 10;
   ```

### Schema Migration Failures

1. **Check Liquibase Logs**: In application pod logs

2. **Verify Database State**:
   ```sql
   SELECT * FROM databasechangelog
   ORDER BY dateexecuted DESC;
   ```

3. **Manual Rollback** (if needed):
   ```bash
   liquibase rollback-count 1
   ```

## Terraform Outputs

The module provides comprehensive outputs:

```hcl
# RDS Connection
output "rds_endpoint"           # host:port
output "rds_jdbc_url"          # Full JDBC URL
output "rds_database_name"     # Database name
output "rds_master_username"   # Master user
output "rds_master_password"   # Password (sensitive)

# Security
output "rds_security_group_id" # Security group ID

# Secrets Manager
output "rds_secrets_manager_arn"  # Secret ARN
output "rds_secrets_manager_name" # Secret name

# Summary
output "dbaas_platform_summary"   # Complete summary
```

## Future Enhancements

- [ ] IAM Database Authentication
- [ ] Read Replicas for scaling
- [ ] Aurora PostgreSQL Serverless option
- [ ] Automated schema migration testing
- [ ] Database connection pooling (PgBouncer)
- [ ] Automated backup testing and restoration

## References

- [AWS RDS PostgreSQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [Spring Boot Database Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/data.html#data.sql.datasource)
- [Liquibase Documentation](https://docs.liquibase.com/)
- [PostgreSQL JDBC Driver](https://jdbc.postgresql.org/)
