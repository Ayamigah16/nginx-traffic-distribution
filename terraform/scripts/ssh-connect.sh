#!/bin/bash
#
# SSH Connection Script
# Helps you easily SSH into your servers
#

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to display header
display_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}║              SSH Connection Helper                            ║${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to check if infrastructure exists
check_infrastructure() {
    if ! terraform show &> /dev/null; then
        echo -e "${RED}No infrastructure found!${NC}"
        echo "Deploy first with: ./scripts/deploy.sh"
        exit 1
    fi
}

# Function to get Terraform output
get_terraform_output() {
    local output_name=$1
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Function to get tfvars value
get_tfvar() {
    local key=$1
    grep "^[[:space:]]*$key" terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1
}

# Function to retrieve server information
get_server_info() {
    LB_IP=$(get_terraform_output "load_balancer_public_ip")
    SERVER1_IP=$(get_terraform_output "server1_public_ip")
    SERVER2_IP=$(get_terraform_output "server2_public_ip")
    KEY_NAME=$(get_tfvar "key_name")
    
    if [ -z "$LB_IP" ]; then
        echo -e "${RED}Could not retrieve server IPs${NC}"
        exit 1
    fi
}

# Function to display menu
display_menu() {
    echo "Select server to connect to:"
    echo ""
    echo "  1) Load Balancer    ($LB_IP)"
    echo "  2) Backend Server 1 ($SERVER1_IP)"
    echo "  3) Backend Server 2 ($SERVER2_IP)"
    echo "  4) All servers (tmux)"
    echo "  5) Exit"
    echo ""
}

# Function to SSH to a single server
ssh_to_server() {
    local server_name=$1
    local server_ip=$2
    
    echo -e "${GREEN}Connecting to $server_name...${NC}"
    ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${server_ip}
}

# Function to SSH to all servers using tmux
ssh_to_all_servers() {
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}tmux is not installed!${NC}"
        echo "Install with: sudo apt install tmux"
        exit 1
    fi
    
    echo -e "${GREEN}Opening tmux with all servers...${NC}"
    
    # Create new tmux session
    tmux new-session -d -s nginx-servers
    
    # Split windows
    tmux split-window -v
    tmux split-window -h
    tmux select-pane -t 0
    
    # Send SSH commands to each pane
    tmux send-keys "ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${LB_IP}" C-m
    tmux select-pane -t 1
    tmux send-keys "ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${SERVER1_IP}" C-m
    tmux select-pane -t 2
    tmux send-keys "ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${SERVER2_IP}" C-m
    
    # Attach to session
    tmux attach-session -t nginx-servers
}

# Function to handle user choice
handle_choice() {
    local choice=$1
    
    case $choice in
        1)
            ssh_to_server "Load Balancer" "$LB_IP"
            ;;
        2)
            ssh_to_server "Backend Server 1" "$SERVER1_IP"
            ;;
        3)
            ssh_to_server "Backend Server 2" "$SERVER2_IP"
            ;;
        4)
            ssh_to_all_servers
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

display_header
check_infrastructure
get_server_info
display_menu

read -p "Enter choice [1-5]: " choice
handle_choice "$choice"
