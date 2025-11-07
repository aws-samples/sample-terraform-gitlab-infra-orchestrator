# Cross-Account Backend Configuration with Role Assumption
# Use this when running Terraform from a different account than the shared services account
# This config tells Terraform to assume a role to access the backend resources

bucket         = "terraform-state-central-multi-env"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-common"
encrypt        = true

# Workspace configuration - creates separate state files per workspace
workspace_key_prefix = "environments"

# Backend configuration with cross-account role assumption
# This file is used by GitLab CI/CD for backend access
bucket         = "terraform-state-central-multi-env"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-common"
encrypt        = true
workspace_key_prefix = "environments"

# Assume role in shared services account to access backend
assume_role = {
  role_arn = "arn:aws:iam::SHARED_SERVICES_ACCOUNT_ID:role/OrganizationAccountAccessRole"  // Your shared services account ID
  session_name = "terraform-backend-access"
}

# Standard S3 backend settings
skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5