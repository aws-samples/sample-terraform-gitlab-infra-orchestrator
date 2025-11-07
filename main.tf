# Terraform Infrastructure Orchestrator - Main Configuration
# This file orchestrates multiple base modules and is environment-agnostic

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for centralized state management
  # Initialize with: terraform init -backend-config=shared/backend-common.hcl
  backend "s3" {
    # Configuration will be provided via backend-config file
    # This enables centralized state management across all environments
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Cross-account assume role for deployment
  # Credential flow:
  # 1. Workflow uses org master account (ORG_MASTER_ACCOUNT_ID) credentials  // Your organization master account
  # 2. Backend operations: workflow assumes shared services account (SHARED_SERVICES_ACCOUNT_ID) role for state/locking  // Your shared services account
  # 3. Provider operations: provider assumes target deployment account role (if different from org master)
  dynamic "assume_role" {
    for_each = var.account_id != null && var.account_id != "" && var.account_id != var.org_master_account_id ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${var.cross_account_role_name}"
      session_name = "terraform-deployment-${var.environment}"
    }
  }

  # Ensure proper credential handling
  skip_credentials_validation = false
  skip_metadata_api_check     = false
  skip_region_validation      = false

  default_tags {
    tags = merge(var.common_tags, {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "terraform"
      Workspace     = terraform.workspace
      OrgMaster     = var.org_master_account_id
      TargetAccount = var.account_id
    })
  }
}

# ALB Module - Application Load Balancer
module "alb" {
  source = "git::https://code.aws.dev/personal_projects/alias_s/sunrajam/tf-alb-base-module.git?ref=v1.0.0"

  for_each = var.alb_spec

  # Required: VPC name (must match Name tag on your VPC)
  vpc_name = each.value.vpc_name

  # Optional: Basic ALB settings
  http_enabled                            = each.value.http_enabled
  https_enabled                           = each.value.https_enabled
  alb_access_logs_s3_bucket_force_destroy = true

  # Optional: Certificate for HTTPS (uncomment if needed)
  # certificate_arn = each.value.certificate_arn

  # Optional: Naming context
  namespace   = each.key
  environment = var.environment
  name        = each.value.name
}

# EC2 Module - Elastic Compute Cloud instances
module "ec2_instance" {
  source   = "git::https://code.aws.dev/personal_projects/alias_s/sunrajam/ec2-base-module.git?ref=v1.0.0"
  for_each = var.ec2_spec

  name_prefix   = each.key
  vpc_name      = each.value.vpc_name
  environment   = var.environment
  account_id    = var.account_id
  instance_type = try(each.value.instance_type, "t3.small")
  key_name      = try(each.value.key_name, null)
  subnet_name   = try(each.value.subnet_name, null)

  # Use AMI name (required)
  ami_name = each.value.ami_name

  # OS-specific configurations
  root_volume_size       = try(each.value.root_volume_size, try(each.value.os_type, "linux") == "windows" ? 50 : 20)
  additional_ebs_volumes = try(each.value.additional_ebs_volumes, [])

  # ALB Integration - Connect to ALB target groups
  enable_alb_integration = try(each.value.enable_alb_integration, false)
  alb_target_group_arns  = try(each.value.enable_alb_integration, false) ? [module.alb[each.value.alb_name].default_target_group_arn] : []

  # OS-specific security group rules
  ingress_rules = try(each.value.ingress_rules, [
    {
      from_port   = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      to_port     = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = try(each.value.os_type, "linux") == "windows" ? "RDP access from private networks" : "SSH access from private networks"
    }
  ])

  # OS-specific user data
  user_data = try(each.value.os_type, "linux") == "windows" ? base64encode(templatefile("${path.module}/userdata/userdata-windows.ps1", {
    environment = var.environment
    hostname    = each.key
    os_type     = "windows"
    })) : base64encode(templatefile("${path.module}/userdata/userdata-linux.sh", {
    environment = var.environment
    hostname    = each.key
    os_type     = try(each.value.os_type, "linux")
  }))

  # Use existing security group or create new one
  create_security_group = true

  tags = merge({
    TestType = "EC2-Base-Module"
    Purpose  = "Infrastructure-Orchestrator"
  }, try(each.value.tags, {}))
}
