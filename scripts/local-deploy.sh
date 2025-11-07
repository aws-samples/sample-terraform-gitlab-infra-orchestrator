#!/bin/bash

# Enterprise Terraform Orchestrator - Local Deployment Script
# This script allows local deployment and testing of the orchestrator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
ACTION="plan"
SKIP_SETUP=false
AUTO_APPROVE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enterprise Terraform Orchestrator - Local Deployment Script

OPTIONS:
    -e, --environment ENV    Target environment (dev, staging, production) [default: dev]
    -a, --action ACTION      Action to perform (setup, plan, apply, destroy) [default: plan]
    -s, --skip-setup        Skip backend setup (if already exists)
    -y, --auto-approve      Auto-approve terraform apply (use with caution)
    -h, --help              Show this help message

EXAMPLES:
    $0 -e dev -a plan                    # Plan infrastructure for dev environment
    $0 -e dev -a apply -y                # Apply infrastructure for dev environment with auto-approve
    $0 -e staging -a setup               # Setup backend for staging environment
    $0 -e production -a destroy          # Destroy production infrastructure (requires confirmation)

PREREQUISITES:
    - AWS CLI configured with appropriate credentials
    - Terraform >= 1.0 installed
    - jq installed for JSON processing
    - Proper AWS account access and IAM roles configured

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -s|--skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        -y|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or production."
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(setup|plan|apply|destroy)$ ]]; then
    print_error "Invalid action: $ACTION. Must be setup, plan, apply, or destroy."
    exit 1
fi

print_status "🚀 Enterprise Terraform Orchestrator - Local Deployment"
print_status "Environment: $ENVIRONMENT"
print_status "Action: $ACTION"
print_status "Skip Setup: $SKIP_SETUP"

# Check prerequisites
print_status "🔍 Checking prerequisites..."

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { print_error "Terraform is required but not installed. Aborting."; exit 1; }
command -v aws >/dev/null 2>&1 || { print_error "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { print_error "jq is required but not installed. Aborting."; exit 1; }

# Check Terraform version
TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
print_status "Terraform version: $TF_VERSION"

# Check AWS credentials
print_status "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials not configured or invalid. Please run 'aws configure' or set environment variables."
    exit 1
fi

CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
print_status "Current AWS Account: $CURRENT_ACCOUNT"
print_status "Current AWS User: $CURRENT_USER"

# Check if config file exists
if [ ! -f "config/aws-accounts.json" ]; then
    print_error "config/aws-accounts.json not found. Please create it from the example file."
    print_status "Run: cp config/aws-accounts.json.example config/aws-accounts.json"
    exit 1
fi

# Check if tfvars file exists
TFVARS_FILE="tfvars/${ENVIRONMENT}-terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
    print_error "$TFVARS_FILE not found. Please create it from the example file."
    print_status "Run: cp tfvars/${ENVIRONMENT}-terraform.tfvars.example $TFVARS_FILE"
    exit 1
fi

# Get account information
SHARED_SERVICES_ACCOUNT_ID=$(jq -r '.shared_services.account_id' config/aws-accounts.json)
TARGET_ACCOUNT_ID=$(grep -E '^account_id\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' ')

if [ "$SHARED_SERVICES_ACCOUNT_ID" = "null" ] || [ "$SHARED_SERVICES_ACCOUNT_ID" = "SHARED_SERVICES_ACCOUNT_ID" ]; then
    print_error "Shared services account ID not configured in config/aws-accounts.json"
    exit 1
fi

if [ "$TARGET_ACCOUNT_ID" = "null" ] || [[ "$TARGET_ACCOUNT_ID" =~ .*ACCOUNT_ID.* ]]; then
    print_error "Target account ID not configured in $TFVARS_FILE"
    exit 1
fi

print_status "🏛️ Shared Services Account: $SHARED_SERVICES_ACCOUNT_ID"
print_status "🎯 Target Account: $TARGET_ACCOUNT_ID"

# Function to setup backend
setup_backend() {
    print_status "🔧 Setting up backend resources..."
    
    # Save original credentials
    ORIGINAL_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    ORIGINAL_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
    ORIGINAL_AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
    
    # Assume role in shared services account
    SHARED_SERVICES_ROLE_ARN="arn:aws:iam::${SHARED_SERVICES_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
    
    print_status "🔐 Assuming role: $SHARED_SERVICES_ROLE_ARN"
    
    if SHARED_CREDENTIALS=$(aws sts assume-role \
        --role-arn "$SHARED_SERVICES_ROLE_ARN" \
        --role-session-name "local-backend-setup" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text 2>/dev/null); then
        
        export AWS_ACCESS_KEY_ID=$(echo $SHARED_CREDENTIALS | cut -d' ' -f1)
        export AWS_SECRET_ACCESS_KEY=$(echo $SHARED_CREDENTIALS | cut -d' ' -f2)
        export AWS_SESSION_TOKEN=$(echo $SHARED_CREDENTIALS | cut -d' ' -f3)
        print_success "Successfully assumed role in shared services account"
    else
        print_error "Failed to assume role in shared services account"
        print_error "Please check IAM role configuration and permissions"
        exit 1
    fi
    
    # Backend resource names
    COMMON_BUCKET_NAME="terraform-state-central-multi-env"
    COMMON_DYNAMODB_TABLE="terraform-state-locks-common"
    
    # Create S3 bucket
    print_status "📦 Setting up S3 bucket: $COMMON_BUCKET_NAME"
    if aws s3api head-bucket --bucket "$COMMON_BUCKET_NAME" 2>/dev/null; then
        print_success "S3 bucket already exists"
    else
        print_status "Creating S3 bucket..."
        aws s3api create-bucket --bucket "$COMMON_BUCKET_NAME" --region us-east-1
        aws s3api put-bucket-versioning --bucket "$COMMON_BUCKET_NAME" --versioning-configuration Status=Enabled
        aws s3api put-bucket-encryption --bucket "$COMMON_BUCKET_NAME" --server-side-encryption-configuration '{
          "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }]
        }'
        aws s3api put-public-access-block --bucket "$COMMON_BUCKET_NAME" --public-access-block-configuration \
          "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
        print_success "S3 bucket created and configured"
    fi
    
    # Create DynamoDB table
    print_status "🗄️ Setting up DynamoDB table: $COMMON_DYNAMODB_TABLE"
    if aws dynamodb describe-table --table-name "$COMMON_DYNAMODB_TABLE" 2>/dev/null; then
        print_success "DynamoDB table already exists"
    else
        print_status "Creating DynamoDB table..."
        aws dynamodb create-table \
          --table-name "$COMMON_DYNAMODB_TABLE" \
          --attribute-definitions AttributeName=LockID,AttributeType=S \
          --key-schema AttributeName=LockID,KeyType=HASH \
          --billing-mode PAY_PER_REQUEST \
          --sse-specification Enabled=true
        
        print_status "Waiting for DynamoDB table to become active..."
        aws dynamodb wait table-exists --table-name "$COMMON_DYNAMODB_TABLE"
        print_success "DynamoDB table created and active"
    fi
    
    # Create backend configuration
    cat > "backend-local.hcl" << EOF
bucket         = "${COMMON_BUCKET_NAME}"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "${COMMON_DYNAMODB_TABLE}"
encrypt        = true
workspace_key_prefix = "environments"

assume_role = {
  role_arn = "${SHARED_SERVICES_ROLE_ARN}"
  session_name = "local-terraform-${ENVIRONMENT}"
}

skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5
EOF
    
    print_success "Backend configuration created: backend-local.hcl"
    
    # Restore original credentials for Terraform operations
    print_status "🔄 Restoring organization master credentials for Terraform operations"
    export AWS_ACCESS_KEY_ID="$ORIGINAL_AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$ORIGINAL_AWS_SECRET_ACCESS_KEY"
    export AWS_SESSION_TOKEN="$ORIGINAL_AWS_SESSION_TOKEN"
    
    print_success "Credentials restored - ready for Terraform operations"
}

# Function to initialize Terraform
init_terraform() {
    print_status "🔧 Initializing Terraform..."
    
    if [ ! -f "backend-local.hcl" ]; then
        print_error "Backend configuration not found. Run setup first."
        exit 1
    fi
    
    terraform init -backend-config=backend-local.hcl
    
    # Set up workspace
    print_status "🏢 Setting up workspace: $ENVIRONMENT"
    
    # List existing workspaces and check if our environment exists
    print_status "📋 Listing existing workspaces..."
    EXISTING_WORKSPACES=$(terraform workspace list)
    echo "$EXISTING_WORKSPACES"
    
    if echo "$EXISTING_WORKSPACES" | grep -q "^\s*${ENVIRONMENT}\s*$" || echo "$EXISTING_WORKSPACES" | grep -q "^\*\s*${ENVIRONMENT}\s*$"; then
        print_status "Workspace '$ENVIRONMENT' already exists, selecting it..."
        terraform workspace select $ENVIRONMENT
        print_success "Selected existing workspace: $ENVIRONMENT"
    else
        print_status "Creating new workspace: $ENVIRONMENT"
        if terraform workspace new $ENVIRONMENT; then
            print_success "Created new workspace: $ENVIRONMENT"
        else
            print_warning "Failed to create workspace, trying to select existing one..."
            terraform workspace select $ENVIRONMENT || {
                print_error "Failed to create or select workspace: $ENVIRONMENT"
                exit 1
            }
        fi
    fi
    
    print_status "📋 Current workspace: $(terraform workspace show)"
}

# Function to plan infrastructure
plan_infrastructure() {
    print_status "📋 Planning infrastructure for $ENVIRONMENT environment..."
    
    terraform plan -var-file="$TFVARS_FILE" -out=tfplan-local
    
    print_success "Infrastructure plan completed"
    print_status "Plan saved to: tfplan-local"
    print_status "Review the plan above before applying"
}

# Function to apply infrastructure
apply_infrastructure() {
    print_status "🚀 Applying infrastructure for $ENVIRONMENT environment..."
    
    if [ ! -f "tfplan-local" ]; then
        print_error "No plan file found. Run plan first."
        exit 1
    fi
    
    if [ "$AUTO_APPROVE" = true ]; then
        terraform apply tfplan-local
    else
        print_warning "About to apply infrastructure changes to $ENVIRONMENT environment"
        print_warning "Target Account: $TARGET_ACCOUNT_ID"
        read -p "Do you want to continue? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            terraform apply tfplan-local
        else
            print_status "Apply cancelled by user"
            exit 0
        fi
    fi
    
    print_success "Infrastructure applied successfully"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_error "⚠️  DESTRUCTIVE ACTION: About to destroy infrastructure in $ENVIRONMENT environment"
    print_error "Target Account: $TARGET_ACCOUNT_ID"
    print_error "This action cannot be undone!"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        print_error "Production environment destruction requires additional confirmation"
        read -p "Type 'destroy-production' to confirm: " -r
        if [[ $REPLY != "destroy-production" ]]; then
            print_status "Destroy cancelled - confirmation failed"
            exit 0
        fi
    fi
    
    read -p "Are you absolutely sure you want to destroy $ENVIRONMENT infrastructure? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        # Run ALB cleanup script if it exists
        if [ -f "scripts/cleanup-alb-logs.sh" ]; then
            print_status "🧹 Running ALB cleanup script..."
            chmod +x scripts/cleanup-alb-logs.sh
            ./scripts/cleanup-alb-logs.sh $ENVIRONMENT || true
        fi
        
        terraform destroy -var-file="$TFVARS_FILE" -auto-approve
        print_success "Infrastructure destroyed"
    else
        print_status "Destroy cancelled by user"
        exit 0
    fi
}

# Main execution logic
case $ACTION in
    setup)
        setup_backend
        ;;
    plan)
        if [ "$SKIP_SETUP" = false ]; then
            setup_backend
        fi
        init_terraform
        plan_infrastructure
        ;;
    apply)
        if [ "$SKIP_SETUP" = false ]; then
            setup_backend
        fi
        init_terraform
        plan_infrastructure
        apply_infrastructure
        ;;
    destroy)
        init_terraform
        destroy_infrastructure
        ;;
esac

print_success "🎉 Local deployment script completed successfully!"

# Cleanup
if [ -f "tfplan-local" ] && [ "$ACTION" = "apply" ]; then
    rm -f tfplan-local
    print_status "Cleaned up local plan file"
fi

print_status "💡 Next steps:"
case $ACTION in
    setup)
        print_status "  - Run: $0 -e $ENVIRONMENT -a plan"
        ;;
    plan)
        print_status "  - Review the plan output above"
        print_status "  - Run: $0 -e $ENVIRONMENT -a apply"
        ;;
    apply)
        print_status "  - Infrastructure is now deployed to $ENVIRONMENT"
        print_status "  - Check AWS console to verify resources"
        ;;
    destroy)
        print_status "  - Infrastructure has been destroyed"
        print_status "  - Verify in AWS console that resources are removed"
        ;;
esac