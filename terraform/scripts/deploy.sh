#!/bin/bash
#
# Terraform Deployment Script
# Automates the deployment of Nginx load balancing infrastructure
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✓ $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✗ $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ⚠ $1"
}

# Function to display header
display_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}║        Terraform Deployment - Nginx Load Balancing           ║${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to check command availability
check_command() {
    local cmd=$1
    local install_url=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed!"
        echo "Install it from: $install_url"
        return 1
    fi
    return 0
}

# Function to check all prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    local all_ok=true
    
    # Check Terraform
    if check_command "terraform" "https://www.terraform.io/downloads"; then
        log_success "Terraform found: $(terraform version | head -1)"
    else
        all_ok=false
    fi
    
    # Check AWS CLI
    if check_command "aws" "https://aws.amazon.com/cli/"; then
        log_success "AWS CLI found: $(aws --version)"
    else
        all_ok=false
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured!"
        echo "Run: aws configure"
        all_ok=false
    else
        log_success "AWS credentials configured"
    fi
    
    if [ "$all_ok" = false ]; then
        exit 1
    fi
}

# Function to ensure terraform.tfvars exists
ensure_tfvars() {
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found"
        echo ""
        read -p "Would you like to create it from the example? (y/n): " create_tfvars
        if [ "$create_tfvars" == "y" ]; then
            cp terraform.tfvars.example terraform.tfvars
            log_success "Created terraform.tfvars"
            log_warning "Please edit terraform.tfvars with your values before continuing"
            echo ""
            read -p "Press Enter when ready to continue..."
        else
            log_error "terraform.tfvars is required"
            exit 1
        fi
    fi
}

# Function to extract config value from tfvars
get_tfvar() {
    local key=$1
    grep "^[[:space:]]*$key" terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1
}

# Function to display configuration summary
display_config_summary() {
    log "Configuration Summary:"
    echo "────────────────────────────────────────────────────────────────"
    
    local region=$(get_tfvar "aws_region")
    local project=$(get_tfvar "project_name")
    local instance_type=$(get_tfvar "instance_type")
    local key_name=$(get_tfvar "key_name")
    local algorithm=$(get_tfvar "lb_algorithm")
    
    echo "  AWS Region:     ${region:-eu-west-1}"
    echo "  Project Name:   ${project:-nginx-lb-tutorial}"
    echo "  Instance Type:  ${instance_type:-t3.micro}"
    echo "  SSH Key:        ${key_name:-NOT SET}"
    echo "  LB Algorithm:   ${algorithm:-round_robin}"
    echo "────────────────────────────────────────────────────────────────"
}

# Function to confirm deployment
confirm_deployment() {
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log "Deployment cancelled"
        exit 0
    fi
}

# Function to initialize Terraform
terraform_init() {
    log "Initializing Terraform..."
    if terraform init; then
        log_success "Terraform initialized"
    else
        log_error "Terraform initialization failed"
        exit 1
    fi
}

# Function to validate Terraform configuration
terraform_validate() {
    log "Validating Terraform configuration..."
    if terraform validate; then
        log_success "Configuration is valid"
    else
        log_error "Configuration validation failed"
        exit 1
    fi
}

# Function to create Terraform plan
terraform_plan() {
    log "Creating deployment plan..."
    if terraform plan -out=tfplan; then
        log_success "Deployment plan created"
    else
        log_error "Deployment plan failed"
        exit 1
    fi
}

# Function to apply Terraform
terraform_apply() {
    log "Applying deployment..."
    echo "This may take 5-10 minutes..."
    echo ""
    
    if terraform apply tfplan; then
        log_success "Deployment completed successfully!"
        rm -f tfplan
    else
        log_error "Deployment failed"
        rm -f tfplan
        exit 1
    fi
}

# Function to display success message
display_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              Infrastructure Deployed Successfully!            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to display outputs and next steps
display_outputs() {
    log "Deployment Information:"
    echo ""
    terraform output
    
    echo ""
    log_success "Deployment complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Wait 2-3 minutes for servers to finish setup"
    echo "  2. Test the load balancer with the URL above"
    echo "  3. SSH into servers using the commands above"
    echo "  4. When done, run: ./scripts/destroy.sh"
    echo ""
}

    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

display_header
check_prerequisites
echo ""

ensure_tfvars
echo ""

display_config_summary
echo ""

confirm_deployment
echo ""

terraform_init
echo ""

terraform_validate
echo ""

terraform_plan
echo ""

terraform_apply

display_success
display_outputs
