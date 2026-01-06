#!/bin/bash

# Script to test the load balancer by making multiple requests
# and showing which server handles each request
#
# Features:
# - Fail-safe scripting with proper error handling
# - Comprehensive logging
# - Statistical analysis of distribution
# - Colorized output for better visualization

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
readonly LOG_FILE="${LOG_DIR}/test-load-balancer-$(date +%Y%m%d-%H%M%S).log"
readonly LB_URL="http://localhost:80"
readonly NUM_REQUESTS="${1:-20}"  # Default to 20, or use first argument

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
    log_info "=== Test started at $(date) ==="
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "${LOG_FILE}"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "${LOG_FILE}" >&2
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "${LOG_FILE}"
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
        log_info "=== Test completed successfully ==="
    else
        log_error "=== Test exited with errors (code: ${exit_code}) ==="
    fi
}

#######################################
# Validation Functions
#######################################

check_load_balancer_accessible() {
    log_info "Checking if load balancer is accessible..."
    
    if ! curl -s --head --connect-timeout 5 "${LB_URL}" > /dev/null 2>&1; then
        log_error "Load balancer is not accessible at ${LB_URL}"
        echo -e "${RED}❌ Load balancer is not accessible at ${LB_URL}${NC}"
        echo -e "${YELLOW}Make sure servers are running: ./scripts/start-servers.sh${NC}"
        return 1
    fi
    
    log_success "Load balancer is accessible"
    return 0
}

validate_num_requests() {
    if ! [[ "${NUM_REQUESTS}" =~ ^[0-9]+$ ]] || [[ "${NUM_REQUESTS}" -lt 1 ]]; then
        log_error "Invalid number of requests: ${NUM_REQUESTS}"
        echo -e "${RED}❌ Invalid number of requests: ${NUM_REQUESTS}${NC}"
        echo -e "${YELLOW}Usage: $0 [number_of_requests]${NC}"
        return 1
    fi
    log_info "Number of requests: ${NUM_REQUESTS}"
    return 0
}

#######################################
# Testing Functions
#######################################

make_request() {
    local request_num=$1
    local server_info
    local response_time
    local algorithm
    local status
    
    # Make request and capture response
    local response
    response=$(curl -s -w "\n%{time_total}\n%{http_code}" -H "Connection: close" "${LB_URL}/server-status" 2>/dev/null) || {
        log_error "Request ${request_num} failed"
        echo "error" "0" "unknown" "000"
        return 1
    }
    
    # Parse response
    server_info=$(echo "${response}" | grep -o '"server":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    response_time=$(echo "${response}" | tail -n2 | head -n1)
    status=$(echo "${response}" | tail -n1)
    
    # Get algorithm from headers
    algorithm=$(curl -s -I "${LB_URL}" 2>/dev/null | grep -i "X-Load-Balancer-Algorithm" | cut -d' ' -f2- | tr -d '\r\n' || echo "Unknown")
    
    # Return results
    echo "${server_info}" "${response_time}" "${algorithm}" "${status}"
    
    log_info "Request ${request_num}: Server=${server_info}, Time=${response_time}s, Status=${status}"
}

format_request_output() {
    local request_num=$1
    local server_info=$2
    local response_time=$3
    local algorithm=$4
    local status=$5
    
    local server_color
    local server_name
    
    # Determine server color and name
    case "${server_info}" in
        "server1")
            server_color="${PURPLE}"
            server_name="Server 1 🟣"
            ;;
        "server2")
            server_color="${RED}"
            server_name="Server 2 🔴"
            ;;
        "error")
            server_color="${YELLOW}"
            server_name="Error ⚠️ "
            ;;
        *)
            server_color="${YELLOW}"
            server_name="Unknown"
            ;;
    esac
    
    # Print formatted output
    printf "%-8s | ${server_color}%-11s${NC} | %-18s | %.3fs | %s\n" \
        "#${request_num}" "${server_name}" "${algorithm}" "${response_time}" "${status}"
}

analyze_distribution() {
    local server1_count=$1
    local server2_count=$2
    local error_count=$3
    local algorithm=$4
    local total_requests=$((server1_count + server2_count + error_count))
    
    # Calculate percentages
    local server1_pct=0
    local server2_pct=0
    
    if [[ ${total_requests} -gt 0 ]]; then
        server1_pct=$(( server1_count * 100 / total_requests ))
        server2_pct=$(( server2_count * 100 / total_requests ))
    fi
    
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Distribution Summary                  ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${PURPLE}Server 1 (🟣):${NC} ${server1_count} requests (${server1_pct}%)"
    echo -e "${RED}Server 2 (🔴):${NC} ${server2_count} requests (${server2_pct}%)"
    
    if [[ ${error_count} -gt 0 ]]; then
        echo -e "${YELLOW}Errors:${NC} ${error_count} requests"
    fi
    
    # Log summary
    log_info "Distribution: Server1=${server1_count}, Server2=${server2_count}, Errors=${error_count}"
    
    # Provide interpretation
    provide_interpretation "${server1_count}" "${server2_count}" "${algorithm}"
}

provide_interpretation() {
    local server1_count=$1
    local server2_count=$2
    local algorithm=$3
    
    echo ""
    echo -e "${YELLOW}📊 Interpretation:${NC}"
    
    case "${algorithm}" in
        *"Round-Robin"*)
            echo "  ▶ Round Robin: Should be roughly 50/50 distribution"
            if [[ $(( server1_count - server2_count )) -lt 3 ]] && [[ $(( server2_count - server1_count )) -lt 3 ]]; then
                echo -e "    ${GREEN}✓ Distribution is within expected range!${NC}"
            else
                echo -e "    ${YELLOW}⚠ Slight variation is normal with small sample sizes${NC}"
            fi
            ;;
        *"IP-Hash"*)
            echo "  ▶ IP Hash: All requests from your IP go to the same server"
            if [[ ${server1_count} -eq ${NUM_REQUESTS} ]] || [[ ${server2_count} -eq ${NUM_REQUESTS} ]]; then
                echo -e "    ${GREEN}✓ Working correctly! All requests to one server${NC}"
            else
                echo -e "    ${YELLOW}⚠ Unexpected: IP Hash should route to one server${NC}"
            fi
            ;;
        *"Weighted"*)
            echo "  ▶ Weighted: Server 1 should get ~75%, Server 2 should get ~25%"
            local expected_s1=$(( NUM_REQUESTS * 3 / 4 ))
            local diff=$(( server1_count - expected_s1 ))
            diff=${diff#-}  # Absolute value
            
            if [[ ${diff} -le 3 ]]; then
                echo -e "    ${GREEN}✓ Distribution matches weight configuration!${NC}"
            else
                echo -e "    ${YELLOW}⚠ Variation from expected (normal with small sample size)${NC}"
            fi
            ;;
        *"Least-Connections"*)
            echo "  ▶ Least Connections: Routes to server with fewer active connections"
            echo "    With quick requests, distribution may vary based on timing"
            ;;
        *)
            echo "  ▶ Algorithm: ${algorithm}"
            ;;
    esac
}

#######################################
# User Interface Functions
#######################################

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Testing Nginx Load Balancer Distribution        ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_tips() {
    echo ""
    echo -e "${BLUE}💡 Tips:${NC}"
    echo "  • Run this test multiple times to see consistency"
    echo "  • Try different algorithms: ./scripts/start-servers.sh"
    echo "  • Monitor real-time logs: sudo tail -f /var/log/nginx/load_balancer_access.log"
    echo "  • Test with browser: Open http://localhost and refresh multiple times"
    echo ""
    echo -e "${BLUE}📊 View test log:${NC}"
    echo -e "  ${YELLOW}${LOG_FILE}${NC}"
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
    
    # Validate inputs
    validate_num_requests || exit 1
    check_load_balancer_accessible || exit 1
    
    echo -e "${GREEN}✓ Load balancer is accessible${NC}"
    echo -e "${BLUE}Making ${NUM_REQUESTS} requests to observe distribution...${NC}"
    echo ""
    
    # Print table header
    echo -e "${CYAN}Request# | Server      | Algorithm          | Response Time | Status${NC}"
    echo "---------|-------------|--------------------|--------------|---------"
    
    # Counters
    local server1_count=0
    local server2_count=0
    local error_count=0
    local algorithm="Unknown"
    
    # Make requests
    for i in $(seq 1 "${NUM_REQUESTS}"); do
        # Make request and parse results
        read -r server_info response_time alg status <<< "$(make_request "${i}")"
        
        # Update algorithm (from first successful request)
        if [[ "${algorithm}" == "Unknown" ]] && [[ "${alg}" != "unknown" ]]; then
            algorithm="${alg}"
        fi
        
        # Count servers
        case "${server_info}" in
            "server1") ((server1_count++)) ;;
            "server2") ((server2_count++)) ;;
            *) ((error_count++)) ;;
        esac
        
        # Format and print output
        format_request_output "${i}" "${server_info}" "${response_time}" "${algorithm}" "${status}"
        
        # Small delay to simulate real traffic
        sleep 0.1
    done
    
    # Analyze and display distribution
    analyze_distribution "${server1_count}" "${server2_count}" "${error_count}" "${algorithm}"
    
    # Print tips
    print_tips
    
    log_success "Test completed successfully"
}

# Run main function
main "$@"
