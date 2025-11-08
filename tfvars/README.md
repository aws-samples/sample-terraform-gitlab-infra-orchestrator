# Terraform Variables Configuration

This directory contains the configuration files that tell Terraform what to deploy in each environment. Think of these as the "recipe cards" for your infrastructure.

## What's in Here

```
tfvars/
├── README.md                           # You are here
├── dev-terraform.tfvars.example        # Development template
├── stg-terraform.tfvars.example        # Staging template
└── prod-terraform.tfvars.example       # Production template
```

## Getting Started

### Step 1: Copy the Templates

```bash
# Make your own copies (don't edit the .example files directly)
cp dev-terraform.tfvars.example dev-terraform.tfvars
cp stg-terraform.tfvars.example stg-terraform.tfvars
cp prod-terraform.tfvars.example prod-terraform.tfvars
```

### Step 2: Fill in Your AWS Account IDs

This is the most important step. Open each file and replace the placeholder account IDs with your real ones:

```hcl
# Replace these with your actual 12-digit account IDs
account_id            = "123456789012"  # Your dev/staging/prod account
org_master_account_id = "123456789010"  # Your organization master account
```

**Pro tip**: Double-check these numbers. A typo here will cause authentication failures that are annoying to debug.

### Step 3: Update Your Network Settings

Make sure the VPC and subnet names match what you actually have in AWS:

```hcl
alb_spec = {
  linux-alb = {
    vpc_name = "my-production-vpc"  # Must exist in your AWS account
    # ...
  }
}

ec2_spec = {
  "linux-webserver" = {
    vpc_name    = "my-production-vpc"  # Must match the ALB VPC
    subnet_name = "private-subnet-1"  # Must exist in the VPC
    key_name    = "my-keypair"        # Must exist in the account
    # ...
  }
}
```

## Configuration Patterns

### Environment Sizing

We use different instance sizes for different environments:

**Development** (keep it cheap):
```hcl
ec2_spec = {
  "web-server" = {
    instance_type = "t3.small"
    # ...
  }
}
```

**Production** (performance matters):
```hcl
ec2_spec = {
  "web-server" = {
    instance_type = "t3.large"
    # ...
  }
}
```

### Security Configuration

Always use restrictive security groups:

```hcl
# Good: Only allow traffic from the VPC
ingress_rules = [
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Your VPC CIDR
    description = "HTTP from VPC only"
  }
]

# Bad: Don't do this
ingress_rules = [
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # The entire internet!
    description = "HTTP from anywhere"
  }
]
```

### Storage Configuration

Always encrypt additional volumes:

```hcl
additional_ebs_volumes = [
  {
    device_name = "/dev/sdf"
    size        = 100
    type        = "gp3"
    encrypted   = true  # Always do this
  }
]
```

## Common Variables Explained

### Required Variables

| Variable | What It Does | Example |
|----------|--------------|---------|
| `project_name` | Names your resources | `"my-awesome-app"` |
| `account_id` | Which AWS account to deploy to | `"123456789012"` |
| `aws_region` | Which AWS region to use | `"us-east-1"` |
| `environment` | Environment name for tagging | `"dev"`, `"staging"`, `"production"` |

### Infrastructure Variables

| Variable | What It Does | Example |
|----------|--------------|---------|
| `alb_spec` | Load balancer configuration | See examples below |
| `ec2_spec` | Server configuration | See examples below |
| `base_modules` | Which modules to use | Points to your GitLab repos |

## Real-World Examples

### Simple Web Application

```hcl
# Basic web app with load balancer
alb_spec = {
  web-alb = {
    vpc_name          = "production-vpc"
    http_enabled      = true
    https_enabled     = true
    health_check_path = "/health"
  }
}

ec2_spec = {
  web-server = {
    instance_type = "t3.medium"
    vpc_name      = "production-vpc"
    subnet_name   = "private-subnet-1"
    key_name      = "production-keypair"
    
    # Connect to the load balancer
    enable_alb_integration = true
    alb_name              = "web-alb"
  }
}
```

### API Backend

```hcl
# API server that doesn't need a load balancer
ec2_spec = {
  api-server = {
    instance_type = "t3.large"
    vpc_name      = "production-vpc"
    subnet_name   = "private-subnet-2"
    key_name      = "production-keypair"
    
    # No load balancer needed
    enable_alb_integration = false
    
    # Custom application port
    additional_security_group_rules = [
      {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
        description = "API port from VPC"
      }
    ]
  }
}
```

## Security Best Practices

### What NOT to Put in These Files

- **Passwords or secrets**: Use AWS Systems Manager Parameter Store instead
- **API keys**: Store them in GitLab CI/CD variables
- **Database passwords**: Let AWS generate them and store in Secrets Manager

### What to Use Instead

```hcl
# Good: Reference a parameter
database_password_parameter = "/myapp/prod/db/password"

# Bad: Hardcoded password
database_password = "super-secret-password"
```

### Tagging Strategy

Always tag your resources consistently:

```hcl
common_tags = {
  Environment = "production"
  Project     = "my-awesome-app"
  Owner       = "platform-team"
  CostCenter  = "engineering"
  Backup      = "daily"
}
```

## Troubleshooting

### "VPC not found" Errors

Make sure the VPC name in your config matches exactly what's in AWS:

```bash
# Check what VPCs you have
aws ec2 describe-vpcs --query 'Vpcs[*].Tags[?Key==`Name`].Value' --output text
```

### "Key pair not found" Errors

Verify your key pair exists in the right region:

```bash
# List key pairs in your region
aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text
```

### "Subnet not found" Errors

Check that your subnet exists and is in the right VPC:

```bash
# List subnets in a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-12345678" \
  --query 'Subnets[*].Tags[?Key==`Name`].Value' --output text
```

## Environment Differences

### Development
- Smaller instance types to save money
- Less strict security (for easier debugging)
- Shorter backup retention
- Single AZ deployment is fine

### Staging
- Production-like sizing
- Production-like security
- Used for load testing and final validation
- Multi-AZ for realistic testing

### Production
- Larger instance types for performance
- Strict security rules
- Long backup retention
- Multi-AZ for high availability
- Monitoring and alerting enabled

## Tips and Tricks

### Start Small
Begin with the simplest configuration that works, then add complexity as needed.

### Use Consistent Naming
Pick a naming convention and stick to it across all environments:
- `{environment}-{service}-{purpose}`
- Example: `prod-web-server`, `staging-api-backend`

### Test in Dev First
Always test configuration changes in dev before promoting to staging and production.

### Keep Environments Similar
The more your environments differ, the more likely you'll have environment-specific bugs.

### Document Your Choices
Add comments to explain why you chose specific configurations:

```hcl
ec2_spec = {
  web-server = {
    instance_type = "t3.large"  # Sized for 1000 concurrent users
    # ...
  }
}
```

## Getting Help

If you're stuck:
1. Check the main [README.md](../README.md) for setup instructions
2. Look at the [REFERENCE-VALUES.md](../REFERENCE-VALUES.md) for all placeholder values
3. Review the example files - they have working configurations
4. Check the GitLab CI/CD logs for specific error messages

Remember: these configuration files are the heart of your infrastructure. Take time to get them right, and your deployments will be much smoother.