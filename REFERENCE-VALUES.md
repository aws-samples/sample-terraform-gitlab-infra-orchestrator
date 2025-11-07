# Reference Values Guide

This document provides a comprehensive list of all placeholder values used throughout the Smart Terraform Infrastructure Orchestrator documentation and configuration files. Replace these placeholders with your actual values during setup.

## Organization & Project Values

### Project Configuration
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{YOUR_PROJECT_NAME}` | Name of your infrastructure project | `"smart-terraform-orchestrator"` |
| `{YOUR_COMPANY}` | Your company/organization name | `"acme-corp"` |
| `{YOUR_ORG}` | Your GitLab organization/group name | `"infrastructure-team"` |
| `{YOUR_GITLAB_ORG}` | Your GitLab organization for modules | `"terraform-modules"` |

### GitLab Configuration
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{GITLAB_HOST}` | Your GitLab instance hostname | `"gitlab.company.com"` |
| `{YOUR_ORG}` | Your GitLab organization/group | `"infrastructure-team"` |

## AWS Account Configuration

### Account IDs (12-digit numbers)
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `ORG_MASTER_ACCOUNT_ID` | AWS Organization master account | `"123456789010"` |
| `SHARED_SERVICES_ACCOUNT_ID` | Shared services account for state management | `"123456789011"` |
| `DEV_ACCOUNT_ID` | Development environment account | `"123456789012"` |
| `STAGING_ACCOUNT_ID` | Staging environment account | `"123456789013"` |
| `PRODUCTION_ACCOUNT_ID` | Production environment account | `"123456789014"` |

### AWS Resources
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{TERRAFORM_STATE_BUCKET}` | S3 bucket for Terraform state | `"your-terraform-state-bucket"` |
| `{TERRAFORM_LOCKS_TABLE}` | DynamoDB table for state locking | `"your-terraform-locks-table"` |
| `{AWS_DEFAULT_REGION}` | Default AWS region | `"us-east-1"` |

## Network Configuration

### VPC & Networking
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{YOUR_VPC_NAME}` | Name of your VPC | `"production-vpc"` |
| `{ENVIRONMENT}-vpc` | Environment-specific VPC naming | `"dev-vpc"`, `"staging-vpc"` |
| `{YOUR_SUBNET_NAME}` | Name of your subnet | `"private-subnet-1"` |
| `{VPC_CIDR}` | Your VPC CIDR block | `"10.0.0.0/16"` |

### Environment-Specific Examples
```hcl
# Development
vpc_name = "dev-vpc"
subnet_name = "dev-private-subnet-1"

# Staging  
vpc_name = "staging-vpc"
subnet_name = "staging-private-subnet-1"

# Production
vpc_name = "production-vpc"
subnet_name = "production-private-subnet-1"
```

## Security Configuration

### Key Pairs & Access
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{YOUR_KEYPAIR_NAME}` | EC2 key pair name | `"production-keypair"` |
| `{CROSS_ACCOUNT_ROLE}` | Cross-account role name | `"OrganizationAccountAccessRole"` |

### Environment-Specific Examples
```hcl
# Development
key_name = "dev-keypair"

# Staging
key_name = "staging-keypair"

# Production  
key_name = "production-keypair"
```

## Instance Configuration

### Instance Types by Environment
| Environment | Web Server | App Server | Database |
|-------------|------------|------------|----------|
| Development | `t3.small` | `t3.medium` | `t3.small` |
| Staging | `t3.medium` | `t3.large` | `t3.medium` |
| Production | `t3.large` | `t3.xlarge` | `r5.large` |

### Storage Configuration
| Environment | Root Volume | Data Volume | Backup Volume |
|-------------|-------------|-------------|---------------|
| Development | 20 GB | 50 GB | 20 GB |
| Staging | 30 GB | 100 GB | 50 GB |
| Production | 50 GB | 200 GB | 100 GB |

## Tagging Strategy

### Common Tags Template
```hcl
common_tags = {
  Owner       = "{YOUR_TEAM_NAME}"           # e.g., "infrastructure-team"
  Environment = "{ENVIRONMENT}"              # "dev", "staging", "production"
  Project     = "{YOUR_PROJECT_NAME}"        # e.g., "smart-terraform-orchestrator"
  CostCenter  = "{YOUR_COST_CENTER}"         # e.g., "engineering"
  Compliance  = "{COMPLIANCE_LEVEL}"         # e.g., "required", "optional"
  Backup      = "{BACKUP_POLICY}"            # e.g., "daily", "weekly"
}
```

### Environment-Specific Tag Examples
```hcl
# Development
common_tags = {
  Owner       = "infrastructure-team"
  Environment = "dev"
  Project     = "smart-terraform-orchestrator"
  CostCenter  = "engineering"
  Compliance  = "optional"
  Backup      = "weekly"
}

# Production
common_tags = {
  Owner       = "infrastructure-team"
  Environment = "production"
  Project     = "smart-terraform-orchestrator"
  CostCenter  = "engineering"
  Compliance  = "required"
  Backup      = "daily"
}
```

## GitLab CI/CD Variables

### Required Variables in GitLab Project Settings
| Variable Name | Description | Example Value | Protected | Masked |
|---------------|-------------|---------------|-----------|--------|
| `AWS_ACCESS_KEY_ID` | Organization master account access key | `AKIA...` | ✅ | ✅ |
| `AWS_SECRET_ACCESS_KEY` | Organization master account secret key | `wJalrXUt...` | ✅ | ✅ |
| `AWS_SESSION_TOKEN` | Session token (if using temporary creds) | `IQoJb3JpZ2...` | ✅ | ✅ |
| `GITLAB_API_TOKEN` | GitLab API token for MR creation | `glpat-...` | ✅ | ✅ |
| `TERRAFORM_STATE_BUCKET` | S3 bucket for state storage | `your-terraform-state-bucket` | ❌ | ❌ |
| `TERRAFORM_LOCKS_TABLE` | DynamoDB table for locking | `your-terraform-locks-table` | ❌ | ❌ |
| `AWS_DEFAULT_REGION` | Default AWS region | `us-east-1` | ❌ | ❌ |
| `GIT_BASE_URL` | GitLab base URL | `https://gitlab.company.com` | ❌ | ❌ |

## Configuration File Examples

### config/aws-accounts.json
```json
{
  "shared_services": {
    "account_id": "SHARED_SERVICES_ACCOUNT_ID",
    "description": "Centralized Terraform state management and logging",
    "region": "us-east-1",
    "resources": {
      "s3_bucket": "your-terraform-state-bucket",
      "dynamodb_table": "your-terraform-locks-table"
    }
  },
  "dev": {
    "account_id": "DEV_ACCOUNT_ID",
    "description": "Development environment for rapid iteration",
    "region": "us-east-1",
    "vpc_name": "dev-vpc",
    "deployment_type": "automatic"
  },
  "staging": {
    "account_id": "STAGING_ACCOUNT_ID", 
    "description": "Staging environment for pre-production testing",
    "region": "us-east-1",
    "vpc_name": "staging-vpc",
    "deployment_type": "manual_approval"
  },
  "production": {
    "account_id": "PRODUCTION_ACCOUNT_ID",
    "description": "Production environment for live workloads",
    "region": "us-east-1",
    "vpc_name": "production-vpc",
    "deployment_type": "manual_approval"
  },
  "organization": {
    "master_account_id": "ORG_MASTER_ACCOUNT_ID",
    "cross_account_role": "OrganizationAccountAccessRole",
    "description": "AWS Organization master account for billing and management"
  }
}
```

### tfvars/dev-terraform.tfvars
```hcl
# Project configuration
project_name = "{YOUR_PROJECT_NAME}"
gitlab_host  = "gitlab.{YOUR_COMPANY}.com"
gitlab_org   = "{YOUR_GITLAB_ORG}"

# AWS configuration
account_id            = "DEV_ACCOUNT_ID"
org_master_account_id = "ORG_MASTER_ACCOUNT_ID"
aws_region            = "us-east-1"
environment           = "dev"

# Infrastructure configuration
alb_spec = {
  linux-alb = {
    vpc_name = "{YOUR_VPC_NAME}"
    # ... other settings
  }
}

ec2_spec = {
  "linux-webserver" = {
    vpc_name    = "{YOUR_VPC_NAME}"
    key_name    = "{YOUR_KEYPAIR_NAME}"
    subnet_name = "{YOUR_SUBNET_NAME}"
    # ... other settings
  }
}
```

## Validation Checklist

Before deploying, ensure you've replaced all placeholders:

### Account Configuration
- [ ] All `*_ACCOUNT_ID` placeholders replaced with actual 12-digit account IDs
- [ ] `ORG_MASTER_ACCOUNT_ID` matches your organization master account
- [ ] Account IDs are valid and accessible

### Network Configuration  
- [ ] `{YOUR_VPC_NAME}` replaced with actual VPC names
- [ ] `{YOUR_SUBNET_NAME}` replaced with actual subnet names
- [ ] `{VPC_CIDR}` matches your actual VPC CIDR blocks
- [ ] VPCs and subnets exist in target AWS accounts

### Security Configuration
- [ ] `{YOUR_KEYPAIR_NAME}` replaced with actual key pair names
- [ ] Key pairs exist in all target AWS accounts
- [ ] Cross-account roles configured with proper trust policies

### Project Configuration
- [ ] `{YOUR_PROJECT_NAME}` replaced with your project name
- [ ] `{YOUR_COMPANY}` replaced with your organization name
- [ ] `{YOUR_GITLAB_ORG}` replaced with your GitLab organization
- [ ] GitLab URLs and paths are accessible

### GitLab CI/CD Variables
- [ ] All required variables configured in GitLab project settings
- [ ] Sensitive variables marked as protected and masked
- [ ] AWS credentials have appropriate permissions
- [ ] GitLab API token has required scopes

## Security Notes

### What NOT to Hardcode
- **AWS Account IDs** in shared code or documentation
- **Credentials** or access keys in any files
- **Internal hostnames** or IP addresses
- **Organization-specific names** in reusable templates

### What to Use Instead
- **Placeholder values** with clear naming conventions
- **Environment variables** for sensitive configuration
- **Configuration files** with `.example` templates
- **Documentation** explaining what values to replace

## Additional Resources

- [Main README](README.md) - Complete setup and usage guide
- [Setup Guide](SETUP.md) - Step-by-step configuration instructions
- [APG Pattern](APG-PATTERN.md) - AWS Prescriptive Guidance documentation
- [tfvars README](tfvars/README.md) - Variable configuration reference

---

**Pro Tip**: Use a consistent naming convention across all environments to make configuration management easier. For example: `{environment}-{resource-type}-{purpose}`