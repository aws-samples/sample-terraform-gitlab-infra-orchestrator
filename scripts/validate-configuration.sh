#!/bin/bash

# Validation script for Terraform Orchestration Framework
# This script checks for placeholder values and configuration issues

set -e

echo "=========================================="
echo "Terraform Orchestration Framework"
echo "Configuration Validation Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Function to print error
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
    ((ERRORS++))
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    ((WARNINGS++))
}

# Function to print success
print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

echo ""
echo "1. Checking for placeholder values..."

# Check for common placeholder patterns
PLACEHOLDER_PATTERNS=(
    "SHARED_SERVICES_ACCOUNT_ID"
    "ORG_MASTER_ACCOUNT_ID"
    "DEV_ACCOUNT_ID"
    "STAGING_ACCOUNT_ID"
    "PRODUCTION_ACCOUNT_ID"
    "TERRAFORM_STATE_BUCKET"
    "TERRAFORM_LOCKS_TABLE"
    "YOUR_PROJECT_NAME"
    "YOUR_COMPANY"
    "YOUR_ORG"
    "YOUR_GITLAB_ORG"
    "GITLAB_HOST"
    "YOUR_VPC_NAME"
    "YOUR_SUBNET_NAME"
    "YOUR_KEYPAIR_NAME"
)

for pattern in "${PLACEHOLDER_PATTERNS[@]}"; do
    if grep -r "$pattern" . --exclude-dir=.git --exclude="*.sh" --exclude="*.md" >/dev/null 2>&1; then
        print_error "Found placeholder '$pattern' in configuration files"
        echo "  Files containing this placeholder:"
        grep -r "$pattern" . --exclude-dir=.git --exclude="*.sh" --exclude="*.md" | head -3
        echo ""
    fi
done

echo ""
echo "2. Checking required configuration files..."

# Required files
REQUIRED_FILES=(
    "main.tf"
    "variables.tf"
    "outputs.tf"
    "config/aws-accounts.json.example"
    "tfvars/dev-terraform.tfvars.example"
    "tfvars/stg-terraform.tfvars.example"
    "tfvars/prod-terraform.tfvars.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "Found required file: $file"
    else
        print_error "Missing required file: $file"
    fi
done

echo ""
echo "3. Checking Terraform syntax..."

if command -v terraform >/dev/null 2>&1; then
    if terraform validate >/dev/null 2>&1; then
        print_success "Terraform syntax validation passed"
    else
        print_error "Terraform syntax validation failed"
        terraform validate
    fi
else
    print_warning "Terraform not installed, skipping syntax validation"
fi

echo ""
echo "4. Checking for sensitive data..."

# Patterns that might indicate sensitive data
SENSITIVE_PATTERNS=(
    "AKIA[0-9A-Z]{16}"  # AWS Access Key ID pattern
    "aws_secret_access_key.*=.*[\"'][^\"']{20,}[\"']"  # AWS Secret Key pattern
    "password.*=.*[\"'][^\"']{8,}[\"']"  # Password pattern
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if grep -rE "$pattern" . --exclude-dir=.git --exclude="*.sh" >/dev/null 2>&1; then
        print_error "Potential sensitive data found matching pattern: $pattern"
        echo "  Please review and remove any hardcoded credentials"
    fi
done

echo ""
echo "5. Checking GitLab CI/CD configuration..."

if [[ -f ".gitlab-ci.yml" ]]; then
    print_success "Found GitLab CI/CD configuration"
    
    # Check for required variables in CI file
    CI_VARIABLES=(
        "TERRAFORM_STATE_BUCKET"
        "TERRAFORM_LOCKS_TABLE"
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
    )
    
    for var in "${CI_VARIABLES[@]}"; do
        if grep -q "$var" .gitlab-ci.yml; then
            print_success "CI/CD file references variable: $var"
        else
            print_warning "CI/CD file missing reference to variable: $var"
        fi
    done
else
    print_warning "GitLab CI/CD configuration file not found"
fi

echo ""
echo "6. Checking documentation..."

DOC_FILES=(
    "README.md"
    "CONTRIBUTING.md"
    "LICENSE"
    "SECURITY.md"
    "CHANGELOG.md"
    "docs/ARCHITECTURE.md"
    "docs/SECURITY-BEST-PRACTICES.md"
)

for doc in "${DOC_FILES[@]}"; do
    if [[ -f "$doc" ]]; then
        print_success "Found documentation: $doc"
    else
        print_warning "Missing documentation: $doc"
    fi
done

echo ""
echo "7. Checking for emojis in documentation..."

if grep -r "[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]" . --include="*.md" >/dev/null 2>&1; then
    print_warning "Found emojis in documentation files"
    echo "  Consider removing emojis for professional documentation"
else
    print_success "No emojis found in documentation"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [[ $ERRORS -eq 0 ]]; then
    print_success "No critical errors found!"
else
    print_error "Found $ERRORS critical error(s) that must be fixed"
fi

if [[ $WARNINGS -eq 0 ]]; then
    print_success "No warnings found!"
else
    print_warning "Found $WARNINGS warning(s) that should be reviewed"
fi

echo ""
echo "Next Steps:"
echo "1. Fix any critical errors before deployment"
echo "2. Review and address warnings as needed"
echo "3. Replace all placeholder values with actual values"
echo "4. Configure GitLab CI/CD variables"
echo "5. Test deployment in development environment"

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}Configuration validation completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Configuration validation failed. Please fix errors before proceeding.${NC}"
    exit 1
fi