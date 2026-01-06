#!/bin/bash

# Script to start all Nginx servers for load balancing demonstration
# This script starts backend servers and the load balancer
#
# Features:
# - Fail-safe scripting with proper error handling
# - Comprehensive logging to file and console
# - Modular functions for maintainability
# - Input validation and sanity checks

# Strict error handling
set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'        # Better word splitting

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/start-servers-$(date +%Y%m%d-%H%M%S).log"
readonly NGINX_BIN="nginx"

# Server ports
readonly BACKEND1_PORT=8081
readonly BACKEND2_PORT=8082
readonly LB_PORT=80

# Trap errors and cleanup
trap 'error_handler $? $LINENO' ERR
trap 'cleanup' EXIT INT TERM

#######################################
# Logging Functions
#######################################

# Initialize logging
init_logging() {
    mkdir -p "${LOG_DIR}" || {
        echo -e "${RED}❌ Failed to create log directory${NC}" >&2
        exit 1
    }
    
    log_info "=== Script started at $(date) ==="
    log_info "Logging to: ${LOG_FILE}"
}

# Log functions
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "${LOG_FILE}" >&2
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" | tee -a "${LOG_FILE}"
}

#######################################
# Error Handling Functions
#######################################

# Error handler
error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Script failed with exit code ${exit_code} at line ${line_number}"
    echo -e "${RED}❌ An error occurred. Check log file: ${LOG_FILE}${NC}" >&2
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        log_info "=== Script completed successfully ==="
    else
        log_error "=== Script exited with errors (code: ${exit_code}) ==="
    fi
}

#######################################
# Validation Functions
#######################################

# Check if Nginx is installed
check_nginx_installed() {
    log_info "Checking if Nginx is installed..."
    if ! command -v "${NGINX_BIN}" &> /dev/null; then
        log_error "Nginx is not installed"
        echo -e "${RED}❌ Nginx is not installed!${NC}"
        echo -e "${YELLOW}Install it with: sudo apt install nginx${NC}"
        return 1
    fi
    log_success "Nginx is installed"
    return 0
}

# Check if configuration file exists
check_config_exists() {
    local config_file=$1
    if [[ ! -f "${config_file}" ]]; then
        log_error "Configuration file not found: ${config_file}"
        echo -e "${RED}❌ Configuration file not found: ${config_file}${NC}"
        return 1
    fi
    log_info "Configuration file exists: ${config_file}"
    return 0
}

# Check if running as root or with sudo
check_permissions() {
    log_info "Checking permissions..."
    if [[ ${EUID} -eq 0 ]]; then
        log_warning "Running as root user"
        return 0
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_warning "sudo requires password"
        echo -e "${YELLOW}⚠️  This script requires sudo privileges${NC}"
    fi
    return 0
}

#######################################
# Port Management Functions
#######################################

# Check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi ":${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Kill process using a specific port
kill_port() {
    local port=$1
    log_warning "Killing process on port ${port}"
    
    if sudo fuser -k "${port}/tcp" 2>/dev/null; then
        sleep 2
        log_info "Successfully freed port ${port}"
        return 0
    else
        log_warning "No process found on port ${port}"
        return 1
    fi
}

# Verify port is listening
verify_port_listening() {
    local port=$1
    local max_attempts=5
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if check_port "${port}"; then
            log_success "Port ${port} is now listening"
            return 0
        fi
        log_info "Waiting for port ${port} to start (attempt ${attempt}/${max_attempts})..."
        sleep 1
        ((attempt++))
    done
    
    log_error "Port ${port} failed to start after ${max_attempts} attempts"
    return 1
}

#######################################
# Nginx Management Functions
#######################################

# Stop all Nginx processes
stop_all_nginx() {
    log_info "Stopping all existing Nginx processes..."
    
    if pgrep -x nginx >/dev/null; then
        sudo killall nginx 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if pgrep -x nginx >/dev/null; then
            log_warning "Force killing remaining Nginx processes"
            sudo killall -9 nginx 2>/dev/null || true
            sleep 1
        fi
        log_success "All Nginx processes stopped"
    else
        log_info "No Nginx processes running"
    fi
}

# Test Nginx configuration
test_nginx_config() {
    local config=$1
    log_info "Testing configuration: ${config}"
    
    if sudo "${NGINX_BIN}" -c "${config}" -t 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "Configuration test passed: ${config}"
        return 0
    else
        log_error "Configuration test failed: ${config}"
        return 1
    fi
}

# Start an Nginx server
start_server() {
    local name=$1
    local port=$2
    local config=$3
    
    log_info "=== Starting ${name} on port ${port} ==="
    echo -e "${YELLOW}Starting ${name} on port ${port}...${NC}"
    
    # Validate configuration file exists
    if ! check_config_exists "${config}"; then
        return 1
    fi
    
    # Check if port is in use
    if check_port "${port}"; then
        log_warning "Port ${port} is already in use"
        echo -e "${RED}⚠️  Port ${port} is already in use. Freeing it...${NC}"
        kill_port "${port}" || {
            log_error "Failed to free port ${port}"
            return 1
        }
    fi
    
    # Test configuration before starting
    if ! test_nginx_config "${config}"; then
        echo -e "${RED}❌ Configuration test failed for ${name}${NC}"
        return 1
    fi
    
    # Start Nginx
    log_info "Launching Nginx with config: ${config}"
    if sudo "${NGINX_BIN}" -c "${config}"; then
        # Verify it's actually listening
        if verify_port_listening "${port}"; then
            log_success "${name} started successfully on port ${port}"
            echo -e "${GREEN}✓ ${name} started successfully on port ${port}${NC}"
            return 0
        else
            log_error "${name} started but not listening on port ${port}"
            echo -e "${RED}❌ ${name} failed to listen on port ${port}${NC}"
            return 1
        fi
    else
        log_error "Failed to start ${name}"
        echo -e "${RED}❌ Failed to start ${name}${NC}"
        return 1
    fi
}

#######################################
# User Interface Functions
#######################################

# Print header
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Nginx Load Balancing Demo - Starting Servers          ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Select load balancer algorithm
select_algorithm() {
    local choice
    
    echo -e "${BLUE}Select Load Balancer Algorithm:${NC}"
    echo "  1) Round Robin (default, equal distribution)"
    echo "  2) Least Connections (route to server with fewer connections)"
    echo "  3) IP Hash (same client IP → same server)"
    echo "  4) Weighted (75% to Server 1, 25% to Server 2)"
    echo "  5) Health Check (round robin with failover)"
    echo ""
    read -p "Enter your choice (1-5) [default: 1]: " choice
    choice=${choice:-1}
    
    case ${choice} in
        1)
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-round-robin.conf"
            LB_NAME="Round Robin Load Balancer"
            ;;
        2)
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-least-conn.conf"
            LB_NAME="Least Connections Load Balancer"
            ;;
        3)
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-ip-hash.conf"
            LB_NAME="IP Hash Load Balancer"
            ;;
        4)
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-weighted.conf"
            LB_NAME="Weighted Load Balancer"
            ;;
        5)
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-health-check.conf"
            LB_NAME="Health Check Load Balancer"
            ;;
        *)
            log_warning "Invalid choice: ${choice}. Using Round Robin."
            echo -e "${RED}Invalid choice. Using Round Robin.${NC}"
            LB_CONFIG="${PROJECT_ROOT}/load-balancer/nginx-round-robin.conf"
            LB_NAME="Round Robin Load Balancer"
            ;;
    esac
    
    log_info "Selected algorithm: ${LB_NAME}"
    echo ""
}

# Print success summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              All Servers Started Successfully!            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📍 Server URLs:${NC}"
    echo -e "  Backend Server 1: ${GREEN}http://localhost:${BACKEND1_PORT}${NC}"
    echo -e "  Backend Server 2: ${GREEN}http://localhost:${BACKEND2_PORT}${NC}"
    echo -e "  Load Balancer:    ${GREEN}http://localhost:${LB_PORT}${NC}"
    echo ""
    echo -e "${BLUE}🧪 Testing:${NC}"
    echo -e "  Test load balancer: ${YELLOW}./scripts/test-load-balancer.sh${NC}"
    echo -e "  Monitor traffic:    ${YELLOW}./scripts/monitor-traffic.sh${NC}"
    echo ""
    echo -e "${BLUE}📊 View logs:${NC}"
    echo -e "  Script log:  ${YELLOW}${LOG_FILE}${NC}"
    echo -e "  Nginx logs:  ${YELLOW}sudo tail -f /var/log/nginx/load_balancer_access.log${NC}"
    echo ""
    echo -e "${BLUE}🛑 Stop servers:${NC}"
    echo -e "  ${YELLOW}./scripts/stop-servers.sh${NC}"
    echo ""
}

#######################################
# Main Execution
#######################################

main() {
    # Initialize logging
    init_logging
    
    # Print header
    print_header
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    check_permissions || exit 1
    check_nginx_installed || exit 1
    echo -e "${GREEN}✓ Pre-flight checks passed${NC}"
    echo ""
    
    # Stop any existing Nginx processes
    stop_all_nginx
    echo ""
    
    # Start Backend Server 1
    if ! start_server "Backend Server 1" "${BACKEND1_PORT}" "${PROJECT_ROOT}/server1/nginx.conf"; then
        log_error "Failed to start Backend Server 1"
        exit 1
    fi
    echo ""
    
    # Start Backend Server 2
    if ! start_server "Backend Server 2" "${BACKEND2_PORT}" "${PROJECT_ROOT}/server2/nginx.conf"; then
        log_error "Failed to start Backend Server 2"
        exit 1
    fi
    echo ""
    
    # Select and start load balancer
    select_algorithm
    if ! start_server "${LB_NAME}" "${LB_PORT}" "${LB_CONFIG}"; then
        log_error "Failed to start Load Balancer"
        exit 1
    fi
    
    # Print success summary
    print_summary
    
    log_success "All servers started successfully!"
}

# Run main function
main "$@"
