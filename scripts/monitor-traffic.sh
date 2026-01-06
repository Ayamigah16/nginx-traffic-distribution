#!/bin/bash

# Script to monitor traffic distribution in real-time
# Shows live requests and which backend server handles them
#
# Features:
# - Fail-safe scripting with proper error handling
# - Real-time log parsing with color coding
# - Statistics tracking
# - Graceful shutdown

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly MONITOR_LOG="${LOG_DIR}/monitor-$(date +%Y%m%d-%H%M%S).log"
readonly NGINX_LOG="/var/log/nginx/load_balancer_access.log"

# Statistics
declare -i SERVER1_COUNT=0
declare -i SERVER2_COUNT=0
declare -i TOTAL_REQUESTS=0

# Trap signals for cleanup
trap 'cleanup' EXIT INT TERM

#######################################
# Logging Functions
#######################################

init_logging() {
    mkdir -p "${LOG_DIR}" || {
        echo -e "${RED}❌ Failed to create log directory${NC}" >&2
        exit 1
    }
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Monitor started" >> "${MONITOR_LOG}"
}

log_request() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "${MONITOR_LOG}"
}

#######################################
# Cleanup Functions
#######################################

cleanup() {
    local exit_code=$?
    echo ""
    echo ""
    print_statistics
    echo -e "${BLUE}Monitoring stopped.${NC}"
    echo -e "${BLUE}Session log: ${YELLOW}${MONITOR_LOG}${NC}"
    echo ""
    exit ${exit_code}
}

#######################################
# Validation Functions
#######################################

check_log_file() {
    if [[ ! -f "${NGINX_LOG}" ]]; then
        echo -e "${RED}❌ Log file not found: ${NGINX_LOG}${NC}" >&2
        echo -e "${YELLOW}Make sure the load balancer is running: ./scripts/start-servers.sh${NC}" >&2
        return 1
    fi
    return 0
}

check_log_readable() {
    if [[ ! -r "${NGINX_LOG}" ]]; then
        echo -e "${YELLOW}⚠️  Need sudo permission to read logs${NC}"
        return 1
    fi
    return 0
}

#######################################
# Statistics Functions
#######################################

update_statistics() {
    local server=$1
    ((TOTAL_REQUESTS++))
    
    case "${server}" in
        "server1")
            ((SERVER1_COUNT++))
            ;;
        "server2")
            ((SERVER2_COUNT++))
            ;;
    esac
}

print_statistics() {
    local server1_pct=0
    local server2_pct=0
    
    if [[ ${TOTAL_REQUESTS} -gt 0 ]]; then
        server1_pct=$(( SERVER1_COUNT * 100 / TOTAL_REQUESTS ))
        server2_pct=$(( SERVER2_COUNT * 100 / TOTAL_REQUESTS ))
    fi
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Real-time Statistics Summary                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${BLUE}Total Requests:${NC} ${TOTAL_REQUESTS}"
    echo -e "${PURPLE}Server 1 (🟣):${NC}  ${SERVER1_COUNT} requests (${server1_pct}%)"
    echo -e "${RED}Server 2 (🔴):${NC}  ${SERVER2_COUNT} requests (${server2_pct}%)"
}

#######################################
# Log Parsing Functions
#######################################

parse_log_line() {
    local line=$1
    local server_color
    local server_label
    local formatted_line
    
    # Detect which server handled the request
    if [[ ${line} =~ localhost:8081 ]]; then
        server_color="${PURPLE}"
        server_label="[Server 1 🟣]"
        update_statistics "server1"
        log_request "Server1: ${line}"
    elif [[ ${line} =~ localhost:8082 ]]; then
        server_color="${RED}"
        server_label="[Server 2 🔴]"
        update_statistics "server2"
        log_request "Server2: ${line}"
    else
        server_color="${YELLOW}"
        server_label="[Unknown   ]"
        log_request "Unknown: ${line}"
    fi
    
    # Extract key information for compact display
    local timestamp
    local method
    local path
    local status
    local response_time
    
    timestamp=$(echo "${line}" | grep -oP '\[\K[^\]]+' | head -1 || echo "N/A")
    method=$(echo "${line}" | grep -oP '"\K[A-Z]+' || echo "N/A")
    path=$(echo "${line}" | grep -oP '"[A-Z]+ \K[^"]*(?=" HTTP)' || echo "/")
    status=$(echo "${line}" | grep -oP '" \K[0-9]{3}' || echo "N/A")
    response_time=$(echo "${line}" | grep -oP 'upstream_response_time: \K[0-9.]+' || echo "N/A")
    
    # Print formatted output
    echo -e "${server_color}${server_label}${NC} ${timestamp} | ${method} ${path} | Status: ${status} | Time: ${response_time}s"
}

monitor_traffic() {
    local use_sudo=$1
    
    if [[ "${use_sudo}" == "true" ]]; then
        sudo tail -f -n 0 "${NGINX_LOG}" 2>/dev/null | while IFS= read -r line; do
            parse_log_line "${line}"
        done
    else
        tail -f -n 0 "${NGINX_LOG}" 2>/dev/null | while IFS= read -r line; do
            parse_log_line "${line}"
        done
    fi
}

#######################################
# User Interface Functions
#######################################

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Real-time Load Balancer Traffic Monitor        ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Monitoring:${NC} ${NGINX_LOG}"
    echo -e "${BLUE}Legend:${NC} ${PURPLE}🟣 Server 1${NC} | ${RED}🔴 Server 2${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop and see statistics${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

#######################################
# Main Execution
#######################################

main() {
    # Initialize logging
    init_logging
    
    # Check if log file exists
    if ! check_log_file; then
        exit 1
    fi
    
    # Print header
    print_header
    
    # Determine if we need sudo
    local use_sudo="false"
    if ! check_log_readable; then
        use_sudo="true"
    fi
    
    # Start monitoring
    if [[ "${use_sudo}" == "true" ]]; then
        echo -e "${YELLOW}Using sudo to read nginx logs...${NC}"
        echo ""
    fi
    
    # Monitor traffic (this will run until interrupted)
    monitor_traffic "${use_sudo}"
}

# Run main function
main "$@"
