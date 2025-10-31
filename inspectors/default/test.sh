#!/bin/bash
#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#
# Comprehensive Test Suite for detect_system_info.sh
# 
# This script runs multiple test scenarios to validate the inspector behavior
# under different configurations and capture diagnostic information.

# shellcheck disable=SC3043

set -e

# ============================================================================
# Test Configuration
# ============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_SCRIPT="${SCRIPT_DIR}/common/detect_system_info.sh"

# Create test base directory with timestamp
TEST_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_LABEL=${TEST_LABEL:-default}
TEST_BASE_DIR=${TEST_BASE_DIR:-/tmp/iwdlm/test}
TEST_SESSION_DIR="${TEST_BASE_DIR}/${TEST_LABEL}/${TEST_TIMESTAMP}"

# Test subdirectories
TEST_01_DIR="${TEST_SESSION_DIR}/test-01-debug-on"
TEST_02_DIR="${TEST_SESSION_DIR}/test-02-debug-off-normal"
TEST_03_DIR="${TEST_SESSION_DIR}/test-03-debug-off-redirected"
TEST_04_DIR="${TEST_SESSION_DIR}/test-04-raw-commands"
TEST_05_DIR="${TEST_SESSION_DIR}/test-05-permission-check"
TEST_06_DIR="${TEST_SESSION_DIR}/test-06-config-validation"

# Summary file
TEST_SUMMARY="${TEST_SESSION_DIR}/test_summary.txt"

TEST_IWDLI_COLORED=${TEST_IWDLI_COLORED:-NO}
# Note, putting the default on bash to facilitate a bit default test on Solaris 8
TEST_SHELL_COMMAND=${TEST_SHELL_COMMAND:-bash}

# Color codes for output (if terminal supports it)
if [ "${TEST_IWDLI_COLORED}" = "YES" ]; then
    COLOR_RESET='\033[0m'
    COLOR_GREEN='\033[0;32m'
    COLOR_RED='\033[0;31m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
else
    COLOR_RESET=''
    COLOR_GREEN=''
    COLOR_RED=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
fi

# ============================================================================
# Utility Functions
# ============================================================================

# Get current time in seconds (portable version for old Solaris)
get_timestamp_seconds() {

    local epoch
    epoch=$(date +%s)
    # Try modern date command first
    if [ "${epoch}" = "%s" ]; then
        # Fallback for old Solaris/SunOS that doesn't support %s
        # Use Perl if available (common on Solaris)
        if command -v perl >/dev/null 2>&1; then
            perl -e 'print time()'
        elif command -v python >/dev/null 2>&1; then
            python -c 'import time; print(int(time.time()))'
        else
            # Last resort: return 0 (duration will be 0 but test continues)
            echo "0"
        fi
    else
        echo "${epoch}"
    fi
}

# Print section header
print_header() {
    echo ""
    echo "========================================================================"
    echo "$1"
    echo "========================================================================"
    echo ""
}

# Print test step
print_step() {
    echo ""
    echo "${COLOR_BLUE}>>> $1${COLOR_RESET}"
}

# Print success message
print_success() {
    echo "${COLOR_GREEN}[OK] $1${COLOR_RESET}"
}

# Print error message
print_error() {
    echo "${COLOR_RED}ERR $1${COLOR_RESET}"
}

# Print warning message
print_warning() {
    echo "${COLOR_YELLOW}WRN $1${COLOR_RESET}"
}

# Log to summary file
log_summary() {
    echo "$1" >> "$TEST_SUMMARY"
}

# ============================================================================
# eval command
# ============================================================================
eval_cmd(){
    __cmd=${1}
    __label=${2}

    print_step "Running command $__cmd via eval with stdout and stderr capture with label $__label"

    # Temporarily disable set -e to prevent shell exit on command failure
    set +e
    eval "${__cmd}" >>"${TEST_04_DIR}/${__label}.out" 2>>"${TEST_04_DIR}/${__label}.err"
    set -e

    unset __cmd __label
}

# ============================================================================
# Test Setup
# ============================================================================

setup_test_environment() {
    print_header "Test Environment Setup"
    
    # Create test directories
    print_step "Creating test directory structure..."
    mkdir -p "$TEST_SESSION_DIR"
    mkdir -p "$TEST_01_DIR"
    mkdir -p "$TEST_02_DIR"
    mkdir -p "$TEST_03_DIR"
    mkdir -p "$TEST_04_DIR"
    mkdir -p "$TEST_05_DIR"
    mkdir -p "$TEST_06_DIR"
    
    print_success "Test directories created at: ${TEST_SESSION_DIR}"
    
    # Verify detection script exists
    print_step "Verifying detection script..."
    if [ ! -f "$DETECT_SCRIPT" ]; then
        print_error "Detection script not found: ${DETECT_SCRIPT}"
        exit 1
    fi
    print_success "Detection script found: ${DETECT_SCRIPT}"
    
    # Initialize summary file
    {
        echo "========================================================================"
        echo "IBM webMethods Default License Inspector - Test Summary"
        echo "========================================================================"
        echo "Test execution: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Test session directory: ${TEST_SESSION_DIR}"
        echo "Detection script: ${DETECT_SCRIPT}"
        echo "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
        echo "OS: $(uname -s) $(uname -r)"
        echo "========================================================================"
        echo ""
    } > "$TEST_SUMMARY"
    
    # Set default IWDLI_HOME
    export IWDLI_HOME="${TEST_SESSION_DIR}/iwdli_home"
    mkdir -p "$IWDLI_HOME"
    print_success "IWDLI_HOME set to: ${IWDLI_HOME}"
}

# ============================================================================
# Test 01: Debug Mode ON
# ============================================================================

test_01_debug_on() {
    print_header "TEST 01: Execute with IWDLI_DEBUG=ON"
    
    log_summary "TEST 01: Debug Mode ON"
    log_summary "========================"
    
    print_step "Setting IWDLI_DEBUG=ON"
    export IWDLI_DEBUG=ON
    
    print_step "Executing detection script..."
    local start_time
    start_time=$(get_timestamp_seconds)
    
    # Temporarily disable set -e to capture actual exit code
    set +e
    "${TEST_SHELL_COMMAND}" "$DETECT_SCRIPT" "${TEST_01_DIR}/output" 2>&1 | tee "${TEST_01_DIR}/execution.log"
    local exit_code=$?
    set -e
    
    if [ "$exit_code" -eq 0 ]; then
        print_success "Script executed successfully"
    else
        print_error "Script failed with exit code: ${exit_code}"
    fi
    
    local end_time
    end_time=$(get_timestamp_seconds)
    local duration=$((end_time - start_time))
    
    # Analyze results
    print_step "Analyzing test results..."
    
    local csv_file=$(find "${TEST_01_DIR}/output" -name "iwdli_output_*.csv" 2>/dev/null | head -1)
    local session_log=$(find "${TEST_01_DIR}/output" -name "iwdli_session.log" 2>/dev/null | head -1)
    
    log_summary "Exit code: ${exit_code}"
    log_summary "Duration: ${duration} seconds"
    log_summary "CSV output: ${csv_file:-NOT FOUND}"
    log_summary "Session log: ${session_log:-NOT FOUND}"
    
    if [ -n "$csv_file" ]; then
        local csv_lines=$(wc -l < "$csv_file" 2>/dev/null || echo "0")
        log_summary "CSV lines: ${csv_lines}"
        print_success "CSV file created with ${csv_lines} lines"
    else
        print_error "CSV file not found"
    fi
    
    if [ -n "$session_log" ]; then
        local debug_lines=$(grep -c "\[DEBUG\]" "$session_log" 2>/dev/null || echo "0")
        local info_lines=$(grep -c "\[INFO\]" "$session_log" 2>/dev/null || echo "0")
        log_summary "DEBUG messages: ${debug_lines}"
        log_summary "INFO messages: ${info_lines}"
        print_success "Session log contains ${debug_lines} DEBUG and ${info_lines} INFO messages"
    fi
    
    # Count debug output files
    local debug_files=$(find "${TEST_01_DIR}/output" -name "*.out" -o -name "*.err" 2>/dev/null | wc -l)
    log_summary "Debug output files: ${debug_files}"
    print_success "Created ${debug_files} debug output files"
    
    log_summary ""
}

# ============================================================================
# Test 02: Debug Mode OFF - Normal Execution
# ============================================================================

test_02_debug_off_normal() {
    print_header "TEST 02: Execute with IWDLI_DEBUG=OFF (Normal Output)"
    
    log_summary "TEST 02: Debug Mode OFF - Normal Execution"
    log_summary "==========================================="
    
    print_step "Setting IWDLI_DEBUG=OFF"
    export IWDLI_DEBUG=OFF
    
    print_step "Executing detection script without output redirection..."
    local start_time
    start_time=$(get_timestamp_seconds)
    
    # Execute and capture to log but let output flow normally
    # Temporarily disable set -e to capture actual exit code
    set +e
    ${TEST_SHELL_COMMAND} "$DETECT_SCRIPT" "${TEST_02_DIR}/output" 2>&1 | tee "${TEST_02_DIR}/execution.log"
    local exit_code=$?
    set -e
    
    if [ "$exit_code" -eq 0 ]; then
        print_success "Script executed successfully"
    else
        print_error "Script failed with exit code: ${exit_code}"
    fi
    
    local end_time
    end_time=$(get_timestamp_seconds)
    local duration=$((end_time - start_time))
    
    # Analyze results
    print_step "Analyzing test results..."
    
    local csv_file=$(find "${TEST_02_DIR}/output" -name "iwdli_output_*.csv" 2>/dev/null | head -1)
    local session_log=$(find "${TEST_02_DIR}/output" -name "iwdli_session.log" 2>/dev/null | head -1)
    local exec_lines=$(wc -l < "${TEST_02_DIR}/execution.log" 2>/dev/null || echo "0")
    
    log_summary "Exit code: ${exit_code}"
    log_summary "Duration: ${duration} seconds"
    log_summary "Execution log lines: ${exec_lines}"
    log_summary "CSV output: ${csv_file:-NOT FOUND}"
    
    # Check for unexpected DEBUG messages
    if [ -f "${TEST_02_DIR}/execution.log" ]; then
        local debug_count=$(grep -c "\[DEBUG\]" "${TEST_02_DIR}/execution.log" 2>/dev/null || echo "0")
        if [ "$debug_count" -gt 0 ]; then
            print_error "Found ${debug_count} DEBUG messages (should be 0)"
            log_summary "DEBUG messages: ${debug_count} (FAIL - should be 0)"
        else
            print_success "No DEBUG messages (correct)"
            log_summary "DEBUG messages: 0 (PASS)"
        fi
    fi
    
    # Check that only INFO messages appear
    if [ -f "${TEST_02_DIR}/execution.log" ]; then
        local info_count=$(grep -c "\[INFO\]" "${TEST_02_DIR}/execution.log" 2>/dev/null || echo "0")
        log_summary "INFO messages: ${info_count}"
        print_success "Found ${info_count} INFO messages"
    fi
    
    log_summary ""
}

# ============================================================================
# Test 03: Debug Mode OFF - Redirected Output
# ============================================================================

test_03_debug_off_redirected() {
    print_header "TEST 03: Execute with IWDLI_DEBUG=OFF (Redirected Output)"
    
    log_summary "TEST 03: Debug Mode OFF - Redirected Output"
    log_summary "============================================"
    
    print_step "Setting IWDLI_DEBUG=OFF"
    export IWDLI_DEBUG=OFF
    
    print_step "Executing detection script with output redirection..."
    local start_time
    start_time=$(get_timestamp_seconds)
    
    # Execute with explicit STDOUT and STDERR redirection
    # Temporarily disable set -e to capture exit code even on failure
    set +e
    ${TEST_SHELL_COMMAND} "$DETECT_SCRIPT" "${TEST_03_DIR}/output" \
        >"${TEST_03_DIR}/stdout.log" \
        2>"${TEST_03_DIR}/stderr.log"
    local exit_code=$?
    set -e
    echo "$exit_code" > "${TEST_03_DIR}/exit_code.txt"
    
    local end_time
    end_time=$(get_timestamp_seconds)
    local duration=$((end_time - start_time))
    
    if [ "$exit_code" -eq 0 ]; then
        print_success "Script executed successfully"
    else
        print_error "Script failed with exit code: ${exit_code}"
    fi
    
    # Analyze results
    print_step "Analyzing test results..."
    
    local stdout_lines=$(wc -l < "${TEST_03_DIR}/stdout.log" 2>/dev/null || echo "0")
    local stderr_lines=$(wc -l < "${TEST_03_DIR}/stderr.log" 2>/dev/null || echo "0")
    local csv_file=$(find "${TEST_03_DIR}/output" -name "iwdli_output_*.csv" 2>/dev/null | head -1)
    
    log_summary "Exit code: ${exit_code}"
    log_summary "Duration: ${duration} seconds"
    log_summary "STDOUT lines: ${stdout_lines}"
    log_summary "STDERR lines: ${stderr_lines}"
    log_summary "CSV output: ${csv_file:-NOT FOUND}"
    
    # Validate STDOUT is empty
    if [ "$stdout_lines" -eq 0 ]; then
        print_success "STDOUT is empty (correct)"
        log_summary "STDOUT validation: PASS"
    else
        print_error "STDOUT has ${stdout_lines} lines (should be 0)"
        log_summary "STDOUT validation: FAIL"
        # Show first few lines
        print_warning "First 10 lines of STDOUT:"
        head -10 "${TEST_03_DIR}/stdout.log" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    
    # Check STDERR for DEBUG messages
    if [ -f "${TEST_03_DIR}/stderr.log" ]; then
        local debug_count=$(grep -c "\[DEBUG\]" "${TEST_03_DIR}/stderr.log" 2>/dev/null || echo "0")
        if [ "$debug_count" -gt 0 ]; then
            print_error "Found ${debug_count} DEBUG messages in STDERR (should be 0)"
            log_summary "STDERR DEBUG check: FAIL (${debug_count} found)"
        else
            print_success "No DEBUG messages in STDERR (correct)"
            log_summary "STDERR DEBUG check: PASS"
        fi
        
        local info_count=$(grep -c "\[INFO\]" "${TEST_03_DIR}/stderr.log" 2>/dev/null || echo "0")
        log_summary "STDERR INFO messages: ${info_count}"
        print_success "Found ${info_count} INFO messages in STDERR"
    fi
    
    log_summary ""
}

# ============================================================================
# Test 04: Raw System Commands
# ============================================================================

test_04_raw_commands() {
    print_header "TEST 04: Execute Raw System Commands"
    
    log_summary "TEST 04: Raw System Commands Execution"
    log_summary "======================================="
    
    print_step "Executing relevant commands..."

    # Process listing commands
    eval_cmd "ps -ef" "ps-ef"
    eval_cmd "ps -auxww" "ps-auxww"
    eval_cmd "ps auxww" "ps_auxww"
    eval_cmd "ps aux" "ps_aux"
    
    # AIX specific commands
    eval_cmd "lparstat" "lparstat"
    eval_cmd "lparstat -i" "lparstat-i"
    eval_cmd "prtconf" "prtconf"
    eval_cmd "lsdev -Cc processor" "lsdev-processor"
    eval_cmd "lscfg -pv" "lscfg-pv"
    eval_cmd "oslevel -s" "oslevel-s"
    
    # Solaris-specific commands
    eval_cmd "psrinfo" "psrinfo"
    eval_cmd "psrinfo -v" "psrinfo-v"
    eval_cmd "psrinfo -pv" "psrinfo-pv"
    eval_cmd "psrinfo -p" "psrinfo-p"
    eval_cmd "zonename" "zonename"
    eval_cmd "virtinfo" "virtinfo"
    eval_cmd "hostid" "hostid"
    
    # Linux-specific commands
    eval_cmd "cat /proc/cpuinfo" "proc-cpuinfo"
    eval_cmd "cat /proc/version" "proc-version"
    eval_cmd "dmidecode" "dmidecode"
    eval_cmd "dmidecode -s system-manufacturer" "dmidecode-manufacturer"
    eval_cmd "dmidecode -s system-product-name" "dmidecode-product"
    eval_cmd "dmidecode -s system-version" "dmidecode-version"
    eval_cmd "dmidecode -s system-uuid" "dmidecode-uuid"
    eval_cmd "systemd-detect-virt" "systemd-detect-virt"
    eval_cmd "cat /sys/devices/virtual/dmi/id/product_uuid" "sys-dmi-uuid"
    
    # Disk-based product detection commands
    print_step "Testing disk-based product detection commands..."
    
    # Determine platform-specific du command options (same logic as detect_system_info.sh)
    local du_cmd="du -s"
    local size_threshold=2
    local os_type
    os_type=$(uname -s 2>/dev/null || echo "Unknown")
    
    case "$os_type" in
        "AIX")
            # AIX du uses 512-byte blocks
            du_cmd="du -s"
            size_threshold=2
            ;;
        "SunOS")
            # Solaris du uses 512-byte blocks, -k not supported on older versions
            du_cmd="du -s"
            size_threshold=2
            ;;
        "Linux")
            # Linux - try -sk for kilobyte output
            if du -sk /tmp >/dev/null 2>&1; then
                du_cmd="du -sk"
                size_threshold=1
            else
                du_cmd="du -s"
                size_threshold=2
            fi
            ;;
        *)
            # Default fallback
            du_cmd="du -s"
            size_threshold=2
            ;;
    esac
    
    print_step "Using du command: ${du_cmd}, threshold: ${size_threshold}"
    
    # Test basic utilities needed for POSIX-compliant disk detection
    print_step "Testing basic POSIX utilities..."
    
    # Test tr (used for counting slashes)
    eval_cmd "echo '/opt/softwareag/IntegrationServer' | tr -cd '/'" "tr-count-slashes"
    eval_cmd "echo '/opt/softwareag/IntegrationServer' | tr -cd '/' | wc -c" "tr-slash-count-with-wc"
    
    # Test find without -maxdepth (POSIX-compliant)
    eval_cmd "find /tmp -type d -name iwdlm 2>/dev/null | head -5" "find-no-maxdepth"
    
    # Test depth calculation approach (count slashes with awk)
    eval_cmd "echo '/opt/softwareag/IntegrationServer' | awk -F/ '{print NF}'" "awk-count-components"
    
    # Test du with different options
    eval_cmd "${du_cmd} /tmp 2>/dev/null | head -5" "du-test"
    eval_cmd "${du_cmd} /tmp 2>/dev/null | awk '{print \$1}' | head -1" "du-extract-size"
    
    # Test arithmetic comparison in shell
    eval_cmd "test 100 -gt 2 && echo 'PASS: 100 > 2' || echo 'FAIL'" "shell-arithmetic-test"
    
    # Test while read loop with piped input
    eval_cmd "echo -e '/path/one\n/path/two\n/path/three' | while IFS= read -r line; do echo \"Line: \$line\"; done" "while-read-test"
    
    # Test grep -q (quiet mode)
    eval_cmd "echo 'IntegrationServer' | grep -q 'Integration' && echo 'PASS: grep -q works' || echo 'FAIL'" "grep-quiet-test"
    
    # Test temp file operations
    eval_cmd "temp_file=\"/tmp/test_temp_\$\$.txt\"; echo 'test data' > \"\$temp_file\"; cat \"\$temp_file\"; rm -f \"\$temp_file\"; echo 'PASS: temp file ops work'" "temp-file-ops"
    
    # Test wc -l output format (different between systems)
    eval_cmd "echo -e 'line1\nline2\nline3' | wc -l" "wc-line-count"
    eval_cmd "echo -e 'line1\nline2\nline3' > /tmp/test_wc_\$\$.txt; wc -l < /tmp/test_wc_\$\$.txt; rm -f /tmp/test_wc_\$\$.txt" "wc-from-stdin"
    
    # Test semicolon-separated list building
    eval_cmd "paths=''; paths='/opt/one'; echo \"First: \$paths\"; paths=\"\${paths};/opt/two\"; echo \"Second: \$paths\"" "semicolon-list-building"
    
    # Test awk for joining with semicolons (may fail on very old awk)
    eval_cmd "echo -e '/path/one\n/path/two\n/path/three' | awk '{printf \"%s%s\", (NR>1 ? \";\" : \"\"), \$0} END {print \"\"}'" "awk-join-semicolon-complex"
    
    # Test shell loop method for joining - Bourne shell compatible
    # Note: IFS= as inline assignment with read fails on Solaris 5.8 /bin/sh
    eval_cmd "result=''; OLD_IFS=\"\$IFS\"; IFS=''; echo -e '/path/one\n/path/two\n/path/three' | while read -r line; do if [ -z \"\$result\" ]; then result=\"\$line\"; else result=\"\${result};\${line}\"; fi; done; IFS=\"\$OLD_IFS\"; echo \"Result: \$result\"" "shell-join-semicolon-bourne"
    
    # OLD TESTS (with -maxdepth - KNOWN TO FAIL on Solaris/AIX)
    print_step "Testing OLD disk detection commands (with -maxdepth - EXPECTED TO FAIL on Solaris/AIX)..."
    
    # Search for IntegrationServer installations
    eval_cmd "find /opt /usr/local /home /app -maxdepth 5 -type d -name IntegrationServer -exec ${du_cmd} \"{}\" \\; | awk -v thresh=\"${size_threshold}\" '\$1 > thresh {print \$2}'" "disk-detect-IntegrationServer"
    
    # Search for Broker installations (with exclusion)
    eval_cmd "find /opt /usr/local /home /app -maxdepth 5 -type d -name Broker -exec ${du_cmd} \"{}\" \\; | grep -v IntegrationServer | awk -v thresh=\"${size_threshold}\" '\$1 > thresh {print \$2}'" "disk-detect-Broker"
    
    # Search for UniversalMessaging installations
    eval_cmd "find /opt /usr/local /home /app -maxdepth 5 -type d -name UniversalMessaging -exec ${du_cmd} \"{}\" \\; | awk -v thresh=\"${size_threshold}\" '\$1 > thresh {print \$2}'" "disk-detect-UniversalMessaging"
    
    # NEW TESTS (POSIX-compliant approach)
    print_step "Testing NEW POSIX-compliant disk detection approach..."
    
    # Test find without -maxdepth, with manual depth filtering on /app (primary install location)
    eval_cmd "find /app -type d -name IntegrationServer 2>/dev/null | while IFS= read -r dir; do slash_count=\$(echo \"\$dir\" | tr -cd '/' | wc -c); base_count=\$(echo '/app' | tr -cd '/' | wc -c); depth=\$((slash_count - base_count)); if [ \$depth -le 5 ]; then echo \"\$dir (depth: \$depth)\"; fi; done | head -10" "posix-disk-detect-with-depth"
    
    # Common Unix commands
    eval_cmd "uname -a" "uname-a"
    eval_cmd "uname -s" "uname-s"
    eval_cmd "uname -r" "uname-r"
    eval_cmd "uname -m" "uname-m"
    eval_cmd "hostname" "hostname"
    
    # OS release files
    eval_cmd "cat /etc/os-release" "etc-os-release"
    eval_cmd "cat /etc/redhat-release" "etc-redhat-release"
    
    print_success "Command execution complete"
    
    log_summary "All commands executed - check ${TEST_04_DIR} for outputs"
    log_summary ""
    
    # Create index file
    {
        echo "Raw System Commands Output Index"
        echo "================================="
        echo "Generated: $(date)"
        echo ""
        echo "Files created:"
        ls -1 "${TEST_04_DIR}" | while IFS= read -r file; do
            echo "  - $file"
        done
    } > "${TEST_04_DIR}/INDEX.txt"
}

# ============================================================================
# Test 05: Permission Check
# ============================================================================

test_05_permission_check() {
    print_header "TEST 05: Permission and Access Check"
    
    log_summary "TEST 05: Permission and Access Check"
    log_summary "====================================="
    
    print_step "Checking file permissions and accessibility..."
    
    {
        echo "Permission Check Report"
        echo "======================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Detection Script:"
        ls -l "$DETECT_SCRIPT"
        if [ -x "$DETECT_SCRIPT" ]; then
            echo "[OK] Script is executable"
        else
            echo "[FAIL] Script is NOT executable"
        fi
        echo ""
        
        echo "Configuration Files:"
        for file in \
            "${SCRIPT_DIR}/common/ibm-eligible-processors.csv" \
            "${SCRIPT_DIR}/common/ibm-eligible-virt-and-os.csv" \
            "${SCRIPT_DIR}/common/node-config.conf" \
            "${SCRIPT_DIR}/landscape-config/product-detection-config.csv" \
            "${SCRIPT_DIR}/landscape-config/product-codes.csv"
        do
            if [ -f "$file" ]; then
                ls -l "$file"
            else
                echo "NOT FOUND: $file"
            fi
        done
        echo ""
        
        echo "Test Directory Permissions:"
        ls -ld "$TEST_SESSION_DIR"
        echo ""
        
        echo "Disk Space:"
        df -k "$TEST_SESSION_DIR" 2>/dev/null || df -k /tmp
        echo ""
        
        echo "Current User:"
        id
        echo ""
        
    } > "${TEST_05_DIR}/permission_report.txt"
    
    cat "${TEST_05_DIR}/permission_report.txt"
    print_success "Permission check completed"
    
    log_summary "Permission check: See ${TEST_05_DIR}/permission_report.txt"
    log_summary ""
}

# ============================================================================
# Test 06: Configuration Validation
# ============================================================================

test_06_config_validation() {
    print_header "TEST 06: Configuration Files Validation"
    
    log_summary "TEST 06: Configuration Files Validation"
    log_summary "========================================"
    
    print_step "Validating CSV configuration files..."
    
    {
        echo "Configuration Validation Report"
        echo "==============================="
        echo "Generated: $(date)"
        echo ""
        
        # Check ibm-eligible-processors.csv
        local proc_csv="${SCRIPT_DIR}/common/ibm-eligible-processors.csv"
        echo "Checking: ibm-eligible-processors.csv"
        if [ -f "$proc_csv" ]; then
            local lines=$(wc -l < "$proc_csv")
            local data_lines=$((lines - 1))
            echo "[OK] Found: $proc_csv"
            echo "  Total lines: $lines"
            echo "  Data lines: $data_lines (excluding header)"
            echo "  Header:"
            head -1 "$proc_csv"
            echo "  Sample data (first 3 lines):"
            tail -n +2 "$proc_csv" | head -3
        else
            echo "[FAIL] NOT FOUND: $proc_csv"
        fi
        echo ""
        
        # Check ibm-eligible-virt-and-os.csv
        local virt_csv="${SCRIPT_DIR}/common/ibm-eligible-virt-and-os.csv"
        echo "Checking: ibm-eligible-virt-and-os.csv"
        if [ -f "$virt_csv" ]; then
            local lines=$(wc -l < "$virt_csv")
            local data_lines=$((lines - 1))
            echo "[OK] Found: $virt_csv"
            echo "  Total lines: $lines"
            echo "  Data lines: $data_lines (excluding header)"
            echo "  Header:"
            head -1 "$virt_csv"
            echo "  Sample data (first 3 lines):"
            tail -n +2 "$virt_csv" | head -3
        else
            echo "[FAIL] NOT FOUND: $virt_csv"
        fi
        echo ""
        
        # Check product-detection-config.csv
        local prod_csv="${SCRIPT_DIR}/landscape-config/product-detection-config.csv"
        if [ ! -f "$prod_csv" ]; then
            prod_csv="${SCRIPT_DIR}/common/product-detection-config.csv"
        fi
        echo "Checking: product-detection-config.csv"
        if [ -f "$prod_csv" ]; then
            local lines=$(wc -l < "$prod_csv")
            local data_lines=$((lines - 1))
            echo "[OK] Found: $prod_csv"
            echo "  Total lines: $lines"
            echo "  Data lines: $data_lines (excluding header)"
            echo "  Header:"
            head -1 "$prod_csv"
            echo "  Sample data (first 3 lines):"
            tail -n +2 "$prod_csv" | head -3
        else
            echo "[FAIL] NOT FOUND: product-detection-config.csv"
        fi
        echo ""
        
        # Check node-config.conf
        local node_conf="${SCRIPT_DIR}/common/node-config.conf"
        echo "Checking: node-config.conf"
        if [ -f "$node_conf" ]; then
            echo "[OK] Found: $node_conf"
            echo "  Contents:"
            cat "$node_conf"
        else
            echo "[FAIL] NOT FOUND: $node_conf"
        fi
        echo ""
        
    } > "${TEST_06_DIR}/config_validation.txt"
    
    cat "${TEST_06_DIR}/config_validation.txt"
    print_success "Configuration validation completed"
    
    log_summary "Configuration validation: See ${TEST_06_DIR}/config_validation.txt"
    log_summary ""
}

# ============================================================================
# Final Summary
# ============================================================================

generate_final_summary() {
    print_header "Test Execution Complete"
    
    {
        echo ""
        echo "========================================================================"
        echo "Test Files Location"
        echo "========================================================================"
        echo "All test artifacts are stored in:"
        echo "  ${TEST_SESSION_DIR}"
        echo ""
        echo "Test directories:"
        echo "  - ${TEST_01_DIR} (Debug ON)"
        echo "  - ${TEST_02_DIR} (Debug OFF - Normal)"
        echo "  - ${TEST_03_DIR} (Debug OFF - Redirected)"
        echo "  - ${TEST_04_DIR} (Raw Commands)"
        echo "  - ${TEST_05_DIR} (Permissions)"
        echo "  - ${TEST_06_DIR} (Config Validation)"
        echo ""
        echo "To analyze results:"
        echo "  1. Review summary: cat ${TEST_SUMMARY}"
        echo "  2. Compare test outputs: diff test-01*/output/iwdli_output_*.csv test-02*/output/iwdli_output_*.csv"
        echo "  3. Check raw commands: ls -l ${TEST_04_DIR}"
        echo "  4. Package for remote analysis: tar -czf test-results.tar.gz ${TEST_SESSION_DIR}"
        echo ""
        echo "========================================================================"
    } >> "$TEST_SUMMARY"
    
    # Display summary
    cat "$TEST_SUMMARY"
    
    print_success "Complete test summary available at: ${TEST_SUMMARY}"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "IBM webMethods Default License Inspector - Test Suite"
    
    echo "Starting comprehensive test suite..."
    echo "Timestamp: ${TEST_TIMESTAMP}"
    echo ""
    
    # Run all tests
    setup_test_environment
    test_01_debug_on
    test_02_debug_off_normal
    test_03_debug_off_redirected
    test_04_raw_commands
    test_05_permission_check
    test_06_config_validation
    generate_final_summary
    
    print_header "All Tests Completed Successfully"
    print_success "Test results: ${TEST_SESSION_DIR}"
    print_success "Test summary: ${TEST_SUMMARY}"
    
    echo ""
    echo "Next steps:"
    echo "  1. Review the test summary file"
    echo "  2. Compare outputs between debug ON and OFF"
    echo "  3. Examine raw command outputs for debugging"
    echo "  4. Package results: tar -czf test-${TEST_TIMESTAMP}.tar.gz ${TEST_SESSION_DIR}"
    echo ""
    echo "Transport results back to code authoring space:"
    echo "  On Unix/Linux system:"
    echo "    tar -czf test-${TEST_TIMESTAMP}.tar.gz ${TEST_SESSION_DIR}"
    echo "  Then on Windows (PowerShell):"
    echo "    scp user@unix-host:/tmp/iwdlm/test/test-${TEST_TIMESTAMP}.tar.gz m:/r/o/r/c/iwcd/7u-overwatch/r/7u-legacy-license-monitor/local/"
    echo "  Or use WinSCP/FileZilla to transfer the .tar.gz file"
    echo ""
}

# Execute main function
main "$@"
