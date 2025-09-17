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

# Global variable for output file
OUTPUT_FILE=""

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
}

# Function to log debug information if INSPECT_DEBUG=ON
logD() {
    if [ "$INSPECT_DEBUG" = "ON" ]; then
        echo "[DEBUG] $1" >&2
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
            if lparstat -i 2>/dev/null | grep -q "Shared"; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="PowerVM - Micro-Partitioning"
                logD "PowerVM Micro-Partitioning detected"
            fi
        fi
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
            VIRT_INFO=$(virtinfo 2>/dev/null)
            logD "virtinfo output: ${VIRT_INFO}"
            if echo "$VIRT_INFO" | grep -q "LDoms"; then
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
        if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
            IS_VIRTUALIZED="yes"
            logD "Hypervisor flag found in CPU info"
        fi
        
        # Check DMI information
        if command -v dmidecode >/dev/null 2>&1; then
            logD "Using dmidecode for hardware detection"
            DMI_SYS_VENDOR=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_PRODUCT=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_VERSION=$(dmidecode -s system-version 2>/dev/null | tr '[:upper:]' '[:lower:]')
            
            logD "DMI_SYS_VENDOR=${DMI_SYS_VENDOR}"
            logD "DMI_SYS_PRODUCT=${DMI_SYS_PRODUCT}"
            logD "DMI_SYS_VERSION=${DMI_SYS_VERSION}"
            
            case "$DMI_SYS_VENDOR" in
                *vmware*)
                    IS_VIRTUALIZED="yes"
                    if echo "$DMI_SYS_PRODUCT" | grep -q "esxi"; then
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
            if grep -q "z/VM" /proc/sysinfo 2>/dev/null; then
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [output_file]"
    echo ""
    echo "Arguments:"
    echo "  output_file   Path to CSV output file (default: ./inspect_output.csv)"
    echo ""
    echo "This script detects system information and outputs it in CSV format with columns:"
    echo "  Parameter, Value"
    echo ""
    echo "Environment variables:"
    echo "  INSPECT_DEBUG=ON   Enable debug logging to stderr"
    echo ""
    echo "Supported platforms:"
    echo "  - AIX (PowerVM detection)"
    echo "  - Linux distributions (RHEL, SUSE, Ubuntu, CentOS, Debian, Oracle Linux)"
    echo "  - Solaris (Zones/Containers, Oracle VM for SPARC)"
    echo "  - Basic IBM i and Windows detection"
}

# Main execution
main() {
    # Set output file - use first argument or default
    if [ -n "$1" ]; then
        if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
            show_usage
            exit 0
        fi
        OUTPUT_FILE="$1"
    else
        OUTPUT_FILE="./inspect_output.csv"
    fi
    
    log "Starting system detection, output file: ${OUTPUT_FILE}"
    
    # Create CSV file with header
    echo "Parameter,Value" > "$OUTPUT_FILE"
    write_csv "detection_timestamp" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Detect system information
    detect_os
    detect_cpu_count
    detect_virtualization
    
    log "Detection complete. Results written to: ${OUTPUT_FILE}"
}

# Execute main function with all arguments
main "$@"
