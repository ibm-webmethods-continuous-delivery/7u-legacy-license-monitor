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
# Author: Generated
# Date: September 16, 2025

set -e

# Global variables for results
OS_NAME=""
OS_VERSION=""
CPU_COUNT=""
IS_VIRTUALIZED="no"
VIRT_TYPE="none"

# Function to detect operating system
detect_os() {
    if [ -f /proc/version ]; then
        # Linux systems
        if [ -f /etc/os-release ]; then
            # Modern Linux distributions
            . /etc/os-release
            OS_NAME="$NAME"
            OS_VERSION="$VERSION_ID"
            
            # Handle specific distributions
            case "$ID" in
                "rhel"|"redhat")
                    OS_NAME="Red Hat Enterprise Linux"
                    # Extract major.minor version
                    OS_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1-2)
                    ;;
                "centos")
                    OS_NAME="CentOS"
                    OS_VERSION="$VERSION_ID"
                    ;;
                "sles"|"suse")
                    OS_NAME="SUSE Linux Enterprise Server"
                    OS_VERSION="$VERSION_ID"
                    ;;
                "ubuntu")
                    OS_NAME="Ubuntu"
                    OS_VERSION="$VERSION_ID"
                    ;;
                "debian")
                    OS_NAME="Debian"
                    OS_VERSION="$VERSION_ID"
                    ;;
                "ol"|"oracle")
                    OS_NAME="Oracle Linux"
                    OS_VERSION="$VERSION_ID"
                    ;;
            esac
        elif [ -f /etc/redhat-release ]; then
            # Older RHEL/CentOS systems
            OS_NAME="Red Hat Enterprise Linux"
            OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/')
        elif [ -f /etc/SuSE-release ]; then
            # Older SUSE systems
            OS_NAME="SUSE Linux Enterprise Server"
            OS_VERSION=$(grep "VERSION" /etc/SuSE-release | cut -d'=' -f2 | tr -d ' ')
        else
            # Generic Linux
            OS_NAME="Linux"
            OS_VERSION=$(uname -r)
        fi
    elif [ "$(uname -s)" = "AIX" ]; then
        # IBM AIX
        OS_NAME="AIX"
        # Get AIX version (e.g., 7.2, 7.3)
        AIX_VERSION=$(oslevel -s | cut -c1-4 | sed 's/\([0-9]\)\([0-9]\)/\1.\2/')
        OS_VERSION="$AIX_VERSION"
    elif [ "$(uname -s)" = "SunOS" ]; then
        # Oracle Solaris
        OS_NAME="Solaris"
        OS_VERSION=$(uname -r | sed 's/5\.//')
    elif [ "$(uname -s)" = "OS400" ] || [ -f /QSYS.LIB ]; then
        # IBM i (AS/400)
        OS_NAME="IBM i"
        # Try to get IBM i version - this might need adjustment based on actual system
        if command -v system >/dev/null 2>&1; then
            OS_VERSION=$(system "DSPPTF" 2>/dev/null | head -1 | cut -d' ' -f2 2>/dev/null || echo "unknown")
        else
            OS_VERSION="unknown"
        fi
    elif echo "$PATH" | grep -i windows >/dev/null 2>&1 || [ -n "$WINDIR" ]; then
        # Basic Windows detection (limited in POSIX shell)
        OS_NAME="Windows"
        OS_VERSION="unknown"
    else
        # Unknown Unix-like system
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
}

# Function to count CPUs
detect_cpu_count() {
    if [ "$(uname -s)" = "AIX" ]; then
        # AIX - count online processors
        if command -v lsdev >/dev/null 2>&1; then
            CPU_COUNT=$(lsdev -Cc processor | grep -c Available || echo "1")
        elif command -v bindprocessor >/dev/null 2>&1; then
            CPU_COUNT=$(bindprocessor -q | wc -w)
        else
            CPU_COUNT="1"
        fi
    elif [ "$(uname -s)" = "SunOS" ]; then
        # Solaris
        if command -v psrinfo >/dev/null 2>&1; then
            CPU_COUNT=$(psrinfo | wc -l)
        else
            CPU_COUNT=$(kstat -m cpu_info | grep "module:" | wc -l)
        fi
    elif [ -f /proc/cpuinfo ]; then
        # Linux systems
        CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo)
    elif command -v sysctl >/dev/null 2>&1; then
        # BSD-like systems
        CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    else
        # Fallback
        CPU_COUNT="1"
    fi
}

# Function to detect virtualization
detect_virtualization() {
    IS_VIRTUALIZED="no"
    VIRT_TYPE="none"
    
    if [ "$(uname -s)" = "AIX" ]; then
        # AIX - Check for PowerVM/LPAR
        if command -v uname >/dev/null 2>&1; then
            if uname -L >/dev/null 2>&1; then
                LPAR_ID=$(uname -L 2>/dev/null)
                if [ -n "$LPAR_ID" ] && [ "$LPAR_ID" != "-1" ]; then
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="PowerVM - LPAR"
                fi
            fi
        fi
        
        # Check for micro-partitioning
        if command -v lparstat >/dev/null 2>&1; then
            if lparstat -i 2>/dev/null | grep -q "Shared"; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="PowerVM - Micro-Partitioning"
            fi
        fi
        
    elif [ "$(uname -s)" = "SunOS" ]; then
        # Solaris - Check for zones/containers
        if command -v zonename >/dev/null 2>&1; then
            ZONE_NAME=$(zonename 2>/dev/null)
            if [ -n "$ZONE_NAME" ] && [ "$ZONE_NAME" != "global" ]; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="Containers/Zones"
            fi
        fi
        
        # Check for Oracle VM Server for SPARC (LDoms)
        if command -v virtinfo >/dev/null 2>&1; then
            VIRT_INFO=$(virtinfo 2>/dev/null)
            if echo "$VIRT_INFO" | grep -q "LDoms"; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="Oracle VM Server for SPARC"
            fi
        fi
        
    elif [ -f /proc/cpuinfo ]; then
        # Linux systems - multiple detection methods
        
        # Check for hypervisor flag in CPU
        if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
            IS_VIRTUALIZED="yes"
        fi
        
        # Check DMI information
        if command -v dmidecode >/dev/null 2>&1; then
            DMI_SYS_VENDOR=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_PRODUCT=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]')
            DMI_SYS_VERSION=$(dmidecode -s system-version 2>/dev/null | tr '[:upper:]' '[:lower:]')
            
            case "$DMI_SYS_VENDOR" in
                *vmware*)
                    IS_VIRTUALIZED="yes"
                    if echo "$DMI_SYS_PRODUCT" | grep -q "esxi"; then
                        VIRT_TYPE="VMware vSphere (ESXi)"
                    else
                        VIRT_TYPE="VMware"
                    fi
                    ;;
                *microsoft*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="MS Hyper-V"
                    ;;
                *citrix*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="CITRIX Hypervisor"
                    ;;
                *qemu*|*kvm*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="KVM hypervisor"
                    ;;
                *oracle*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="Oracle VM"
                    ;;
                *nutanix*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="Nutanix AHV (PRISM)"
                    ;;
                *ibm*)
                    IS_VIRTUALIZED="yes"
                    VIRT_TYPE="IBM Virtualization"
                    ;;
            esac
        fi
        
        # Check /sys/hypervisor
        if [ -d /sys/hypervisor ]; then
            IS_VIRTUALIZED="yes"
            if [ -f /sys/hypervisor/type ]; then
                HYPERVISOR_TYPE=$(cat /sys/hypervisor/type 2>/dev/null)
                case "$HYPERVISOR_TYPE" in
                    "xen") VIRT_TYPE="Xen" ;;
                    *) VIRT_TYPE="$HYPERVISOR_TYPE" ;;
                esac
            fi
        fi
        
        # Check for specific virtualization indicators
        if [ -f /proc/xen/capabilities ] 2>/dev/null; then
            IS_VIRTUALIZED="yes"
            VIRT_TYPE="Xen"
        fi
        
        # Check systemd-detect-virt if available
        if command -v systemd-detect-virt >/dev/null 2>&1; then
            DETECTED_VIRT=$(systemd-detect-virt 2>/dev/null)
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
            fi
        fi
        
        # Check for z/VM (IBM mainframe)
        if [ -f /proc/sysinfo ]; then
            if grep -q "z/VM" /proc/sysinfo 2>/dev/null; then
                IS_VIRTUALIZED="yes"
                VIRT_TYPE="z/VM"
            fi
        fi
        
        # Check dmesg for virtualization clues (if accessible)
        if command -v dmesg >/dev/null 2>&1; then
            DMESG_OUTPUT=$(dmesg 2>/dev/null | head -50)
            if echo "$DMESG_OUTPUT" | grep -qi "hypervisor\|vmware\|kvm\|xen"; then
                IS_VIRTUALIZED="yes"
                if [ "$VIRT_TYPE" = "none" ]; then
                    if echo "$DMESG_OUTPUT" | grep -qi "vmware"; then
                        VIRT_TYPE="VMware"
                    elif echo "$DMESG_OUTPUT" | grep -qi "kvm"; then
                        VIRT_TYPE="KVM hypervisor"
                    elif echo "$DMESG_OUTPUT" | grep -qi "xen"; then
                        VIRT_TYPE="Xen"
                    else
                        VIRT_TYPE="Unknown hypervisor"
                    fi
                fi
            fi
        fi
    fi
    
    # If we detected virtualization but don't have a specific type
    if [ "$IS_VIRTUALIZED" = "yes" ] && [ "$VIRT_TYPE" = "none" ]; then
        VIRT_TYPE="Unknown"
    fi
}

# Function to output results
output_results() {
    echo "=== System Information Detection ==="
    echo "Operating System: $OS_NAME"
    echo "OS Version: $OS_VERSION"
    echo "CPU Count: $CPU_COUNT"
    echo "Virtualized: $IS_VIRTUALIZED"
    echo "Virtualization Type: $VIRT_TYPE"
    echo "===================================="
}

# Function to output JSON format
output_json() {
    cat << EOF
{
  "os_name": "$OS_NAME",
  "os_version": "$OS_VERSION",
  "cpu_count": "$CPU_COUNT",
  "is_virtualized": "$IS_VIRTUALIZED",
  "virtualization_type": "$VIRT_TYPE",
  "detection_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -j, --json    Output results in JSON format"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "This script detects system information including:"
    echo "  - Operating system name and version"
    echo "  - Number of CPUs"
    echo "  - Virtualization status and type"
    echo ""
    echo "Supported platforms:"
    echo "  - AIX (PowerVM detection)"
    echo "  - Linux distributions (RHEL, SUSE, Ubuntu, CentOS, Debian, Oracle Linux)"
    echo "  - Solaris (Zones/Containers, Oracle VM for SPARC)"
    echo "  - Basic IBM i and Windows detection"
}

# Main execution
main() {
    # Parse command line arguments
    JSON_OUTPUT=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Detect system information
    detect_os
    detect_cpu_count
    detect_virtualization
    
    # Output results
    if [ "$JSON_OUTPUT" = true ]; then
        output_json
    else
        output_results
    fi
}

# Execute main function with all arguments
main "$@"
