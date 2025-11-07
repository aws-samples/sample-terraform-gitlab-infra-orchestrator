# Terraform Variables Configuration

This directory contains environment-specific Terraform variable files for the Smart Infrastructure Orchestrator.

## File Structure

```
tfvars/
├── README.md                           # This file
├── dev-terraform.tfvars.example        # Development environment template
├── stg-terraform.tfvars.example        # Staging environment template
└── prod-terraform.tfvars.example       # Production environment template
```

## Quick Setup

### Step 1: Create Environment Files

```bash
# Copy example files to create your configurations
cp dev-terraform.tfvars.example dev-terraform.tfvars
cp stg-terraform.tfvars.example stg-terraform.tfvars
cp prod-terraform.tfvars.example prod-terraform.tfvars
```

### Step 2: Configure Account IDs

Update each file with your AWS account information:

```hcl
# Replace these placeholders with your actual account IDs
account_id            = "123456789012"  # Your environment account
org_master_account_id = "123456789010"  # Your organization master account
```

### Step 3: Update Infrastructure Settings

Configure your VPC and networking:

```hcl
# Update with your actual VPC and subnet names
alb_spec = {
  linux-alb = {
    vpc_name = "your-vpc-name"          # Must exist in target account
    # ...
  }
}

ec2_spec = {
  "linux-webserver" = {
    vpc_name    = "your-vpc-name"       # Must match ALB VPC
    subnet_name = "your-subnet-name"    # Must exist in VPC
    key_name    = "your-keypair-name"   # Must exist in account
    # ...
  }
}
```

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_name` | Name of your project | `"smart-terraform-orchestrator"` |
| `account_id` | Target AWS account ID | `"123456789012"` |
| `org_master_account_id` | Organization master account | `"123456789010"` |
| `aws_region` | AWS region for deployment | `"us-east-1"` |
| `environment` | Environment name | `"dev"`, `"staging"`, `"production"` |

## Security Best Practices

### Network Security
```hcl
# Use VPC CIDR blocks instead of 0.0.0.0/0
ingress_rules = [
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR only
    description = "HTTP from VPC (ALB)"
  }
]
```

### Storage Security
```hcl
# Always encrypt additional volumes
additional_ebs_volumes = [
  {
    device_name = "/dev/sdf"
    size        = 100
    type        = "gp3"
    encrypted   = true  # Always enable encryption
  }
]
```

## Important Security Notes

### What NOT to Commit
- **Never commit actual `.tfvars` files** to version control
- **Never include sensitive data** like passwords or keys
- **Never use hardcoded account IDs** in shared code

### What to Use Instead
- **GitLab CI/CD Variables** for sensitive configuration
- **AWS Systems Manager Parameter Store** for secrets
- **Environment-specific branches** for configuration management

---

**Pro Tip**: Start with the development environment to validate your configuration before promoting to staging and production.