#!/bin/sh
#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#
# System Information Detection Script
# POSIX-compliant script to detect:
# 1. Operating system name
# 2. Operating system version
# 3. Number of CPUs available
# 4. Virtualization status (running in VM or not)
# 5. Type of virtualization technology
#
# Supports: AIX, Linux (RHEL, SUSE, Ubuntu, CentOS, Debian, Oracle Linux), 
#          Solaris, IBM i detection capabilities, and basic Windows detection
#
# Author: Generated and refined by Mihai Ungureanu
# Date: September 16, 2025

set -e

# Global variables for results
OS_NAME=""
OS_VERSION=""
CPU_COUNT=""
IS_VIRTUALIZED="no"
VIRT_TYPE="none"
PROCESSOR_VENDOR=""
PROCESSOR_BRAND=""
PROCESSOR_ELIGIBLE="false"
OS_ELIGIBLE="false"
VIRT_ELIGIBLE="false"

# Global variable for output file
OUTPUT_FILE=""

# Global variable for script directory (to find CSV files)
SCRIPT_DIR=""

# Global variable for output directory and session folder
OUTPUT_DIR=""
SESSION_DIR=""
SESSION_LOG=""

# Function to write a parameter-value pair to CSV
write_csv() {
    local parameter="$1"
    local value="$2"
    echo "${parameter},${value}" >> "$OUTPUT_FILE"
    logD "CSV: ${parameter}=${value}"
}

# Function to log important information
log() {
    echo "[INFO] $1" >&2
    if [ -n "$SESSION_LOG" ]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$SESSION_LOG"
    fi
}

# Function to log debug information if INSPECT_DEBUG=ON
logD() {
    if [ "$INSPECT_DEBUG" = "ON" ]; then
        echo "[DEBUG] $1" >&2
        if [ -n "$SESSION_LOG" ]; then
            echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$SESSION_LOG"
        fi
    fi
}

# Function to run command with debug output capture
run_debug_cmd() {
    local cmd="$1"
    local cmd_name="$2"
    
    if [ "$INSPECT_DEBUG" = "ON" ] && [ -n "$SESSION_DIR" ]; then
        logD "Running command: $cmd"
        local out_file="${SESSION_DIR}/${cmd_name}.out"
        local err_file="${SESSION_DIR}/${cmd_name}.err"
        
        # Run command and capture both stdout and stderr
        eval "$cmd" >"$out_file" 2>"$err_file"
        local exit_code=$?
        
        logD "Command '$cmd' completed with exit code: $exit_code"
        logD "Output saved to: $out_file"
        logD "Errors saved to: $err_file"
        
        return $exit_code
    else
        # Regular execution without debug capture
        eval "$cmd"
    fi
}

# Function to detect operating system
detect_os() {
    os_name=$(uname -s)
    logD "os_name=${os_name}"
    
    # Check specific OS types first before generic checks
    if [ "$os_name" = "AIX" ]; then
        # IBM AIX
        log "Detected AIX system"
        OS_NAME="AIX"
        write_csv "OS_NAME" "AIX"
        # Get AIX version (e.g., 7.2, 7.3)
        AIX_VERSION=$(oslevel -s | cut -c1-4 | sed 's/\([0-9]\)\([0-9]\)/\1.\2/')
        logD "AIX_VERSION=${AIX_VERSION}"
        OS_VERSION="$AIX_VERSION"
        write_csv "OS_VERSION" "$AIX_VERSION"
    elif [ "$os_name" = "SunOS" ]; then
        # Oracle Solaris
        log "Detected Solaris system"
        OS_NAME="Solaris"
        write_csv "OS_NAME" "Solaris"
        OS_VERSION=$(uname -r | sed 's/5\.//')
        logD "Solaris version=${OS_VERSION}"
        write_csv "OS_VERSION" "$OS_VERSION"
    elif [ "$os_name" = "OS400" ] || [ -f /QSYS.LIB ]; then
        # IBM i (AS/400)
        log "Detected IBM i system"
        OS_NAME="IBM i"
        write_csv "OS_NAME" "IBM i"
        # Try to get IBM i version - this might need adjustment based on actual system
        if command -v system >/dev/null 2>&1; then
            OS_VERSION=$(system "DSPPTF" 2>/dev/null | head -1 | cut -d' ' -f2 2>/dev/null || echo "unknown")
        else
            OS_VERSION="unknown"
        fi
        logD "IBM i version=${OS_VERSION}"
        write_csv "OS_VERSION" "$OS_VERSION"
    elif echo "$PATH" | grep -i windows >/dev/null 2>&1 || [ -n "$WINDIR" ]; then
        # Basic Windows detection (limited in POSIX shell)
        log "Detected Windows system"
        OS_NAME="Windows"
        write_csv "OS_NAME" "Windows"
        OS_VERSION="unknown"
        write_csv "OS_VERSION" "unknown"
    elif [ -f /proc/version ]; then
        # Linux systems (check after other Unix variants)
        log "Detected Linux system"
        logD "Found /proc/version, checking Linux distribution"
        if [ -f /etc/os-release ]; then
            # Modern Linux distributions
            logD "Found /etc/os-release"
            . /etc/os-release
            OS_NAME="$NAME"
            OS_VERSION="$VERSION_ID"
            logD "Initial OS_NAME=${OS_NAME}, OS_VERSION=${OS_VERSION}"
            
            # Handle specific distributions
            case "$ID" in
                "rhel"|"redhat")
                    OS_NAME="Red Hat Enterprise Linux"
                    # Extract major.minor version
                    OS_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1-2)
                    logD "RHEL detected, adjusted version=${OS_VERSION}"
                    write_csv "OS_NAME" "Red Hat Enterprise Linux"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                "centos")
                    OS_NAME="CentOS"
                    OS_VERSION="$VERSION_ID"
                    logD "CentOS detected"
                    write_csv "OS_NAME" "CentOS"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                "sles"|"suse")
                    OS_NAME="SUSE Linux Enterprise Server"
                    OS_VERSION="$VERSION_ID"
                    logD "SUSE detected"
                    write_csv "OS_NAME" "SUSE Linux Enterprise Server"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                "ubuntu")
                    OS_NAME="Ubuntu"
                    OS_VERSION="$VERSION_ID"
                    logD "Ubuntu detected"
                    write_csv "OS_NAME" "Ubuntu"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                "debian")
                    OS_NAME="Debian"
                    OS_VERSION="$VERSION_ID"
                    logD "Debian detected"
                    write_csv "OS_NAME" "Debian"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                "ol"|"oracle")
                    OS_NAME="Oracle Linux"
                    OS_VERSION="$VERSION_ID"
                    logD "Oracle Linux detected"
                    write_csv "OS_NAME" "Oracle Linux"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
                *)
                    # Default case for unknown Linux distributions
                    write_csv "OS_NAME" "$OS_NAME"
                    write_csv "OS_VERSION" "$OS_VERSION"
                    ;;
            esac
        elif [ -f /etc/redhat-release ]; then
            # Older RHEL/CentOS systems
            logD "Found /etc/redhat-release"
            OS_NAME="Red Hat Enterprise Linux"
            OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/')
            logD "Legacy RHEL version=${OS_VERSION}"
            write_csv "OS_NAME" "Red Hat Enterprise Linux"
            write_csv "OS_VERSION" "$OS_VERSION"
        elif [ -f /etc/SuSE-release ]; then
            # Older SUSE systems
            logD "Found /etc/SuSE-release"
            OS_NAME="SUSE Linux Enterprise Server"
            OS_VERSION=$(grep "VERSION" /etc/SuSE-release | cut -d'=' -f2 | tr -d ' ')
            logD "Legacy SUSE version=${OS_VERSION}"
            write_csv "OS_NAME" "SUSE Linux Enterprise Server"
            write_csv "OS_VERSION" "$OS_VERSION"
        else
            # Generic Linux
            logD "Generic Linux fallback"
            OS_NAME="Linux"
            OS_VERSION=$(uname -r)
            logD "Generic Linux version=${OS_VERSION}"
            write_csv "OS_NAME" "Linux"
            write_csv "OS_VERSION" "$OS_VERSION"
        fi
    else
        # Unknown Unix-like system
        log "Unknown Unix-like system detected"
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
        logD "Unknown system: OS_NAME=${OS_NAME}, OS_VERSION=${OS_VERSION}"
        write_csv "OS_NAME" "$OS_NAME"
        write_csv "OS_VERSION" "$OS_VERSION"
    fi
    
    log "Final OS detection: ${OS_NAME} ${OS_VERSION}"
}

# Function to count CPUs
detect_cpu_count() {
    os_name=$(uname -s)
    logD "Detecting CPU count for ${os_name}"
    
    if [ "$os_name" = "AIX" ]; then
        # AIX - count online processors
        logD "Using AIX CPU detection methods"
        if command -v lsdev >/dev/null 2>&1; then
            CPU_COUNT=$(lsdev -Cc processor | grep -c Available || echo "1")
            logD "lsdev method: CPU_COUNT=${CPU_COUNT}"
        elif command -v bindprocessor >/dev/null 2>&1; then
            CPU_COUNT=$(bindprocessor -q | wc -w)
            logD "bindprocessor method: CPU_COUNT=${CPU_COUNT}"
        else
            CPU_COUNT="1"
            logD "AIX fallback: CPU_COUNT=${CPU_COUNT}"
        fi
    elif [ "$os_name" = "SunOS" ]; then
        # Solaris
        logD "Using Solaris CPU detection methods"
        if command -v psrinfo >/dev/null 2>&1; then
            CPU_COUNT=$(psrinfo | wc -l)
            logD "psrinfo method: CPU_COUNT=${CPU_COUNT}"
        else
            CPU_COUNT=$(kstat -m cpu_info | grep "module:" | wc -l)
            logD "kstat method: CPU_COUNT=${CPU_COUNT}"
        fi
    elif [ -f /proc/cpuinfo ]; then
        # Linux systems
        logD "Using Linux /proc/cpuinfo method"
        CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo)
        logD "Linux method: CPU_COUNT=${CPU_COUNT}"
    elif command -v sysctl >/dev/null 2>&1; then
        # BSD-like systems
        logD "Using BSD sysctl method"
        CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
        logD "BSD method: CPU_COUNT=${CPU_COUNT}"
    else
        # Fallback
        CPU_COUNT="1"
        logD "Fallback method: CPU_COUNT=${CPU_COUNT}"
    fi
    
    log "CPU count detected: ${CPU_COUNT}"
    write_csv "CPU_COUNT" "$CPU_COUNT"
}

# Function to detect virtualization
detect_virtualization() {
    IS_VIRTUALIZED="no"
    VIRT_TYPE="none"
    os_name=$(uname -s)
    
    log "Starting virtualization detection for ${os_name}"
    logD "Initial state: IS_VIRTUALIZED=${IS_VIRTUALIZED}, VIRT_TYPE=${VIRT_TYPE}"
    
    if [ "$os_name" = "AIX" ]; then
        # AIX - Check for PowerVM/LPAR
        logD "Checking AIX PowerVM/LPAR detection"
        if command -v uname >/dev/null 2>&1; then
            if uname -L >/dev/null 2>&1; then
                LPAR_ID=$(uname -L 2>/dev/null)
                logD "LPAR_ID=${LPAR_ID}"
                if [ -n "$LPAR_ID" ] && [ "$LPAR_ID" != "-1" ]; then
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="PowerVM - LPAR"
                    logD "PowerVM LPAR detected"
                fi
            fi
        fi
        
        # Check for micro-partitioning
        logD "Checking AIX micro-partitioning"
        if command -v lparstat >/dev/null 2>&1; then
            run_debug_cmd "lparstat" "lparstat"
            run_debug_cmd "lparstat -i" "lparstat-i"
            if lparstat -i 2>/dev/null | grep "Shared" >/dev/null 2>&1; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="PowerVM - Micro-Partitioning"
                logD "PowerVM Micro-Partitioning detected"
            fi
        fi
        
    elif [ "$os_name" = "SunOS" ]; then
        # Solaris - Check for zones/containers
        logD "Checking Solaris zones/containers"
        if command -v zonename >/dev/null 2>&1; then
            ZONE_NAME=$(zonename 2>/dev/null)
            logD "ZONE_NAME=${ZONE_NAME}"
            if [ -n "$ZONE_NAME" ] && [ "$ZONE_NAME" != "global" ]; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="Containers/Zones"
                logD "Solaris zone detected: ${ZONE_NAME}"
            fi
        fi
        
        # Check for Oracle VM Server for SPARC (LDoms)
        logD "Checking Oracle VM Server for SPARC (LDoms)"
        if command -v virtinfo >/dev/null 2>&1; then
            run_debug_cmd "virtinfo" "virtinfo"
            VIRT_INFO=$(virtinfo 2>/dev/null)
            logD "virtinfo output: ${VIRT_INFO}"
            if echo "$VIRT_INFO" | grep "LDoms" >/dev/null 2>&1; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="Oracle VM Server for SPARC"
                logD "Oracle VM Server for SPARC detected"
            fi
        fi
        
    elif [ -f /proc/cpuinfo ]; then
        # Linux systems - multiple detection methods
        logD "Checking Linux virtualization detection methods"
        
        # Check for hypervisor flag in CPU
        logD "Checking for hypervisor flag in /proc/cpuinfo"
        if grep "hypervisor" /proc/cpuinfo >/dev/null 2>&1; then
            IS_VIRTUALIZED="yes"
            logD "Hypervisor flag found in CPU info"
        fi
        
        # Check DMI information
        if command -v dmidecode >/dev/null 2>&1; then
            logD "Using dmidecode for hardware detection"
            run_debug_cmd "dmidecode -s system-manufacturer" "dmidecode-manufacturer"
            run_debug_cmd "dmidecode -s system-product-name" "dmidecode-product"
            run_debug_cmd "dmidecode -s system-version" "dmidecode-version"
            
            DMI_SYS_VENDOR=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_PRODUCT=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_VERSION=$(dmidecode -s system-version 2>/dev/null | tr '[:upper:]' '[:lower:]')
            
            logD "DMI_SYS_VENDOR=${DMI_SYS_VENDOR}"
            logD "DMI_SYS_PRODUCT=${DMI_SYS_PRODUCT}"
            logD "DMI_SYS_VERSION=${DMI_SYS_VERSION}"
            
            case "$DMI_SYS_VENDOR" in
                *vmware*)
                    IS_VIRTUALIZED="yes"
                    if echo "$DMI_SYS_PRODUCT" | grep "esxi" >/dev/null 2>&1; then
                        VIRT_TYPE="VMware vSphere (ESXi)"
                    else
                        VIRT_TYPE="VMware"
                    fi
                    logD "VMware virtualization detected: ${VIRT_TYPE}"
                    ;;
                *microsoft*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="MS Hyper-V"
                    logD "Microsoft Hyper-V detected"
                    ;;
                *citrix*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="CITRIX Hypervisor"
                    logD "Citrix Hypervisor detected"
                    ;;
                *qemu*|*kvm*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="KVM hypervisor"
                    logD "KVM hypervisor detected"
                    ;;
                *oracle*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="Oracle VM"
                    logD "Oracle VM detected"
                    ;;
                *nutanix*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="Nutanix AHV (PRISM)"
                    logD "Nutanix AHV detected"
                    ;;
                *ibm*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="IBM Virtualization"
                    logD "IBM Virtualization detected"
                    ;;
            esac
        fi
        
        # Check /sys/hypervisor
        logD "Checking /sys/hypervisor"
        if [ -d /sys/hypervisor ]; then
            IS_VIRTUALIZED="yes"
            logD "/sys/hypervisor directory found"
            if [ -f /sys/hypervisor/type ]; then
                HYPERVISOR_TYPE=$(cat /sys/hypervisor/type 2>/dev/null)
                logD "Hypervisor type: ${HYPERVISOR_TYPE}"
                case "$HYPERVISOR_TYPE" in
                    "xen") VIRT_TYPE="Xen" ;;
                    *) VIRT_TYPE="$HYPERVISOR_TYPE" ;;
                esac
            fi
        fi
        
        # Check for specific virtualization indicators
        logD "Checking for Xen capabilities"
        if [ -f /proc/xen/capabilities ] 2>/dev/null; then
            IS_VIRTUALIZED="yes"
            VIRT_TYPE="Xen"
            logD "Xen capabilities file found"
        fi
        
        # Check systemd-detect-virt if available
        logD "Checking systemd-detect-virt"
        if command -v systemd-detect-virt >/dev/null 2>&1; then
            run_debug_cmd "systemd-detect-virt" "systemd-detect-virt"
            DETECTED_VIRT=$(systemd-detect-virt 2>/dev/null)
            logD "systemd-detect-virt result: ${DETECTED_VIRT}"
            if [ "$?" -eq 0 ] && [ "$DETECTED_VIRT" != "none" ]; then
                IS_VIRTUALIZED="yes"
                case "$DETECTED_VIRT" in
                    "vmware") VIRT_TYPE="VMware vSphere" ;;
                    "microsoft") VIRT_TYPE="MS Hyper-V" ;;
                    "kvm") VIRT_TYPE="KVM hypervisor" ;;
                    "xen") VIRT_TYPE="Xen" ;;
                    "oracle") VIRT_TYPE="Oracle VM" ;;
                    *) VIRT_TYPE="$DETECTED_VIRT" ;;
                esac
                logD "systemd-detect-virt mapped to: ${VIRT_TYPE}"
            fi
        fi
        
        # Check for z/VM (IBM mainframe)
        logD "Checking for z/VM"
        if [ -f /proc/sysinfo ]; then
            if grep "z/VM" /proc/sysinfo >/dev/null 2>&1; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="z/VM"
                logD "z/VM detected in /proc/sysinfo"
            fi
        fi
        
        # Check dmesg for virtualization clues (if accessible)
        logD "Checking dmesg for virtualization clues"
        if command -v dmesg >/dev/null 2>&1; then
            DMESG_OUTPUT=$(dmesg 2>/dev/null | head -50)
            if echo "$DMESG_OUTPUT" | grep -qi "hypervisor\|vmware\|kvm\|xen"; then
                IS_VIRTUALIZED="yes"
                logD "Virtualization indicators found in dmesg"
                if [ "$VIRT_TYPE" = "none" ]; then
                    if echo "$DMESG_OUTPUT" | grep -qi "vmware"; then
                        VIRT_TYPE="VMware"
                        logD "VMware detected in dmesg"
                    elif echo "$DMESG_OUTPUT" | grep -qi "kvm"; then
                        VIRT_TYPE="KVM hypervisor"
                        logD "KVM detected in dmesg"
                    elif echo "$DMESG_OUTPUT" | grep -qi "xen"; then
                        VIRT_TYPE="Xen"
                        logD "Xen detected in dmesg"
                    else
                        VIRT_TYPE="Unknown hypervisor"
                        logD "Unknown hypervisor detected in dmesg"
                    fi
                fi
            fi
        fi
    fi
    
    # If we detected virtualization but don't have a specific type
    if [ "$IS_VIRTUALIZED" = "yes" ] && [ "$VIRT_TYPE" = "none" ]; then
        VIRT_TYPE="Unknown"
        logD "Virtualization detected but type unknown"
    fi
    
    log "Virtualization detection complete: ${IS_VIRTUALIZED}, Type: ${VIRT_TYPE}"
    write_csv "IS_VIRTUALIZED" "$IS_VIRTUALIZED"
    write_csv "VIRT_TYPE" "$VIRT_TYPE"
}

# Function to detect processor information
detect_processor() {
    PROCESSOR_VENDOR=""
    PROCESSOR_BRAND=""
    os_name=$(uname -s)
    
    log "Starting processor detection for ${os_name}"
    
    if [ "$os_name" = "AIX" ]; then
        # AIX - Use prtconf or lsattr to get processor info
        logD "Detecting AIX processor information"
        if command -v prtconf >/dev/null 2>&1; then
            run_debug_cmd "prtconf" "prtconf"
            PROC_INFO=$(prtconf | grep -i "processor\|system model" | head -10)
            logD "prtconf processor info: ${PROC_INFO}"
            
            # Look for Processor Type line (e.g., "Processor Type: PowerPC_POWER8")
            PROC_TYPE=$(prtconf | grep "Processor Type:" | cut -d':' -f2 | sed 's/^[ \t]*//')
            logD "Processor Type from prtconf: ${PROC_TYPE}"
            
            # IBM Power processors
            if echo "$PROC_TYPE" | grep -i "power"; then
                PROCESSOR_VENDOR="IBM"
                if echo "$PROC_TYPE" | grep -i "power10"; then
                    PROCESSOR_BRAND="POWER10"
                elif echo "$PROC_TYPE" | grep -i "power9"; then
                    PROCESSOR_BRAND="POWER9"
                elif echo "$PROC_TYPE" | grep -i "power8"; then
                    PROCESSOR_BRAND="POWER8"
                elif echo "$PROC_TYPE" | grep -i "power7"; then
                    PROCESSOR_BRAND="POWER7"
                elif echo "$PROC_TYPE" | grep -i "power6"; then
                    PROCESSOR_BRAND="POWER6"
                elif echo "$PROC_TYPE" | grep -i "power5"; then
                    PROCESSOR_BRAND="POWER5"
                elif echo "$PROC_TYPE" | grep -i "power4"; then
                    PROCESSOR_BRAND="POWER4"
                elif echo "$PROC_TYPE" | grep -i "power3"; then
                    PROCESSOR_BRAND="POWER3"
                else
                    PROCESSOR_BRAND="POWER"
                fi
                logD "IBM Power processor detected: ${PROCESSOR_BRAND}"
            fi
        fi
        
    elif [ "$os_name" = "SunOS" ]; then
        # Solaris - Use psrinfo or isainfo
        logD "Detecting Solaris processor information"
        if command -v psrinfo >/dev/null 2>&1; then
            # Try psrinfo -pv first for detailed processor info
            run_debug_cmd "psrinfo -pv" "psrinfo-pv"
            run_debug_cmd "psrinfo -v" "psrinfo-v"
            run_debug_cmd "psrinfo" "psrinfo"
            
            PROC_INFO=$(psrinfo -pv 2>/dev/null | head -10)
            if [ -z "$PROC_INFO" ]; then
                # Fallback to psrinfo -v for older Solaris versions
                PROC_INFO=$(psrinfo -v 2>/dev/null | head -10)
            fi
            logD "psrinfo processor info: ${PROC_INFO}"
            
            # Check for SPARC processors
            if echo "$PROC_INFO" | grep -i "sparc" >/dev/null 2>&1; then
                # Determine if it's Oracle or Fujitsu SPARC
                if echo "$PROC_INFO" | grep -i "sparc.*m8" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC M8"
                elif echo "$PROC_INFO" | grep -i "sparc.*m7" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC M7"
                elif echo "$PROC_INFO" | grep -i "sparc.*m6" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC M6"
                elif echo "$PROC_INFO" | grep -i "sparc.*m5" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC M5"
                elif echo "$PROC_INFO" | grep -i "sparc.*t5" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC T5"
                elif echo "$PROC_INFO" | grep -i "sparc.*t4" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC T4"
                elif echo "$PROC_INFO" | grep -i "ultrasparc.*t3\|niagara.*3" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC T3 (Niagara 3)"
                elif echo "$PROC_INFO" | grep -i "ultrasparc.*t2\|niagara.*2" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC T2 (Niagara 2)"
                elif echo "$PROC_INFO" | grep -i "ultrasparc.*t1\|niagara.*1" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC T1 (Niagara 1)"
                elif echo "$PROC_INFO" | grep -i "ultrasparc.*iv" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC IV"
                elif echo "$PROC_INFO" | grep -i "ultrasparc.*iii" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC III"
                elif echo "$PROC_INFO" | grep -i "sparc64.*xii" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Fujitsu"
                    PROCESSOR_BRAND="SPARC64 XII"
                elif echo "$PROC_INFO" | grep -i "sparc64.*x" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Fujitsu"
                    PROCESSOR_BRAND="SPARC64 X/X+"
                elif echo "$PROC_INFO" | grep -i "sparc64.*vii" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Fujitsu"
                    PROCESSOR_BRAND="SPARC64 VII"
                elif echo "$PROC_INFO" | grep -i "sparc64.*vi" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Fujitsu"
                    PROCESSOR_BRAND="SPARC64 VI"
                elif echo "$PROC_INFO" | grep -i "sparc64.*v" >/dev/null 2>&1; then
                    PROCESSOR_VENDOR="Fujitsu"
                    PROCESSOR_BRAND="SPARC64 V"
                elif echo "$PROC_INFO" | grep -i "sparcv9" >/dev/null 2>&1; then
                    # Generic SPARC v9 - could be UltraSPARC III or IV
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="UltraSPARC III"
                else
                    PROCESSOR_VENDOR="Oracle"
                    PROCESSOR_BRAND="SPARC"
                fi
                logD "SPARC processor detected: ${PROCESSOR_VENDOR} ${PROCESSOR_BRAND}"
            fi
        fi
        
    elif [ -f /proc/cpuinfo ]; then
        # Linux systems - Read /proc/cpuinfo
        logD "Detecting Linux processor information from /proc/cpuinfo"
        
        # Get vendor and model info
        VENDOR_ID=$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | sed 's/^[ \t]*//')
        MODEL_NAME=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | sed 's/^[ \t]*//')
        CPU_FAMILY=$(grep -m1 "cpu family" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | sed 's/^[ \t]*//')
        
        logD "vendor_id: ${VENDOR_ID}"
        logD "model name: ${MODEL_NAME}"
        logD "cpu family: ${CPU_FAMILY}"
        
        case "$VENDOR_ID" in
            "GenuineIntel")
                PROCESSOR_VENDOR="Intel"
                # Determine Intel processor type from model name
                if echo "$MODEL_NAME" | grep -qi "xeon"; then
                    PROCESSOR_BRAND="Xeon - All Processor Numbers"
                elif echo "$MODEL_NAME" | grep -qi "pentium"; then
                    PROCESSOR_BRAND="Pentium - All Processor Numbers"
                elif echo "$MODEL_NAME" | grep -qi "core"; then
                    PROCESSOR_BRAND="Core - All Processor Numbers"
                else
                    # Default to Xeon for unknown Intel processors in server context
                    PROCESSOR_BRAND="Xeon - All Processor Numbers"
                fi
                logD "Intel processor detected: ${PROCESSOR_BRAND}"
                ;;
            "AuthenticAMD")
                PROCESSOR_VENDOR="AMD"
                if echo "$MODEL_NAME" | grep -qi "epyc"; then
                    PROCESSOR_BRAND="Epyc"
                elif echo "$MODEL_NAME" | grep -qi "opteron.*6[0-9][0-9][0-9]"; then
                    PROCESSOR_BRAND="Opteron 6000 series"
                elif echo "$MODEL_NAME" | grep -qi "opteron"; then
                    PROCESSOR_BRAND="Opteron"
                else
                    # Default based on CPU family or model name
                    if [ "$CPU_FAMILY" = "23" ] || [ "$CPU_FAMILY" = "25" ]; then
                        PROCESSOR_BRAND="Epyc"
                    else
                        PROCESSOR_BRAND="Opteron"
                    fi
                fi
                logD "AMD processor detected: ${PROCESSOR_BRAND}"
                ;;
            *)
                # Check for other architectures
                ARCH=$(uname -m)
                logD "Architecture: ${ARCH}"
                case "$ARCH" in
                    "s390x"|"s390")
                        PROCESSOR_VENDOR="IBM"
                        PROCESSOR_BRAND="System z - All IFL or CP engines"
                        logD "IBM System z detected"
                        ;;
                    "ppc64"|"ppc64le"|"ppc")
                        PROCESSOR_VENDOR="IBM"
                        # Try to determine Power version from /proc/cpuinfo
                        if grep -qi "power10" /proc/cpuinfo; then
                            PROCESSOR_BRAND="POWER10"
                        elif grep -qi "power9" /proc/cpuinfo; then
                            PROCESSOR_BRAND="POWER9"
                        elif grep -qi "power8" /proc/cpuinfo; then
                            PROCESSOR_BRAND="POWER8"
                        elif grep -qi "power7" /proc/cpuinfo; then
                            PROCESSOR_BRAND="POWER7"
                        else
                            PROCESSOR_BRAND="POWER"
                        fi
                        logD "IBM Power processor detected: ${PROCESSOR_BRAND}"
                        ;;
                    *)
                        logD "Unknown processor architecture: ${ARCH}"
                        ;;
                esac
                ;;
        esac
    fi
    
    # Set defaults if detection failed
    if [ -z "$PROCESSOR_VENDOR" ]; then
        PROCESSOR_VENDOR="Unknown"
        logD "Processor vendor could not be determined"
    fi
    if [ -z "$PROCESSOR_BRAND" ]; then
        PROCESSOR_BRAND="Unknown"
        logD "Processor brand could not be determined"
    fi
    
    log "Processor detection complete: ${PROCESSOR_VENDOR} ${PROCESSOR_BRAND}"
    write_csv "PROCESSOR_VENDOR" "$PROCESSOR_VENDOR"
    write_csv "PROCESSOR_BRAND" "$PROCESSOR_BRAND"
}

# Function to check processor eligibility
check_processor_eligibility() {
    PROCESSOR_ELIGIBLE="false"
    local processors_csv="${SCRIPT_DIR}/ibm-eligible-processors.csv"
    
    logD "Checking processor eligibility using: ${processors_csv}"
    
    if [ ! -f "$processors_csv" ]; then
        log "Warning: Processor eligibility file not found: ${processors_csv}"
        write_csv "PROCESSOR_ELIGIBLE" "$PROCESSOR_ELIGIBLE"
        return
    fi
    
    if [ "$PROCESSOR_VENDOR" = "Unknown" ] || [ "$PROCESSOR_BRAND" = "Unknown" ]; then
        logD "Cannot check processor eligibility - vendor or brand unknown"
        write_csv "PROCESSOR_ELIGIBLE" "$PROCESSOR_ELIGIBLE"
        return
    fi
    
    # Read CSV file and check for matches
    # Skip header line and search for processor vendor/brand combination
    while IFS=',' read -r vendor brand type os version || [ -n "$vendor" ]; do
        # Skip empty lines and header
        [ -z "$vendor" ] && continue
        [ "$vendor" = "processor-vendor" ] && continue
        
        logD "Checking: vendor='${vendor}' brand='${brand}' against '${PROCESSOR_VENDOR}' '${PROCESSOR_BRAND}'"
        
        # Compare vendor and brand (case insensitive)
        if echo "$vendor" | grep "^${PROCESSOR_VENDOR}$" >/dev/null 2>&1 && echo "$brand" | grep "^${PROCESSOR_BRAND}" >/dev/null 2>&1; then
            PROCESSOR_ELIGIBLE="true"
            logD "Processor eligibility match found: ${vendor} ${brand}"
            break
        fi
    done < "$processors_csv"
    
    log "Processor eligibility check complete: ${PROCESSOR_ELIGIBLE}"
    write_csv "PROCESSOR_ELIGIBLE" "$PROCESSOR_ELIGIBLE"
}

# Function to check OS and virtualization eligibility
check_os_virt_eligibility() {
    OS_ELIGIBLE="false"
    VIRT_ELIGIBLE="false"
    local virt_os_csv="${SCRIPT_DIR}/ibm-eligible-virt-and-os.csv"
    
    logD "Checking OS and virtualization eligibility using: ${virt_os_csv}"
    
    if [ ! -f "$virt_os_csv" ]; then
        log "Warning: OS/Virtualization eligibility file not found: ${virt_os_csv}"
        write_csv "OS_ELIGIBLE" "$OS_ELIGIBLE"
        write_csv "VIRT_ELIGIBLE" "$VIRT_ELIGIBLE"
        return
    fi
    
    # Normalize OS name for comparison
    local normalized_os_name=""
    case "$OS_NAME" in
        "Red Hat Enterprise Linux")
            normalized_os_name="Red Hat Enterprise Linux"
            ;;
        "SUSE Linux Enterprise Server")
            normalized_os_name="SUSE Linux Enterprise Server"
            ;;
        "AIX")
            normalized_os_name="AIX"
            ;;
        "Solaris")
            normalized_os_name="Solaris"
            ;;
        "Ubuntu")
            normalized_os_name="Ubuntu"
            ;;
        "CentOS")
            normalized_os_name="CentOS"
            ;;
        "Debian")
            normalized_os_name="Debian"
            ;;
        "Oracle Linux")
            normalized_os_name="Oracle Linux"
            ;;
        "IBM i")
            normalized_os_name="IBM i"
            ;;
        "Windows")
            normalized_os_name="Windows"
            ;;
        *)
            normalized_os_name="$OS_NAME"
            ;;
    esac
    
    # Normalize virtualization type for comparison
    local normalized_virt_type=""
    case "$VIRT_TYPE" in
        "PowerVM - Micro-Partitioning")
            normalized_virt_type="PowerVM - Micro-Partitioning"
            ;;
        "PowerVM - LPAR")
            normalized_virt_type="PowerVM - LPAR"
            ;;
        "KVM hypervisor")
            normalized_virt_type="KVM hypervisor standalone"
            ;;
        "VMware vSphere"|"VMware")
            normalized_virt_type="VMware vSphere"
            ;;
        "MS Hyper-V")
            normalized_virt_type="MS Hyper-V"
            ;;
        "CITRIX Hypervisor")
            normalized_virt_type="CITRIX Hypervisor"
            ;;
        "Nutanix AHV (PRISM)")
            normalized_virt_type="Nutanix AHV (PRISM)"
            ;;
        "z/VM")
            normalized_virt_type="z/VM"
            ;;
        "Containers/Zones")
            normalized_virt_type="Containers/Zones"
            ;;
        "none")
            # For non-virtualized systems, we don't check virtualization eligibility
            normalized_virt_type="none"
            ;;
        *)
            normalized_virt_type="$VIRT_TYPE"
            ;;
    esac
    
    logD "Normalized OS: '${normalized_os_name}', Normalized Virt: '${normalized_virt_type}'"
    
    # For physical systems, determine OS eligibility based on known IBM-supported OS types
    # regardless of version (the CSV only contains virtualization-specific constraints)
    if [ "$IS_VIRTUALIZED" = "no" ]; then
        case "$normalized_os_name" in
            "AIX"|"Solaris"|"Red Hat Enterprise Linux"|"SUSE Linux Enterprise Server"|"IBM i")
                OS_ELIGIBLE="true"
                VIRT_ELIGIBLE="false"  # Physical systems have no virtualization, so not virt eligible
                logD "Physical system with IBM-supported OS (${normalized_os_name}) - OS eligible, no virtualization"
                ;;
            *)
                logD "Physical system with unsupported OS (${normalized_os_name}) - not eligible"
                ;;
        esac
    else
        # For virtualized systems, check against CSV for version-specific requirements
        local found_virt_match="false"
        while IFS=',' read -r virt_vendor virt_tech eligible_os sub_cap_form ilmt_version || [ -n "$virt_vendor" ]; do
            # Skip empty lines and header
            [ -z "$virt_vendor" ] && continue
            [ "$virt_vendor" = "virtualization-vendor" ] && continue
            
            # Check if this CSV entry matches our OS and meets version requirements
            local os_virt_match="false"
            if echo "$eligible_os" | grep "$normalized_os_name" >/dev/null 2>&1; then
                # Check if version requirements are met for virtualized systems
                local version_match="true"
                case "$normalized_os_name" in
                    "AIX")
                        # Extract version requirement from eligible_os (e.g., "AIX 7.1" -> "7.1")
                        if echo "$eligible_os" | grep "AIX.*[0-9]" >/dev/null 2>&1; then
                            local required_version=$(echo "$eligible_os" | sed 's/.*AIX \([0-9.]*\).*/\1/')
                            logD "AIX virtualization version check: detected=${OS_VERSION}, required=${required_version}, eligible_os=${eligible_os}"
                            if [ -n "$required_version" ]; then
                                # Convert versions to numbers for comparison (e.g., 7.200 -> 720, 6.100 -> 610)
                                local detected_num=$(echo "$OS_VERSION" | sed 's/\([0-9]*\)\.\([0-9]*\).*/\1\2/' | sed 's/^0*//')
                                local required_num=$(echo "$required_version" | sed 's/\([0-9]*\)\.\([0-9]*\).*/\1\2/' | sed 's/^0*//')
                                if [ "$detected_num" -lt "$required_num" ] 2>/dev/null; then
                                    version_match="false"
                                    logD "AIX version ${OS_VERSION} (${detected_num}) does not meet virtualization requirement ${required_version} (${required_num})"
                                else
                                    logD "AIX version ${OS_VERSION} (${detected_num}) meets virtualization requirement ${required_version} (${required_num})"
                                fi
                            fi
                        fi
                        ;;
                    "Solaris")
                        # Extract version requirement from eligible_os (e.g., "Solaris 11" -> "11")
                        if echo "$eligible_os" | grep "Solaris.*[0-9]" >/dev/null 2>&1; then
                            local required_version=$(echo "$eligible_os" | sed 's/.*Solaris \([0-9]*\).*/\1/')
                            logD "Solaris virtualization version check: detected=${OS_VERSION}, required=${required_version}, eligible_os=${eligible_os}"
                            if [ -n "$required_version" ]; then
                                local detected_num=$(echo "$OS_VERSION" | sed 's/^0*//')
                                local required_num=$(echo "$required_version" | sed 's/^0*//')
                                if [ "$detected_num" -lt "$required_num" ] 2>/dev/null; then
                                    version_match="false"
                                    logD "Solaris version ${OS_VERSION} (${detected_num}) does not meet virtualization requirement ${required_version} (${required_num})"
                                else
                                    logD "Solaris version ${OS_VERSION} (${detected_num}) meets virtualization requirement ${required_version} (${required_num})"
                                fi
                            fi
                        fi
                        ;;
                    "Red Hat Enterprise Linux")
                        # Extract version requirement from eligible_os
                        if echo "$eligible_os" | grep "Red Hat Enterprise Linux.*[0-9]" >/dev/null 2>&1; then
                            local required_version=$(echo "$eligible_os" | sed 's/.*Red Hat Enterprise Linux \([0-9]*\).*/\1/')
                            logD "RHEL virtualization version check: detected=${OS_VERSION}, required=${required_version}, eligible_os=${eligible_os}"
                            if [ -n "$required_version" ]; then
                                local detected_major=$(echo "$OS_VERSION" | cut -d'.' -f1)
                                if [ "$detected_major" -lt "$required_version" ] 2>/dev/null; then
                                    version_match="false"
                                    logD "RHEL version ${OS_VERSION} does not meet virtualization requirement ${required_version}"
                                else
                                    logD "RHEL version ${OS_VERSION} meets virtualization requirement ${required_version}"
                                fi
                            fi
                        fi
                        ;;
                    *)
                        # For other OS types, simple name match is sufficient
                        logD "OS ${normalized_os_name} - simple name match for virtualization, eligible_os=${eligible_os}"
                        ;;
                esac
                
                if [ "$version_match" = "true" ]; then
                    os_virt_match="true"
                    OS_ELIGIBLE="true"
                    logD "OS virtualization eligibility match found: ${eligible_os}"
                    
                    # Check if this specific virtualization technology matches
                    if echo "$virt_tech" | grep "$normalized_virt_type" >/dev/null 2>&1; then
                        VIRT_ELIGIBLE="true"
                        found_virt_match="true"
                        logD "Virtualization technology match found: ${virt_tech} for OS ${eligible_os}"
                    fi
                fi
            fi
        done < "$virt_os_csv"
    fi
    
    log "OS eligibility check complete: ${OS_ELIGIBLE}"
    log "Virtualization eligibility check complete: ${VIRT_ELIGIBLE}"
    write_csv "OS_ELIGIBLE" "$OS_ELIGIBLE"
    write_csv "VIRT_ELIGIBLE" "$VIRT_ELIGIBLE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [output_directory]"
    echo ""
    echo "Arguments:"
    echo "  output_directory  Path to output directory (default: ./detection-output)"
    echo ""
    echo "This script creates a timestamped subdirectory within the output directory"
    echo "and generates the following files:"
    echo "  - inspect_output.csv: Main detection results in CSV format"
    echo "  - session.log: Detailed logging of the detection session"
    echo "  - [command].out/.err: Command outputs when INSPECT_DEBUG=ON"
    echo ""
    echo "Output parameters include:"
    echo "  - detection_timestamp: ISO 8601 timestamp"
    echo "  - OS_NAME, OS_VERSION: Operating system information"
    echo "  - CPU_COUNT: Number of available CPUs"
    echo "  - IS_VIRTUALIZED: yes/no if running on virtualized platform"
    echo "  - VIRT_TYPE: Type of virtualization technology"
    echo "  - PROCESSOR_VENDOR, PROCESSOR_BRAND: Processor information"
    echo "  - PROCESSOR_ELIGIBLE: true/false if processor is IBM-eligible"
    echo "  - OS_ELIGIBLE: true/false if OS is IBM-eligible"
    echo "  - VIRT_ELIGIBLE: true/false if virtualization is IBM-eligible"
    echo ""
    echo "Environment variables:"
    echo "  INSPECT_DEBUG=ON   Enable debug logging and command output capture"
    echo ""
    echo "Supported platforms:"
    echo "  - AIX (PowerVM detection)"
    echo "  - Linux distributions (RHEL, SUSE, Ubuntu, CentOS, Debian, Oracle Linux)"
    echo "  - Solaris (Zones/Containers, Oracle VM for SPARC)"
    echo "  - Basic IBM i and Windows detection"
    echo ""
    echo "Note: Eligibility checking requires ibm-eligible-processors.csv and"
    echo "      ibm-eligible-virt-and-os.csv files in the same directory as this script."
}

# Main execution
main() {
    # Determine script directory for CSV file locations
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    logD "Script directory: ${SCRIPT_DIR}"
    
    # Set output directory - use first argument or default
    if [ -n "$1" ]; then
        if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
            show_usage
            exit 0
        fi
        OUTPUT_DIR="$1"
    else
        OUTPUT_DIR="./detection-output"
    fi
    
    # Create timestamped session directory
    TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
    SESSION_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
    
    # Create directories if they don't exist
    mkdir -p "$SESSION_DIR" || {
        echo "Error: Cannot create session directory: $SESSION_DIR" >&2
        exit 1
    }
    
    # Set output file and session log
    OUTPUT_FILE="${SESSION_DIR}/inspect_output.csv"
    SESSION_LOG="${SESSION_DIR}/session.log"
    
    # Initialize session log
    echo "=== System Detection Session Started ===" > "$SESSION_LOG"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$SESSION_LOG"
    echo "Session Directory: $SESSION_DIR" >> "$SESSION_LOG"
    echo "Debug Mode: ${INSPECT_DEBUG:-OFF}" >> "$SESSION_LOG"
    echo "=========================================" >> "$SESSION_LOG"
    echo "" >> "$SESSION_LOG"
    
    log "Starting system detection"
    log "Session directory: ${SESSION_DIR}"
    log "Output file: ${OUTPUT_FILE}"
    log "Session log: ${SESSION_LOG}"
    
    # Create CSV file with header
    echo "Parameter,Value" > "$OUTPUT_FILE"
    write_csv "detection_timestamp" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    write_csv "session_directory" "$SESSION_DIR"
    
    # Detect system information
    detect_os
    detect_cpu_count
    detect_virtualization
    detect_processor
    
    # Check eligibility
    check_processor_eligibility
    check_os_virt_eligibility
    
    log "Detection complete. Results written to: ${OUTPUT_FILE}"
    log "Session log available at: ${SESSION_LOG}"
    
    # Final session log entry
    echo "" >> "$SESSION_LOG"
    echo "=== System Detection Session Completed ===" >> "$SESSION_LOG"
    echo "End Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$SESSION_LOG"
    echo "==========================================" >> "$SESSION_LOG"
}

# Execute main function with all arguments
main "$@"
