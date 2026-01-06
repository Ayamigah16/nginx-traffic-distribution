#!/bin/bash
#
# Terraform Destroy Script
# Safely destroys all infrastructure resources
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
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                               ║${NC}"
    echo -e "${RED}║        Terraform Destroy - Infrastructure Cleanup            ║${NC}"
    echo -e "${RED}║                                                               ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to show warning
show_warning() {
    log_warning "This will destroy ALL infrastructure resources!"
    log_warning "This action CANNOT be undone!"
    echo ""
}

# Function to show current resources
show_resources() {
    log "Current resources:"
    echo ""
    terraform show | grep -E "resource|aws_instance|aws_vpc|aws_eip" || true
    echo ""
}

# Function to get user confirmation
get_confirmation() {
    read -p "Are you sure you want to destroy all resources? Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        log "Destroy cancelled"
        exit 0
    fi
}

# Function to get final confirmation
get_final_confirmation() {
    read -p "This is your last chance. Type 'destroy' to proceed: " confirm2
    if [ "$confirm2" != "destroy" ]; then
        log "Destroy cancelled"
        exit 0
    fi
}

# Function to create destroy plan
create_destroy_plan() {
    log "Creating destroy plan..."
    if terraform plan -destroy -out=destroy.tfplan; then
        log_success "Destroy plan created"
    else
        log_error "Destroy plan failed"
        exit 1
    fi
}

# Function to execute destroy
execute_destroy() {
    log "Destroying infrastructure..."
    if terraform apply destroy.tfplan; then
        log_success "Infrastructure destroyed successfully!"
        rm -f destroy.tfplan
    else
        log_error "Destroy failed"
        rm -f destroy.tfplan
        exit 1
    fi
}

# Function to display success message
display_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              All Resources Destroyed Successfully!            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Cleanup complete!"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

display_header
show_warning
show_resources

get_confirmation
echo ""

get_final_confirmation
echo ""

create_destroy_plan
echo ""

execute_destroy
display_success
