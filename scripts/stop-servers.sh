#!/bin/bash

# Script to stop all Nginx servers
#
# Features:
# - Fail-safe scripting with proper error handling
# - Comprehensive logging to file and console
# - Modular functions for maintainability
# - Port verification

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/stop-servers-$(date +%Y%m%d-%H%M%S).log"
readonly PORTS=(80 8081 8082)

# Trap errors and cleanup
trap 'error_handler $? $LINENO' ERR
trap 'cleanup' EXIT INT TERM

#######################################
# Logging Functions
#######################################

init_logging() {
    mkdir -p "${LOG_DIR}" || {
        echo -e "${RED}❌ Failed to create log directory${NC}" >&2
        exit 1
    }
    log_info "=== Script started at $(date) ==="
}

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

error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Script failed with exit code ${exit_code} at line ${line_number}"
    echo -e "${RED}❌ An error occurred. Check log file: ${LOG_FILE}${NC}" >&2
}

cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        log_info "=== Script completed successfully ==="
    else
        log_error "=== Script exited with errors (code: ${exit_code}) ==="
    fi
}

#######################################
# Port Management Functions
#######################################

check_port_in_use() {
    local port=$1
    if lsof -Pi ":${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

verify_ports_free() {
    local all_free=true
    
    for port in "${PORTS[@]}"; do
        if check_port_in_use "${port}"; then
            log_warning "Port ${port} is still in use"
            echo -e "${RED}⚠️  Port ${port} is still in use${NC}"
            all_free=false
        else
            log_info "Port ${port} is free"
        fi
    done
    
    if [[ "${all_free}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

#######################################
# Nginx Management Functions
#######################################

stop_nginx_gracefully() {
    log_info "Attempting graceful shutdown of Nginx processes..."
    
    if pgrep -x nginx >/dev/null; then
        sudo killall nginx 2>/dev/null || true
        log_info "Sent termination signal to Nginx processes"
        return 0
    else
        log_info "No Nginx processes found"
        return 1
    fi
}

stop_nginx_forcefully() {
    log_warning "Force killing remaining Nginx processes..."
    
    if pgrep -x nginx >/dev/null; then
        sudo killall -9 nginx 2>/dev/null || true
        log_info "Force killed Nginx processes"
        return 0
    else
        log_info "No Nginx processes to force kill"
        return 1
    fi
}

verify_nginx_stopped() {
    local max_attempts=5
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if ! pgrep -x nginx >/dev/null; then
            log_success "All Nginx processes stopped"
            return 0
        fi
        log_info "Waiting for Nginx to stop (attempt ${attempt}/${max_attempts})..."
        sleep 1
        ((attempt++))
    done
    
    log_error "Nginx processes still running after ${max_attempts} attempts"
    return 1
}

#######################################
# User Interface Functions
#######################################

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Nginx Load Balancing Demo - Stopping Servers       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           All Servers Stopped Successfully!              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ All Nginx processes stopped${NC}"
    echo -e "${GREEN}✓ All ports (80, 8081, 8082) are now free${NC}"
    echo ""
    echo -e "${BLUE}📊 View logs:${NC}"
    echo -e "  ${YELLOW}${LOG_FILE}${NC}"
    echo ""
    echo -e "${BLUE}🚀 To start servers again, run:${NC}"
    echo -e "${YELLOW}./scripts/start-servers.sh${NC}"
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
    
    # Stop Nginx gracefully
    echo -e "${YELLOW}Stopping all Nginx processes...${NC}"
    stop_nginx_gracefully
    sleep 2
    
    # Verify Nginx stopped
    if ! verify_nginx_stopped; then
        log_warning "Nginx did not stop gracefully, forcing shutdown..."
        echo -e "${YELLOW}⚠️  Some processes did not stop gracefully${NC}"
        stop_nginx_forcefully
        sleep 1
        
        # Verify again
        if ! verify_nginx_stopped; then
            log_error "Failed to stop all Nginx processes"
            echo -e "${RED}❌ Failed to stop all Nginx processes${NC}"
            exit 1
        fi
    fi
    
    # Verify ports are free
    echo ""
    echo -e "${YELLOW}Verifying ports are free...${NC}"
    if verify_ports_free; then
        print_summary
        log_success "All servers stopped and ports freed"
    else
        echo -e "${YELLOW}⚠️  Some ports are still in use.${NC}"
        echo -e "${YELLOW}They will be freed automatically when starting servers.${NC}"
        log_warning "Some ports still in use after stopping"
    fi
}

# Run main function
main "$@"
