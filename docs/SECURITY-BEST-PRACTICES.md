# Security Best Practices for Terraform Orchestration Framework

This document outlines essential security practices for deploying and managing infrastructure using the Terraform Orchestration Framework in AWS multi-account environments.

## AWS Account Security

### Multi-Account Strategy

**Account Separation**
- Use dedicated AWS accounts for each environment (dev, staging, production)
- Implement a shared services account for centralized state management
- Maintain an organization master account for billing and management only
- Never deploy workloads directly in the organization master account

**Cross-Account Role Configuration**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ORG_MASTER_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id-per-account"
        }
      }
    }
  ]
}
```

**Account Hardening Checklist**
- [ ] Enable AWS CloudTrail in all accounts
- [ ] Configure AWS Config for compliance monitoring
- [ ] Set up AWS GuardDuty for threat detection
- [ ] Enable AWS Security Hub for centralized security findings
- [ ] Configure VPC Flow Logs for network monitoring
- [ ] Implement AWS Organizations SCPs (Service Control Policies)

## IAM Security

### Principle of Least Privilege

**Role-Based Access Control**
- Create specific IAM roles for each service and environment
- Avoid using wildcard permissions (`*`) in production
- Implement time-based access controls where possible
- Use IAM conditions to restrict access by IP, time, or MFA

**Example Terraform Deployment Role Policy**
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
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": "arn:aws:iam::*:role/terraform-*"
    }
  ]
}
```

**MFA Requirements**
- Enforce MFA for all human users
- Use hardware MFA devices for privileged accounts
- Implement MFA for sensitive operations via IAM conditions

### Temporary Credentials Implementation

**Why Temporary Credentials Are Recommended**
- **Time-limited exposure**: Credentials expire automatically (1-12 hours)
- **No credential storage**: No long-lived secrets in CI/CD variables
- **Automatic rotation**: New credentials for each pipeline execution
- **Enhanced audit trail**: Each session has unique identifiers
- **Reduced blast radius**: Compromised credentials have limited lifespan

**Implementation Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                 GitLab CI/CD Pipeline                       │
├─────────────────────────────────────────────────────────────┤
│  1. Pipeline starts with base AWS credentials               │
│  2. Assume role in organization master account              │
│  3. Get temporary credentials (AWS_SESSION_TOKEN)           │
│  4. Use temporary credentials for cross-account operations  │
│  5. Credentials auto-expire after pipeline completion       │
└─────────────────────────────────────────────────────────────┘
```

**Role Trust Policy for Temporary Credentials**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ORG_MASTER_ACCOUNT_ID:user/gitlab-ci-user"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id"
        },
        "IpAddress": {
          "aws:SourceIp": ["GITLAB_RUNNER_IP_RANGE"]
        }
      }
    }
  ]
}
```

### Service Account Management

**CI/CD Service Accounts**
- **Preferred**: Use temporary credentials with session tokens (auto-expiring)
- **Alternative**: Use dedicated service accounts with regular key rotation (every 90 days maximum)
- Store credentials securely in GitLab CI/CD variables (protected + masked)
- Never commit credentials to version control
- Implement role-based access with cross-account assume role patterns

**Temporary Credentials Strategy (Recommended)**
```bash
# Temporary credentials with session tokens (recommended approach)
#!/bin/bash

# This framework uses temporary credentials with session tokens for enhanced security
# No permanent access keys are stored - credentials are generated on-demand

# Example: Assume role to get temporary credentials
ROLE_ARN="arn:aws:iam::ORG_MASTER_ACCOUNT_ID:role/GitLabCIRole"
SESSION_NAME="gitlab-ci-session-$(date +%s)"

# Get temporary credentials (valid for 1-12 hours)
TEMP_CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --duration-seconds 3600 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

# Extract credentials
export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | cut -d' ' -f1)
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | cut -d' ' -f2)
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | cut -d' ' -f3)

echo "Temporary credentials obtained (expires in 1 hour)"
```

**Benefits of Temporary Credentials**:
- **Auto-expiring**: Credentials automatically expire (1-12 hours)
- **No rotation needed**: New credentials generated for each pipeline run
- **Reduced attack surface**: No long-lived credentials stored
- **Audit trail**: Each session is logged with unique session name

**Legacy Key Rotation (if using permanent keys)**
```bash
# Only use if temporary credentials are not possible
#!/bin/bash
OLD_KEY_ID="AKIAIOSFODNN7EXAMPLE"
NEW_KEY=$(aws iam create-access-key --user-name gitlab-ci-user)
# Update GitLab CI variables with new key
# Test deployment with new key
# Delete old key after successful validation
aws iam delete-access-key --access-key-id $OLD_KEY_ID --user-name gitlab-ci-user
```

## Infrastructure Security

### Network Security

**VPC Configuration**
- Use private subnets for all application resources
- Implement NAT Gateways for outbound internet access
- Configure Network ACLs as an additional security layer
- Enable VPC Flow Logs for traffic monitoring

**Security Group Best Practices**
```hcl
# Example: Restrictive security group
resource "aws_security_group" "web_servers" {
  name_prefix = "web-servers-"
  vpc_id      = var.vpc_id

  # Inbound rules - be specific
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTPS from ALB only"
  }

  # Outbound rules - restrict as needed
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for package updates"
  }

  tags = {
    Name = "web-servers-sg"
  }
}
```

### Data Protection

**Encryption at Rest**
- Enable EBS encryption by default
- Use KMS customer-managed keys for sensitive data
- Encrypt S3 buckets with appropriate key management
- Enable RDS encryption for database instances

**Encryption in Transit**
- Use TLS 1.2+ for all communications
- Implement SSL/TLS termination at load balancers
- Use VPC endpoints for AWS service communications
- Configure certificate management with AWS Certificate Manager

**Example KMS Key Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow use of the key for specific services",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "rds.amazonaws.com",
          "s3.amazonaws.com"
        ]
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

## Terraform State Security

### Backend Security

**S3 Backend Configuration**
```hcl
terraform {
  backend "s3" {
    bucket         = "secure-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
    dynamodb_table = "terraform-locks"
    
    # Security enhancements
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    skip_region_validation      = false
  }
}
```

**State File Protection**
- Enable S3 bucket versioning for state recovery
- Configure S3 bucket policies to restrict access
- Use separate state files per environment
- Implement state file backup and recovery procedures

**Example S3 Bucket Policy for State Files**
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
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::SHARED_SERVICES_ACCOUNT:role/TerraformStateRole"
        ]
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state-bucket/*"
    }
  ]
}
```

### State Locking

**DynamoDB Configuration**
- Use DynamoDB for state locking to prevent concurrent modifications
- Enable point-in-time recovery for the locks table
- Configure appropriate read/write capacity or use on-demand billing
- Monitor lock duration and implement alerting for stuck locks

## CI/CD Security

### Pipeline Security

**GitLab CI/CD Hardening**
- Use protected branches for production deployments
- Require manual approval for production changes
- Implement branch protection rules
- Use protected CI/CD variables for sensitive data

**Variable Security Configuration**
```yaml
# GitLab CI/CD Variables Configuration for Temporary Credentials
variables:
  # Protected: Only available on protected branches
  # Masked: Hidden in job logs
  
  # Temporary credentials (recommended approach)
  AWS_ACCESS_KEY_ID: 
    protected: true
    masked: true
    description: "Temporary access key from assume role"
  AWS_SECRET_ACCESS_KEY:
    protected: true
    masked: true
    description: "Temporary secret key from assume role"
  AWS_SESSION_TOKEN:
    protected: true
    masked: true
    description: "Session token for temporary credentials"
  
  # Configuration variables
  TERRAFORM_STATE_BUCKET:
    protected: true
    masked: false
  TERRAFORM_LOCKS_TABLE:
    protected: true
    masked: false
```

**Temporary Credentials in GitLab CI/CD**
```yaml
# Example job using temporary credentials
deploy:production:
  stage: deploy
  variables:
    # Temporary credentials are automatically available
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_SESSION_TOKEN: $AWS_SESSION_TOKEN
  before_script:
    - echo "Using temporary credentials with session token"
    - aws sts get-caller-identity  # Verify credentials
  script:
    - terraform apply -auto-approve
  environment:
    name: production
```

**Pipeline Approval Process**
```yaml
deploy:production:
  stage: deploy
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "production"
      when: manual  # Require manual approval
  before_script:
    - echo "Production deployment requires manual approval"
    - echo "Reviewer: Please verify all security requirements"
```

### Code Security

**Terraform Code Scanning**
- Implement static analysis tools (tfsec, Checkov, Terrascan)
- Scan for security misconfigurations before deployment
- Use pre-commit hooks for local validation
- Integrate security scanning into CI/CD pipeline

**Example Security Scanning Job**
```yaml
security_scan:
  stage: validate
  image: aquasec/tfsec:latest
  script:
    - tfsec . --format json --out tfsec-report.json
    - tfsec . --format junit --out tfsec-junit.xml
  artifacts:
    reports:
      junit: tfsec-junit.xml
    paths:
      - tfsec-report.json
  rules:
    - if: $CI_COMMIT_BRANCH
```

## Monitoring and Compliance

### Security Monitoring

**CloudTrail Configuration**
```hcl
resource "aws_cloudtrail" "security_trail" {
  name           = "security-audit-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_bucket.bucket
  
  # Security enhancements
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  # KMS encryption
  kms_key_id = aws_kms_key.cloudtrail_key.arn
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::terraform-state-bucket/*"]
    }
  }
}
```

**Security Alerting**
- Configure CloudWatch alarms for suspicious activities
- Set up SNS notifications for security events
- Monitor failed authentication attempts
- Alert on privilege escalation activities

### Compliance Framework

**Compliance Checklist**
- [ ] Implement resource tagging strategy for cost allocation
- [ ] Configure AWS Config rules for compliance monitoring
- [ ] Set up AWS Security Hub for centralized compliance dashboard
- [ ] Document security procedures and incident response plans
- [ ] Conduct regular security assessments and penetration testing
- [ ] Maintain audit logs for compliance requirements

**Required Tags for Compliance**
```hcl
locals {
  required_tags = {
    Environment   = var.environment
    Project       = var.project_name
    Owner         = var.team_name
    CostCenter    = var.cost_center
    Compliance    = var.compliance_framework
    DataClass     = var.data_classification
    BackupPolicy  = var.backup_required
    ManagedBy     = "terraform"
  }
}
```

## Security Tools and Automation

### Recommended Security Tools

**Static Analysis Tools**
- **tfsec**: Terraform security scanner
- **Checkov**: Infrastructure as code security scanner
- **Terrascan**: Policy as code scanner
- **Semgrep**: Custom rule-based security scanner

**Runtime Security**
- **AWS GuardDuty**: Threat detection service
- **AWS Security Hub**: Centralized security findings
- **AWS Config**: Configuration compliance monitoring
- **AWS Inspector**: Application security assessment

### Automated Security Testing

**Pre-deployment Security Checks**
```bash
#!/bin/bash
# security-check.sh - Run before deployment

echo "Running security validation..."

# Check for hardcoded secrets
if grep -r "AKIA\|aws_secret_access_key\|password" . --exclude-dir=.git; then
    echo "❌ Potential hardcoded credentials found"
    exit 1
fi

# Run Terraform security scan
tfsec . --minimum-severity HIGH
if [ $? -ne 0 ]; then
    echo "❌ High severity security issues found"
    exit 1
fi

# Validate IAM policies
for policy in policies/*.json; do
    aws iam simulate-principal-policy \
        --policy-source-arn "arn:aws:iam::ACCOUNT:role/test-role" \
        --policy-input-list "file://$policy" \
        --action-names "s3:GetObject" \
        --resource-arns "arn:aws:s3:::test-bucket/*"
done

echo "Security validation passed"
```

## Incident Response

### Security Incident Procedures

**Immediate Response Steps**
1. **Identify and Isolate**: Determine scope and isolate affected resources
2. **Assess Impact**: Evaluate data exposure and system compromise
3. **Contain Threat**: Implement immediate containment measures
4. **Notify Stakeholders**: Alert security team and management
5. **Document Everything**: Maintain detailed incident logs

**Emergency Access Revocation**
```bash
#!/bin/bash
# emergency-revoke.sh - Revoke compromised credentials

COMPROMISED_USER="gitlab-ci-user"
COMPROMISED_KEY_ID="AKIAIOSFODNN7EXAMPLE"

# Disable user
aws iam put-user-policy --user-name $COMPROMISED_USER \
    --policy-name DenyAllPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*"
        }]
    }'

# Delete access key
aws iam delete-access-key --user-name $COMPROMISED_USER --access-key-id $COMPROMISED_KEY_ID

echo "Emergency access revocation completed"
```

### Recovery Procedures

**Infrastructure Recovery**
1. **Assess Damage**: Review CloudTrail logs for unauthorized changes
2. **Restore from Backup**: Use Terraform state backups if needed
3. **Rebuild Compromised Resources**: Destroy and recreate affected infrastructure
4. **Update Security Controls**: Implement additional security measures
5. **Conduct Post-Incident Review**: Document lessons learned

## Security Resources

### AWS Security Documentation
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [AWS Organizations Security Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)

### Terraform Security Resources
- [Terraform Security Best Practices](https://learn.hashicorp.com/tutorials/terraform/security)
- [HashiCorp Security Model](https://www.hashicorp.com/security)

### Compliance Frameworks
- **SOC 2**: System and Organization Controls
- **ISO 27001**: Information Security Management
- **PCI DSS**: Payment Card Industry Data Security Standard
- **HIPAA**: Health Insurance Portability and Accountability Act

---

## Security Checklist Summary

**Before Deployment**
- [ ] All placeholder values replaced with actual account IDs
- [ ] IAM roles configured with least privilege access
- [ ] Cross-account trust relationships established
- [ ] Encryption enabled for all data at rest and in transit
- [ ] Security scanning tools integrated into CI/CD pipeline
- [ ] Network security groups configured restrictively
- [ ] CloudTrail enabled in all accounts
- [ ] Backup and recovery procedures documented

**During Operation**
- [ ] Regular security assessments conducted
- [ ] Access keys rotated according to schedule
- [ ] Security monitoring alerts configured
- [ ] Compliance requirements validated
- [ ] Incident response procedures tested
- [ ] Security training provided to team members

**Continuous Improvement**
- [ ] Security metrics tracked and reported
- [ ] Threat model updated regularly
- [ ] Security tools and processes evaluated
- [ ] Industry best practices adopted
- [ ] Security culture promoted within organization

---

**Remember**: Security is not a one-time setup but an ongoing process. Regularly review and update these practices as your infrastructure and threat landscape evolve.