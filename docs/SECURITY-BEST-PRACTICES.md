# Security Best Practices

Look, security is hard. We've made mistakes, learned from them, and want to share what we've figured out so you don't have to learn the hard way.

## The Multi-Account Strategy

**Why separate accounts?** Because when someone accidentally runs `terraform destroy` in the wrong terminal, you want it to only affect dev, not production. We learned this lesson the expensive way.

### Account Setup

Here's how we organize things:
- **Organization master**: Just for billing and management. Don't put workloads here.
- **Shared services**: Where we store Terraform state and logs. Think of it as the "control room."
- **Environment accounts**: One each for dev, staging, and production. Complete isolation.

### Cross-Account Roles

Instead of managing AWS keys for every account, we use cross-account roles. Much cleaner:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::ORG_MASTER_ACCOUNT:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "some-unique-id-you-choose"
      }
    }
  }]
}
```

**Pro tip**: Use different external IDs for each account. Makes it harder for someone to accidentally assume the wrong role.

## IAM: The Principle of Least Privilege

We used to give everyone admin access because it was easier. Don't do this. Here's what we do instead:

### Service Accounts for CI/CD

**Option 1: Temporary Credentials (Recommended)**
This is the gold standard. Credentials expire automatically, so if they get compromised, the damage is limited.

```bash
# Get temporary credentials that expire in 1 hour
aws sts assume-role \
  --role-arn "arn:aws:iam::ACCOUNT:role/GitLabRole" \
  --role-session-name "gitlab-$(date +%s)" \
  --duration-seconds 3600
```

**Option 2: Long-lived Keys (If you must)**
If temporary credentials don't work for your setup, at least rotate keys every 90 days. Set a calendar reminder.

### Permissions That Actually Work

Here's a role policy that gives Terraform what it needs without being overly permissive:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:PassRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    }
  ]
}
```

Notice the region restriction? That prevents someone from accidentally spinning up resources in expensive regions.

## Network Security

### VPC Design

We assume you already have VPCs set up (because networking teams usually handle this). But here are the basics:

- **Private subnets** for everything that doesn't need direct internet access
- **Public subnets** only for load balancers and NAT gateways
- **Security groups** as your primary firewall (NACLs are backup)

### Security Group Rules

Keep them tight. Here's what we do for web servers:

```hcl
# Only allow HTTPS from the load balancer
ingress {
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]
  description     = "HTTPS from ALB only"
}

# SSH only from the VPC (for management)
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # Your VPC CIDR
  description = "SSH from VPC"
}
```

**Never use 0.0.0.0/0 for SSH.** Just don't.

## Data Protection

### Encryption Everywhere

Turn on encryption for everything. It's 2024, there's no excuse not to:

- **EBS volumes**: Enable encryption by default in your AWS account settings
- **S3 buckets**: Use KMS encryption, not just AES-256
- **RDS**: Always encrypt databases, especially in production
- **In transit**: TLS 1.2 minimum for everything

### KMS Key Management

Don't use the default AWS keys for sensitive data. Create your own:

```hcl
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}
```

## Terraform State Security

This is critical. If someone gets access to your state files, they can see everything about your infrastructure.

### S3 Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
    dynamodb_table = "terraform-locks"
  }
}
```

### S3 Bucket Policy

Lock down your state bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::terraform-state-bucket",
        "arn:aws:s3:::terraform-state-bucket/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

This forces HTTPS for all access to the bucket.

## CI/CD Security

### GitLab Variables

Mark sensitive variables as both protected and masked:
- **Protected**: Only available on protected branches
- **Masked**: Hidden in job logs

### Pipeline Approval Process

For production deployments, always require manual approval:

```yaml
deploy:production:
  stage: deploy
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "production"
      when: manual  # Someone has to click the button
  script:
    - terraform apply -auto-approve
```

### Branch Protection

Set up branch protection rules in GitLab:
- Require merge request approvals for `staging` and `production` branches
- Prevent direct pushes to these branches
- Require status checks to pass

## Monitoring and Alerting

### What to Monitor

- **Failed authentication attempts**: Someone might be trying to break in
- **Privilege escalation**: New IAM roles or policy changes
- **Resource creation in unexpected regions**: Could indicate compromise
- **Large data transfers**: Might be data exfiltration

### CloudTrail Setup

Enable CloudTrail in all accounts and send logs to a central location:

```hcl
resource "aws_cloudtrail" "security_trail" {
  name           = "security-audit-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_bucket.bucket
  
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  kms_key_id = aws_kms_key.cloudtrail_key.arn
}
```

## Code Security

### Static Analysis

Run security scans on your Terraform code before deployment:

```bash
# Install tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Run scan
tfsec . --format json --out tfsec-report.json
```

### Pre-commit Hooks

Set up pre-commit hooks to catch issues early:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_validate
      - id: terraform_fmt
      - id: terraform_tfsec
```

## Incident Response

### When Things Go Wrong

1. **Don't panic.** Seriously, panicking makes everything worse.
2. **Isolate the problem.** Disable compromised accounts/keys immediately.
3. **Assess the damage.** Check CloudTrail logs to see what happened.
4. **Contain the threat.** Revoke access, change passwords, rotate keys.
5. **Document everything.** You'll need this for the post-mortem.

### Emergency Access Revocation

Keep this script handy:

```bash
#!/bin/bash
# emergency-revoke.sh
COMPROMISED_USER="gitlab-ci-user"

# Attach a deny-all policy
aws iam put-user-policy --user-name $COMPROMISED_USER \
    --policy-name EmergencyDenyAll \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*"
        }]
    }'

echo "Emergency access revocation completed for $COMPROMISED_USER"
```

## Common Mistakes We've Made

**Hardcoding secrets in code**: Use environment variables or AWS Systems Manager Parameter Store instead.

**Using the same IAM user everywhere**: Create separate users/roles for different purposes.

**Not rotating access keys**: Set up automatic rotation or at least calendar reminders.

**Overly permissive security groups**: Start restrictive and open up as needed, not the other way around.

**Not monitoring CloudTrail**: You can't respond to threats you don't know about.

**Storing state files locally**: Use remote state with encryption and locking.

## Security Checklist

Before you deploy to production:

- [ ] All placeholder account IDs replaced with real values
- [ ] Cross-account roles configured with least privilege
- [ ] Encryption enabled for all data at rest and in transit
- [ ] CloudTrail enabled in all accounts
- [ ] Security groups configured restrictively
- [ ] Branch protection rules enabled in GitLab
- [ ] Monitoring and alerting configured
- [ ] Incident response procedures documented
- [ ] Team trained on security procedures

## Resources That Actually Help

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/) - The official guide
- [Terraform Security Best Practices](https://learn.hashicorp.com/tutorials/terraform/security) - HashiCorp's recommendations
- [tfsec](https://github.com/aquasecurity/tfsec) - Static analysis for Terraform
- [Checkov](https://github.com/bridgecrewio/checkov) - Another good security scanner

## Final Thoughts

Security isn't a one-time setup. It's an ongoing process. Review these practices regularly, stay up to date with new threats, and don't be afraid to ask for help when you need it.

The goal isn't perfect security (that's impossible) - it's to make your infrastructure secure enough that attackers will go find an easier target.