#!/bin/bash
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

# shellcheck disable=SC3043,SC2129

set -e

## Assurance of global public constants
export IWDLI_DEBUG="${IWDLI_DEBUG:-OFF}"
export IWDLI_HOME="${IWDLI_HOME:-/tmp/iwdli-home}"
export IWDLI_AUDIT_DIR="${IWDLI_AUDIT_DIR:-${IWDLI_HOME}/audit}"
export IWDLI_DATA_DIR="${IWDLI_DATA_DIR:-${IWDLI_HOME}/data}"
export IWDLI_DETECTION_CONFIG_DIR="${IWDLI_DETECTION_CONFIG_DIR:-${IWDLI_HOME}/detection-config}"
export IWDLI_LANDSCAPE_CONFIG_DIR="${IWDLI_LANDSCAPE_CONFIG_DIR:-${IWDLI_HOME}/landscape-config}"

## Session global private constants
iwdli_session_timestamp=$(date -u '+%Y-%m-%d_%H%M%S')
iwdli_session_audit_dir=${IWDLI_SESSION_AUDIT_DIR:-${IWDLI_AUDIT_DIR}/${iwdli_session_timestamp}}
# note that user MAY provide a IWDLI_SESSION_AUDIT_DIR folder if they want to keep the audit files in an upfront defined folder
iwdli_session_log="${iwdli_session_audit_dir}/iwdli_session.log"
# shellcheck disable=SC3028
hostname_short=$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")
iwdli_output_file="${IWDLI_DATA_DIR}/iwdli_output_${hostname_short}_${iwdli_session_timestamp}.csv"
script_dir="$(cd "$(dirname "$0")" && pwd)"
os_name=$(uname -s)

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
CONSIDERED_CPUS=""
HOST_PHYSICAL_CPUS=""
PARTITION_CPUS=""

# Global variables for physical host identification
PHYSICAL_HOST_ID=""
HOST_ID_METHOD=""
HOST_ID_CONFIDENCE=""

# Global variables for disk-based product detection results
DETECT_INSTALL_STATUS=""
DETECT_INSTALL_COUNT=""
DETECT_INSTALL_PATHS=""

# Function to write a parameter-value pair to CSV
write_csv() {
  echo "$1,$2" >> "$iwdli_output_file"
  logD "CSV: $1=$2"
}

# Function to log important information
log() {
  __log_time=$(date -u '+%H:%M:%S')
  echo "${__log_time}[INF] $1" >&2
  if [ -n "$iwdli_session_log" ]; then
    echo "${__log_time}[INF] $1" >> "$iwdli_session_log"
  fi
  unset __log_time
}

# Function to log important information
logE() {
  __log_time=$(date -u '+%H:%M:%S')
  echo "${__log_time}[ERR] $1" >&2
  if [ -n "$iwdli_session_log" ]; then
      echo "${__log_time}[ERR] $1" >> "$iwdli_session_log"
  fi
  unset __log_time
}

# Function to log debug information if IWDLI_DEBUG=ON
logD() {
  if [ "$IWDLI_DEBUG" = "ON" ]; then
    __log_time=$(date -u '+%H:%M:%S')
    echo "${__log_time}[DBG] $1" >&2
    if [ -n "$iwdli_session_log" ]; then
      echo "${__log_time}[DBG] $1" >> "$iwdli_session_log"
    fi
    unset __log_time
  fi
}

# Function to run command with debug output capture
run_debug_cmd() {
  if [ "$IWDLI_DEBUG" = "ON" ] && [ -n "$iwdli_session_audit_dir" ]; then
    logD "Running command: $1"
    __out_file="${iwdli_session_audit_dir}/$2.out"
    __err_file="${iwdli_session_audit_dir}/$2.err"
    
    # Run command and capture both stdout and stderr
    eval "$1" >"$__out_file" 2>"$__err_file"
    __exit_code=$?
    
    if [ ${__exit_code} -ne 0 ]; then
      logE "Command '$1' completed with exit code: $__exit_code"
    fi

    logD "Command '$1' completed with exit code: $__exit_code"
    logD "Output saved to: $__out_file"
    logD "Errors saved to: $__err_file"
    
    unset __out_file __err_file __exit_code
    return 1
  else
    # Regular execution without debug capture
    eval "$1"
  fi
}

# Function to log all session information (computed constants and environment)
log_session_info() {
  logD "=== Session Information ==="
  logD "Environment variables:"
  logD "  IWDLI_DEBUG=${IWDLI_DEBUG}"
  logD "  IWDLI_HOME=${IWDLI_HOME}"
  logD "  IWDLI_AUDIT_DIR=${IWDLI_AUDIT_DIR}"
  logD "  IWDLI_DATA_DIR=${IWDLI_DATA_DIR}"
  logD "  IWDLI_DETECTION_CONFIG_DIR=${IWDLI_DETECTION_CONFIG_DIR}"
  logD "  IWDLI_LANDSCAPE_CONFIG_DIR=${IWDLI_LANDSCAPE_CONFIG_DIR}"
  logD "Session constants:"
  logD "  iwdli_session_timestamp=${iwdli_session_timestamp}"
  logD "  iwdli_session_audit_dir=${iwdli_session_audit_dir}"
  logD "  iwdli_session_log=${iwdli_session_log}"
  logD "  hostname_short=${hostname_short}"
  logD "  iwdli_output_file=${iwdli_output_file}"
  logD "Script variables:"
  logD "  script_dir=${script_dir}"
  logD "  os_name=${os_name}"
  logD "==========================="
}

# Function to detect operating system
detect_os() {
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
            CPU_COUNT=$(psrinfo | wc -l | sed 's/^[[:space:]]*//')
            logD "psrinfo method: CPU_COUNT=${CPU_COUNT}"
        else
            CPU_COUNT=$(kstat -m cpu_info | grep "module:" | wc -l | sed 's/^[[:space:]]*//')
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

# Function to detect host/physical CPU information for licensing calculations
detect_host_physical_cpus() {
    local host_cpus=""
    local partition_cpus=""
    
    logD "Detecting host/physical CPU information"
    
    case "$OS_NAME" in
        "AIX")
            # For AIX, try to get physical host CPU information
            if command -v lparstat >/dev/null 2>&1; then
                # Get physical CPU information from lparstat
                local lparstat_output
                lparstat_output=$(lparstat -i 2>/dev/null || echo "")
                logD "lparstat output for CPU detection: ${lparstat_output}"
                
                # Try to extract physical CPU count from various lparstat fields
                # Look for "Physical CPU in system" or similar
                if echo "$lparstat_output" | grep -i "Physical CPU" >/dev/null 2>&1; then
                    host_cpus=$(echo "$lparstat_output" | grep -i "Physical CPU" | sed 's/.*: *\([0-9]*\).*/\1/' | head -1)
                    logD "Found physical CPUs from lparstat: ${host_cpus}"
                fi
                
                # Try to get partition-specific CPU allocation
                if echo "$lparstat_output" | grep -i "Maximum Physical CPU" >/dev/null 2>&1; then
                    partition_cpus=$(echo "$lparstat_output" | grep -i "Maximum Physical CPU" | sed 's/.*: *\([0-9]*\).*/\1/' | head -1)
                    logD "Found partition max CPUs from lparstat: ${partition_cpus}"
                elif echo "$lparstat_output" | grep -i "Online Physical CPU" >/dev/null 2>&1; then
                    partition_cpus=$(echo "$lparstat_output" | grep -i "Online Physical CPU" | sed 's/.*: *\([0-9]*\).*/\1/' | head -1)
                    logD "Found partition online CPUs from lparstat: ${partition_cpus}"
                fi
            fi
            
            # Try alternative AIX methods if lparstat doesn't provide info
            if [ -z "$host_cpus" ] && command -v prtconf >/dev/null 2>&1; then
                # Try to get CPU info from prtconf
                local prtconf_output
                prtconf_output=$(prtconf 2>/dev/null | grep -i "Number Of Processors" || echo "")
                if [ -n "$prtconf_output" ]; then
                    host_cpus=$(echo "$prtconf_output" | sed 's/.*: *\([0-9]*\).*/\1/')
                    logD "Found host CPUs from prtconf: ${host_cpus}"
                fi
            fi
            ;;
            
        "SunOS")
            # For Solaris, use various methods to detect host CPUs
            if command -v psrinfo >/dev/null 2>&1; then
                # Physical CPU count
                host_cpus=$(psrinfo -p 2>/dev/null | sed 's/^[[:space:]]*//' || echo "")
                if [ -n "$host_cpus" ]; then
                    logD "Found physical CPUs from psrinfo -p: ${host_cpus}"
                fi
                
                # If in a zone, try to detect host physical CPUs
                if [ "$IS_VIRTUALIZED" = "yes" ] && command -v zonename >/dev/null 2>&1; then
                    local zone_name=$(zonename 2>/dev/null)
                    if [ "$zone_name" != "global" ]; then
                        # In a non-global zone - virtual CPU count is what we have, 
                        # but we need host physical for comparison
                        # This is challenging from within a zone, so we'll use what we can detect
                        logD "In non-global zone (${zone_name}), host CPU detection limited"
                    fi
                fi
            fi
            ;;
            
        "Red Hat Enterprise Linux"|"SUSE Linux Enterprise Server"|*Linux*)
            # For Linux, try to get physical CPU information
            if [ -f /proc/cpuinfo ]; then
                # Get physical CPU count (not logical cores)
                local physical_cpus=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l 2>/dev/null || echo "")
                if [ -n "$physical_cpus" ] && [ "$physical_cpus" -gt 0 ]; then
                    host_cpus="$physical_cpus"
                    logD "Found physical CPUs from /proc/cpuinfo: ${host_cpus}"
                fi
                
                # For virtualized environments, try to detect host information
                if [ "$IS_VIRTUALIZED" = "yes" ]; then
                    # This is challenging from within a VM, but we can try some approaches
                    case "$VIRT_TYPE" in
                        "KVM"|"VMware"|"Xen"|"Hyper-V")
                            # For these, the virtual CPU count is typically what we should use
                            # Host CPU detection from within VM is not reliable
                            logD "In virtualized environment (${VIRT_TYPE}), host CPU detection limited from within VM"
                            ;;
                    esac
                fi
            fi
            ;;
    esac
    
    # Store the results
    logD "Host CPUs detected: ${host_cpus:-unknown}"
    logD "Partition CPUs detected: ${partition_cpus:-unknown}"
    
    # Return values via global variables for use in considered CPU calculation
    HOST_PHYSICAL_CPUS="$host_cpus"
    PARTITION_CPUS="$partition_cpus"
    
    # Write to CSV
    write_csv "HOST_PHYSICAL_CPUS" "${HOST_PHYSICAL_CPUS:-unknown}"
    write_csv "PARTITION_CPUS" "${PARTITION_CPUS:-unknown}"
}

# Function to detect physical host identifier for VM aggregation
detect_physical_host_id() {
    PHYSICAL_HOST_ID="unknown"
    HOST_ID_METHOD="none"
    HOST_ID_CONFIDENCE="low"
    
    log "Starting physical host identification"
    logD "Virtualization status: IS_VIRTUALIZED=${IS_VIRTUALIZED}, VIRT_TYPE=${VIRT_TYPE}"
    
    # Only attempt host identification if we're in a virtualized environment
    if [ "$IS_VIRTUALIZED" = "yes" ]; then
        case "$OS_NAME" in
            "AIX")
                detect_aix_physical_host_id
                ;;
            "SunOS")
                detect_solaris_physical_host_id
                ;;
            "Red Hat Enterprise Linux"|"SUSE Linux Enterprise Server"|*Linux*)
                detect_linux_physical_host_id
                ;;
            *)
                logD "Physical host detection not implemented for OS: ${OS_NAME}"
                ;;
        esac
    else
        # Not virtualized - this IS the physical host
        PHYSICAL_HOST_ID=$(hostname 2>/dev/null || echo "localhost")
        HOST_ID_METHOD="physical-hostname"
        HOST_ID_CONFIDENCE="high"
        logD "Physical machine detected, using hostname as host ID: ${PHYSICAL_HOST_ID}"
    fi
    
    log "Physical host identification complete: ID=${PHYSICAL_HOST_ID}, Method=${HOST_ID_METHOD}, Confidence=${HOST_ID_CONFIDENCE}"
    
    # Write to CSV
    write_csv "PHYSICAL_HOST_ID" "$PHYSICAL_HOST_ID"
    write_csv "HOST_ID_METHOD" "$HOST_ID_METHOD"
    write_csv "HOST_ID_CONFIDENCE" "$HOST_ID_CONFIDENCE"
}

# AIX PowerVM physical host identification
detect_aix_physical_host_id() {
    logD "Attempting AIX physical host identification"
    
    # Method 1: Use uname -m to get the machine hardware name (physical host identifier)
    if command -v uname >/dev/null 2>&1; then
        machine_name=$(uname -m 2>/dev/null)
        if [ -n "$machine_name" ] && [ "$machine_name" != "unknown" ]; then
            PHYSICAL_HOST_ID="aix-machine-${machine_name}"
            HOST_ID_METHOD="uname-machine"
            HOST_ID_CONFIDENCE="high"
            logD "AIX machine name found: ${machine_name}"
            return
        fi
    fi
    
    # Method 2: Try to get hardware serial number from lscfg as fallback
    if command -v lscfg >/dev/null 2>&1; then
        serial=$(lscfg -pv | grep "System Serial Number" | head -1 | sed 's/.*System Serial Number[[:space:]]*\.*[[:space:]]*\(.*\)/\1/' 2>/dev/null)
        if [ -n "$serial" ] && [ "$serial" != "Not Available" ]; then
            PHYSICAL_HOST_ID="aix-serial-${serial}"
            HOST_ID_METHOD="hardware-serial"
            HOST_ID_CONFIDENCE="high"
            logD "AIX hardware serial found: ${serial}"
            return
        fi
    fi
    
    # Method 3: Try to get system identifier from lparstat (kept for compatibility)
    if command -v lparstat >/dev/null 2>&1; then
        lparstat_output=$(lparstat -i 2>/dev/null)
        
        # Look for Node Name (which is typically the partition name, not physical host)
        node_name=$(echo "$lparstat_output" | grep "Node Name" | sed 's/.*Node Name[[:space:]]*:[[:space:]]*\(.*\)/\1/' 2>/dev/null)
        if [ -n "$node_name" ]; then
            PHYSICAL_HOST_ID="aix-node-${node_name}"
            HOST_ID_METHOD="powervm-node-name"
            HOST_ID_CONFIDENCE="low"
            logD "AIX node name found (partition name): ${node_name}"
            return
        fi
    fi
    
    # Method 4: Fallback to VM hostname with low confidence
    vm_hostname=$(hostname 2>/dev/null || echo "unknown")
    PHYSICAL_HOST_ID="aix-vm-${vm_hostname}"
    HOST_ID_METHOD="fallback-vm-hostname"
    HOST_ID_CONFIDENCE="low"
    logD "AIX fallback to VM hostname: ${vm_hostname}"
}

# Solaris physical host identification
detect_solaris_physical_host_id() {
    logD "Attempting Solaris physical host identification"
    
    # Method 1: Try to get hardware serial from prtconf in global zone
    if command -v prtconf >/dev/null 2>&1; then
        # This might work if we can access global zone info
        serial=$(prtconf -v 2>/dev/null | grep "banner-name" | head -1 | sed "s/.*banner-name: '\(.*\)'/\1/" 2>/dev/null)
        if [ -n "$serial" ]; then
            PHYSICAL_HOST_ID="solaris-banner-${serial}"
            HOST_ID_METHOD="hardware-banner"
            HOST_ID_CONFIDENCE="medium"
            logD "Solaris hardware banner found: ${serial}"
            return
        fi
    fi
    
    # Method 2: Try to get zone's underlying physical host info
    if command -v zonename >/dev/null 2>&1 && command -v zoneadm >/dev/null 2>&1; then
        zone_name=$(zonename 2>/dev/null)
        # In a non-global zone, we have limited access to physical host info
        # This is a challenging scenario - we might need to rely on configuration
        if [ "$zone_name" != "global" ]; then
            logD "In non-global zone (${zone_name}), limited physical host detection"
        fi
    fi
    
    # Method 3: Try hostid as a system identifier
    if command -v hostid >/dev/null 2>&1; then
        host_id=$(hostid 2>/dev/null)
        if [ -n "$host_id" ]; then
            PHYSICAL_HOST_ID="solaris-hostid-${host_id}"
            HOST_ID_METHOD="solaris-hostid"
            HOST_ID_CONFIDENCE="medium"
            logD "Solaris hostid found: ${host_id}"
            return
        fi
    fi
    
    # Method 4: Fallback to VM hostname
    vm_hostname=$(hostname 2>/dev/null || echo "unknown")
    PHYSICAL_HOST_ID="solaris-vm-${vm_hostname}"
    HOST_ID_METHOD="fallback-vm-hostname"
    HOST_ID_CONFIDENCE="low"
    logD "Solaris fallback to VM hostname: ${vm_hostname}"
}

# Linux physical host identification
detect_linux_physical_host_id() {
    logD "Attempting Linux physical host identification for VIRT_TYPE: ${VIRT_TYPE}"
    
    case "$VIRT_TYPE" in
        *VMware*)
            detect_vmware_host_id
            ;;
        *KVM*|*QEMU*)
            detect_kvm_host_id
            ;;
        *Hyper-V*|*Microsoft*)
            detect_hyperv_host_id
            ;;
        *Xen*)
            detect_xen_host_id
            ;;
        *Oracle*)
            detect_oracle_vm_host_id
            ;;
        *)
            detect_generic_linux_host_id
            ;;
    esac
}

# VMware host identification
detect_vmware_host_id() {
    logD "Attempting VMware host identification"
    
    # Method 1: VMware tools vmware-toolbox-cmd
    if command -v vmware-toolbox-cmd >/dev/null 2>&1; then
        host_name=$(vmware-toolbox-cmd stat hosttime 2>/dev/null | head -1)
        if [ -n "$host_name" ]; then
            PHYSICAL_HOST_ID="vmware-host-${host_name}"
            HOST_ID_METHOD="vmware-tools"
            HOST_ID_CONFIDENCE="high"
            logD "VMware host via tools: ${host_name}"
            return
        fi
    fi
    
    # Method 2: Try DMI UUID as host identifier
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="vmware-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "VMware UUID found: ${uuid}"
            return
        fi
    fi
    
    # Method 3: Fallback
    generic_linux_fallback "vmware"
}

# KVM host identification
detect_kvm_host_id() {
    logD "Attempting KVM host identification"
    
    # Method 1: Try to get KVM host info from /sys
    if [ -f /sys/devices/virtual/dmi/id/product_uuid ]; then
        uuid=$(cat /sys/devices/virtual/dmi/id/product_uuid 2>/dev/null)
        if [ -n "$uuid" ]; then
            PHYSICAL_HOST_ID="kvm-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "KVM UUID found: ${uuid}"
            return
        fi
    fi
    
    # Method 2: Try DMI UUID
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="kvm-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "KVM DMI UUID found: ${uuid}"
            return
        fi
    fi
    
    # Method 3: Fallback
    generic_linux_fallback "kvm"
}

# Hyper-V host identification
detect_hyperv_host_id() {
    logD "Attempting Hyper-V host identification"
    
    # Method 1: Try to get Hyper-V specific UUID
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="hyperv-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "Hyper-V UUID found: ${uuid}"
            return
        fi
    fi
    
    # Method 2: Fallback
    generic_linux_fallback "hyperv"
}

# Xen host identification
detect_xen_host_id() {
    logD "Attempting Xen host identification"
    
    # Method 1: Try Xen-specific methods
    if [ -f /proc/xen/capabilities ]; then
        caps=$(cat /proc/xen/capabilities 2>/dev/null)
        logD "Xen capabilities: ${caps}"
    fi
    
    # Method 2: Try DMI UUID
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="xen-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "Xen UUID found: ${uuid}"
            return
        fi
    fi
    
    # Method 3: Fallback
    generic_linux_fallback "xen"
}

# Oracle VM host identification
detect_oracle_vm_host_id() {
    logD "Attempting Oracle VM host identification"
    
    # Similar to other hypervisors, try UUID
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="oraclevm-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="medium"
            logD "Oracle VM UUID found: ${uuid}"
            return
        fi
    fi
    
    # Fallback
    generic_linux_fallback "oraclevm"
}

# Generic Linux host identification
detect_generic_linux_host_id() {
    logD "Attempting generic Linux host identification"
    
    # Try DMI UUID as last resort
    if command -v dmidecode >/dev/null 2>&1; then
        uuid=$(dmidecode -s system-uuid 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -n "$uuid" ] && [ "$uuid" != "not present" ]; then
            PHYSICAL_HOST_ID="linux-uuid-${uuid}"
            HOST_ID_METHOD="hypervisor-uuid"
            HOST_ID_CONFIDENCE="low"
            logD "Generic Linux UUID found: ${uuid}"
            return
        fi
    fi
    
    # Fallback
    generic_linux_fallback "generic"
}

# Common fallback method for Linux systems
generic_linux_fallback() {
    virt_prefix="$1"
    vm_hostname=$(hostname 2>/dev/null || echo "unknown")
    PHYSICAL_HOST_ID="${virt_prefix}-vm-${vm_hostname}"
    HOST_ID_METHOD="fallback-vm-hostname"
    HOST_ID_CONFIDENCE="low"
    logD "Linux fallback (${virt_prefix}) to VM hostname: ${vm_hostname}"
}

# Function to detect virtualization
detect_virtualization() {
    IS_VIRTUALIZED="no"
    VIRT_TYPE="none"
    
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
            if echo "$DMESG_OUTPUT" | grep -i "hypervisor\|vmware\|kvm\|xen" >/dev/null 2>&1; then
                IS_VIRTUALIZED="yes"
                logD "Virtualization indicators found in dmesg"
                if [ "$VIRT_TYPE" = "none" ]; then
                    if echo "$DMESG_OUTPUT" | grep -i "vmware" >/dev/null 2>&1; then
                        VIRT_TYPE="VMware"
                        logD "VMware detected in dmesg"
                    elif echo "$DMESG_OUTPUT" | grep -i "kvm" >/dev/null 2>&1; then
                        VIRT_TYPE="KVM hypervisor"
                        logD "KVM detected in dmesg"
                    elif echo "$DMESG_OUTPUT" | grep -i "xen" >/dev/null 2>&1; then
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
                if echo "$MODEL_NAME" | grep -i "xeon" >/dev/null 2>&1; then
                    PROCESSOR_BRAND="Xeon - All Processor Numbers"
                elif echo "$MODEL_NAME" | grep -i "pentium" >/dev/null 2>&1; then
                    PROCESSOR_BRAND="Pentium - All Processor Numbers"
                elif echo "$MODEL_NAME" | grep -i "core" >/dev/null 2>&1; then
                    PROCESSOR_BRAND="Core - All Processor Numbers"
                else
                    # Default to Xeon for unknown Intel processors in server context
                    PROCESSOR_BRAND="Xeon - All Processor Numbers"
                fi
                logD "Intel processor detected: ${PROCESSOR_BRAND}"
                ;;
            "AuthenticAMD")
                PROCESSOR_VENDOR="AMD"
                if echo "$MODEL_NAME" | grep -i "epyc" >/dev/null 2>&1; then
                    PROCESSOR_BRAND="Epyc"
                elif echo "$MODEL_NAME" | grep -i "opteron.*6[0-9][0-9][0-9]" >/dev/null 2>&1; then
                    PROCESSOR_BRAND="Opteron 6000 series"
                elif echo "$MODEL_NAME" | grep -i "opteron" >/dev/null 2>&1; then
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
                        if grep -i "power10" /proc/cpuinfo >/dev/null 2>&1; then
                            PROCESSOR_BRAND="POWER10"
                        elif grep -i "power9" /proc/cpuinfo >/dev/null 2>&1; then
                            PROCESSOR_BRAND="POWER9"
                        elif grep -i "power8" /proc/cpuinfo >/dev/null 2>&1; then
                            PROCESSOR_BRAND="POWER8"
                        elif grep -i "power7" /proc/cpuinfo >/dev/null 2>&1; then
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
    # Load processors CSV from detection-config (contract-level configuration)
    processors_csv="$IWDLI_DETECTION_CONFIG_DIR/ibm-eligible-processors.csv"
    
    logD "Checking processor eligibility using: ${processors_csv}"
    
    if [ ! -f "$processors_csv" ]; then
        log "ERROR: Required processor eligibility file not found: ${processors_csv}"
        log "ERROR: This file must exist in detection-config directory"
        exit 1
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
    # Load virt/OS CSV from landscape-config (required)
    virt_os_csv="$IWDLI_DETECTION_CONFIG_DIR/ibm-eligible-virt-and-os.csv"
    
    logD "Checking OS and virtualization eligibility using: ${virt_os_csv}"
    
    if [ ! -f "$virt_os_csv" ]; then
        log "ERROR: Required OS/Virtualization eligibility file not found: ${virt_os_csv}"
        log "ERROR: This file must exist in detection-config directory"
        exit 1
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
    
    # Normalize virtualization type for comparison with CSV
    local normalized_virt_type=""
    case "$VIRT_TYPE" in
        "PowerVM - Micro-Partitioning")
            # Map micro-partitioning to DLPAR for CSV matching
            normalized_virt_type="PowerVM - DLPAR"
            ;;
        "PowerVM - LPAR")
            # Regular LPARs also map to DLPAR
            normalized_virt_type="PowerVM - DLPAR"
            ;;
        "PowerVM"|"LPAR")
            # Generic PowerVM detection maps to DLPAR
            normalized_virt_type="PowerVM - DLPAR"
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
                                # Normalize versions to major.minor format for comparison
                                # Convert X.Y.Z to XY format, handling missing minor parts
                                local detected_major=$(echo "$OS_VERSION" | cut -d'.' -f1)
                                local detected_minor=$(echo "$OS_VERSION" | cut -d'.' -f2 | sed 's/^0*//' | head -c1)
                                local required_major=$(echo "$required_version" | cut -d'.' -f1)
                                local required_minor=$(echo "$required_version" | cut -d'.' -f2 | sed 's/^0*//' | head -c1)
                                
                                # Handle empty minor versions
                                [ -z "$detected_minor" ] && detected_minor="0"
                                [ -z "$required_minor" ] && required_minor="0"
                                
                                # Create comparable version numbers (e.g., 6.1 -> 61, 7.1 -> 71)
                                local detected_num="${detected_major}${detected_minor}"
                                local required_num="${required_major}${required_minor}"
                                
                                logD "Version comparison: detected=${detected_major}.${detected_minor} (${detected_num}) vs required=${required_major}.${required_minor} (${required_num})"
                                
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

# Function to calculate considered CPUs for IBM licensing
calculate_considered_cpus() {
    logD "Calculating considered CPUs for IBM licensing"
    
    # Start with the detected virtual/logical CPU count
    local virtual_cpus="$CPU_COUNT"
    local considered_cpus="$virtual_cpus"
    
    logD "Starting calculation - Virtual CPUs: ${virtual_cpus}"
    logD "OS_ELIGIBLE: ${OS_ELIGIBLE}, VIRT_ELIGIBLE: ${VIRT_ELIGIBLE}"
    logD "IS_VIRTUALIZED: ${IS_VIRTUALIZED}, VIRT_TYPE: ${VIRT_TYPE}"
    logD "Host Physical CPUs: ${HOST_PHYSICAL_CPUS:-unknown}"
    logD "Partition CPUs: ${PARTITION_CPUS:-unknown}"
    
    if [ "$IS_VIRTUALIZED" = "yes" ]; then
        # We are in a virtualized environment
        logD "Processing virtualized environment"
        
        # Check if both OS and virtualization technology are eligible
        if [ "$OS_ELIGIBLE" = "true" ] && [ "$VIRT_ELIGIBLE" = "true" ]; then
            # Both OS and virt tech are eligible - use virtual CPU count
            considered_cpus="$virtual_cpus"
            logD "Both OS and virtualization eligible - using virtual CPUs: ${considered_cpus}"
        else
            # Either OS or virtualization technology not eligible
            # Use physical host/partition cores instead
            logD "OS or virtualization not eligible - need to use physical cores"
            
            # Prefer partition CPUs if available, otherwise use host physical CPUs
            if [ -n "$PARTITION_CPUS" ] && [ "$PARTITION_CPUS" -gt 0 ] 2>/dev/null; then
                considered_cpus="$PARTITION_CPUS"
                logD "Using partition CPUs: ${considered_cpus}"
            elif [ -n "$HOST_PHYSICAL_CPUS" ] && [ "$HOST_PHYSICAL_CPUS" -gt 0 ] 2>/dev/null; then
                considered_cpus="$HOST_PHYSICAL_CPUS"
                logD "Using host physical CPUs: ${considered_cpus}"
            else
                # Fallback to virtual CPUs if we can't determine physical
                considered_cpus="$virtual_cpus"
                logD "Cannot determine physical CPUs - falling back to virtual CPUs: ${considered_cpus}"
            fi
        fi
        
        # Check for over-provisioning scenario
        # If physical cores < virtual cores, use physical cores
        local physical_to_compare=""
        if [ -n "$PARTITION_CPUS" ] && [ "$PARTITION_CPUS" -gt 0 ] 2>/dev/null; then
            physical_to_compare="$PARTITION_CPUS"
        elif [ -n "$HOST_PHYSICAL_CPUS" ] && [ "$HOST_PHYSICAL_CPUS" -gt 0 ] 2>/dev/null; then
            physical_to_compare="$HOST_PHYSICAL_CPUS"
        fi
        
        if [ -n "$physical_to_compare" ]; then
            if [ "$physical_to_compare" -lt "$virtual_cpus" ] 2>/dev/null; then
                logD "Over-provisioning detected: physical (${physical_to_compare}) < virtual (${virtual_cpus})"
                considered_cpus="$physical_to_compare"
                logD "Using physical CPUs due to over-provisioning: ${considered_cpus}"
            fi
        fi
        
    else
        # Physical system - use the detected CPU count
        considered_cpus="$virtual_cpus"
        logD "Physical system - using detected CPUs: ${considered_cpus}"
    fi
    
    # Ensure we have a valid number
    if ! echo "$considered_cpus" | grep -E '^[0-9]+$' >/dev/null 2>&1; then
        logD "Invalid considered_cpus value (${considered_cpus}), using virtual_cpus (${virtual_cpus})"
        considered_cpus="$virtual_cpus"
    fi
    
    CONSIDERED_CPUS="$considered_cpus"
    log "Considered CPUs for IBM licensing: ${CONSIDERED_CPUS}"
    write_csv "CONSIDERED_CPUS" "$CONSIDERED_CPUS"
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
    # shellcheck disable=SC2016
    echo '  - iwdli_output_${HOSTNAME}_${TIMESTAMP}.csv: Main detection results in CSV format'
    echo "  - session.log: Detailed logging of the detection session"
    echo "  - [command].out/.err: Command outputs when IWDLI_DEBUG=ON"
    echo ""
    echo "Output parameters include:"
    echo "  - detection_timestamp: ISO 8601 timestamp"
    echo "  - OS_NAME, OS_VERSION: Operating system information"
    echo "  - CPU_COUNT: Number of available CPUs (virtual/logical)"
    echo "  - HOST_PHYSICAL_CPUS: Number of physical CPUs in host (when detectable)"
    echo "  - PARTITION_CPUS: Number of CPUs allocated to partition (when applicable)"
    echo "  - CONSIDERED_CPUS: CPU count for IBM licensing calculations"
    echo "  - IS_VIRTUALIZED: yes/no if running on virtualized platform"
    echo "  - VIRT_TYPE: Type of virtualization technology"
    echo "  - PROCESSOR_VENDOR, PROCESSOR_BRAND: Processor information"
    echo "  - PROCESSOR_ELIGIBLE: true/false if processor is IBM-eligible"
    echo "  - OS_ELIGIBLE: true/false if OS is IBM-eligible"
    echo "  - VIRT_ELIGIBLE: true/false if virtualization is IBM-eligible"
    echo ""
    echo "Environment variables:"
    echo "  IWDLI_DEBUG=ON                    Enable debug logging and command output capture"
    echo "  IWDLI_HOME=path                   Set inspector home directory"
    echo "                                    (default: /tmp/iwdli-home)"
    echo "  IWDLI_AUDIT_DIR=path              Set audit/log output directory"
    echo "                                    (default: \$IWDLI_HOME/audit)"
    echo "  IWDLI_DATA_DIR=path               Set CSV data output directory"
    echo "                                    (default: \$IWDLI_HOME/data)"
    echo "  IWDLI_DETECTION_CONFIG_DIR=path   Set detection configuration directory"
    echo "                                    (default: \$IWDLI_HOME/detection-config)"
    echo "  IWDLI_LANDSCAPE_CONFIG_DIR=path   Set landscape configuration directory"
    echo "                                    (default: \$IWDLI_HOME/landscape-config)"
    echo ""
    echo "Supported platforms:"
    echo "  - AIX (PowerVM detection)"
    echo "  - Linux distributions (RHEL, SUSE, Ubuntu, CentOS, Debian, Oracle Linux)"
    echo "  - Solaris (Zones/Containers, Oracle VM for SPARC)"
    echo "  - Basic IBM i and Windows detection"
    echo ""
    echo "Configuration files:"
    echo "  Detection config (IWDLI_DETECTION_CONFIG_DIR - contract-level, fixed):"
    echo "    - ibm-eligible-processors.csv"
    echo "    - ibm-eligible-virt-and-os.csv"
    echo "    - product-codes.csv"
    echo "    - product-detection-config.csv"
    echo "  Landscape config (IWDLI_LANDSCAPE_CONFIG_DIR - per environment):"
    echo "    - <hostname>/node-config.conf (host-specific settings)"
    echo "    - Fallback: node-config.conf in script directory"
}

# Function to load node configuration based on hostname
load_node_config() {
  NODE_TYPE="PROD"  # Default to PROD
    
  # Look for hostname-specific directory in landscape-config
  host_config_dir=""
  if [ -d "$IWDLI_LANDSCAPE_CONFIG_DIR" ]; then
    # Try exact hostname match first
    if [ -d "$IWDLI_LANDSCAPE_CONFIG_DIR/$hostname_short" ]; then
      host_config_dir="$IWDLI_LANDSCAPE_CONFIG_DIR/$hostname_short"
      logD "Found exact hostname match: $host_config_dir"
    else
      # Try to find a directory that contains the hostname as substring
      for dir in "$IWDLI_LANDSCAPE_CONFIG_DIR"/*; do
        if [ -d "$dir" ]; then
          dir_name=$(basename "$dir")
          # Skip CSV files and hidden directories
          case "$dir_name" in
            *.csv|.*) continue ;;
          esac
          # Check if hostname appears in directory name
          case "$dir_name" in
            *"$hostname_short"*) 
              host_config_dir="$dir"
              logD "Found hostname substring match: $host_config_dir"
              break ;;
          esac
        fi
      done
    fi
  fi
    
  # Load configuration from host-specific directory or fall back to common location
  node_config_file=""
  if [ -n "$host_config_dir" ] && [ -f "$host_config_dir/node-config.conf" ]; then
    node_config_file="$host_config_dir/node-config.conf"
    logD "Using host-specific configuration: $node_config_file"
  elif [ -f "$script_dir/node-config.conf" ]; then
    # Fall back to script directory for backward compatibility
    node_config_file="$script_dir/node-config.conf"
    logD "Using fallback configuration: $node_config_file"
  fi
    
  if [ -n "$node_config_file" ] && [ -f "$node_config_file" ]; then
    logD "Loading node configuration from: $node_config_file"
    # Source the config file to get NODE_TYPE
    # shellcheck source=/dev/null
    . "$node_config_file" 2>/dev/null || {
      logD "Warning: Could not source node configuration file"
    }
    logD "Node type set to: $NODE_TYPE"
  else
    logD "Node configuration file not found, using default: $NODE_TYPE"
  fi
}

# Function to get IBM product code for a given product mnemonic
# Usage: get_product_code <product_mnemo_id>
# Returns: IBM product code or "UNKNOWN" if not found
get_product_code() {
    local product_mnemo="$1"
    local product_codes_file="$IWDLI_DETECTION_CONFIG_DIR/product-codes.csv"
    
    if [ ! -f "$product_codes_file" ]; then
        log "WARNING: product-codes.csv not found at: $product_codes_file"
        echo "UNKNOWN"
        return
    fi
    
    # Read CSV and find matching product mnemonic
    while IFS=',' read -r mnemo_id prod_code prod_name mode terms_id notes || [ -n "$mnemo_id" ]; do
        # Skip empty lines and header
        [ -z "$mnemo_id" ] && continue
        echo "$mnemo_id" | grep "product-mnemo-id" >/dev/null 2>&1 && continue
        
        # Remove any leading/trailing whitespace
        mnemo_id=$(echo "$mnemo_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        prod_code=$(echo "$prod_code" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ "$mnemo_id" = "$product_mnemo" ]; then
            echo "$prod_code"
            return
        fi
    done < "$product_codes_file"
    
    # Not found
    echo "UNKNOWN"
}

# Function to detect product installations on disk
# This function searches the filesystem for product installation directories
# and filters for substantive installations (> 1KB size)
# POSIX-compliant version - works on Solaris, AIX, and Linux
#
# Arguments:
#   $1 - product_id: Product mnemonic identifier (e.g., "IS_ONP_PRD")
#   $2 - folder_name: Directory name to search for (e.g., "IntegrationServer")
#   $3 - exclude_pattern: Optional grep pattern to exclude false positives
#
# Returns via global variables:
#   DETECT_INSTALL_STATUS: "installed" or "not-installed"
#   DETECT_INSTALL_COUNT: Number of installations found (integer)
#   DETECT_INSTALL_PATHS: Semicolon-separated list of installation paths
#
detect_product_installations() {
    local product_id="$1"
    local folder_name="$2"
    local exclude_pattern="$3"
    
    # Default search paths - /app is primary installation location for webMethods
    # IWDLI_SEARCH_PATHS should be space-separated directory paths
    local search_paths="${IWDLI_SEARCH_PATHS:-/app /opt /usr/local /home}"
    
    logD "=== Starting disk-based detection ==="
    logD "Product ID: ${product_id}"
    logD "Folder name: ${folder_name}"
    logD "Exclude pattern: ${exclude_pattern:-<none>}"
    logD "Search paths: ${search_paths}"
    
    # Initialize result variables
    local found_paths=""
    local found_count=0
    
    # Determine platform-specific du command options and size threshold
    local du_opts="-s"
    local size_threshold=2
    
    case "$OS_NAME" in
        "AIX")
            # AIX du uses 512-byte blocks, threshold > 2 blocks (~1KB)
            du_opts="-s"
            size_threshold=2
            ;;
        "Solaris")
            # Solaris du uses 512-byte blocks
            du_opts="-s"
            size_threshold=2
            ;;
        *)
            # Linux - try -sk for kilobyte output
            if du -sk /tmp >/dev/null 2>&1; then
                du_opts="-sk"
                size_threshold=1
            else
                # Fallback for systems without -k option
                du_opts="-s"
                size_threshold=2
            fi
            ;;
    esac
    
    logD "Using du options: ${du_opts}, size threshold: ${size_threshold}"
    
    # Use temporary file to collect results (avoids subshell variable issues)
    local temp_results="${iwdli_session_audit_dir}/disk_detect_${product_id}_$$.tmp"
    
    # Process each search path
    for search_path in $search_paths; do
        # Check if search path exists and is accessible
        if [ ! -d "$search_path" ]; then
            logD "Skipping non-existent search path: ${search_path}"
            continue
        fi
        
        if [ ! -r "$search_path" ]; then
            logD "Skipping non-readable search path: ${search_path}"
            continue
        fi
        
        logD "Searching in: ${search_path}"
        
        # Calculate base depth (count slashes in search path)
        # Using tr to count slashes - POSIX-compliant and works on all platforms
        base_slashes=$(echo "$search_path" | tr -cd '/' | wc -c)
        
        # Find all matching directories - POSIX compliant (no -maxdepth)
        # Filter results manually by depth
        find "$search_path" -type d -name "$folder_name" 2>/dev/null | while IFS= read -r found_dir; do
            # Skip empty lines
            [ -z "$found_dir" ] && continue
            
            # Calculate directory depth using slash count
            dir_slashes=$(echo "$found_dir" | tr -cd '/' | wc -c)
            rel_depth=$((dir_slashes - base_slashes))
            
            # Skip if too deep (depth > 5)
            if [ $rel_depth -gt 5 ]; then
                logD "Skipping (too deep - level $rel_depth): ${found_dir}"
                continue
            fi
            
            # Apply exclusion pattern if specified
            if [ -n "$exclude_pattern" ]; then
                # Use grep without -q for Solaris 5.8 compatibility (redirect output to /dev/null)
                if echo "$found_dir" | grep "$exclude_pattern" >/dev/null 2>&1; then
                    logD "Skipping (excluded): ${found_dir}"
                    continue
                fi
            fi
            
            # Check directory size - must be substantive (> threshold)
            # shellcheck disable=SC2086
            dir_size=$(du $du_opts "$found_dir" 2>/dev/null | awk '{print $1}')
            
            # Validate size is numeric and above threshold
            if [ -z "$dir_size" ]; then
                logD "Skipping (cannot determine size): ${found_dir}"
                continue
            fi
            
            # Compare size using shell arithmetic
            if [ "$dir_size" -le "$size_threshold" ]; then
                logD "Skipping (too small - ${dir_size} blocks): ${found_dir}"
                continue
            fi
            
            # Valid installation found - save to temp file
            echo "$found_dir" >> "$temp_results"
            logD "  Found installation: ${found_dir} (depth: ${rel_depth}, size: ${dir_size})"
        done
    done
    
    # Process collected results from temp file
    if [ -f "$temp_results" ]; then
        # Count installations (wc -l may have leading spaces, trim them)
        found_count=$(wc -l < "$temp_results" 2>/dev/null | sed 's/^[[:space:]]*//')
        
        # Build semicolon-separated path list
        # Use simple shell loop compatible with old Bourne shell
        # Note: IFS= as inline assignment with read doesn't work on Solaris 5.8 /bin/sh
        found_paths=""
        OLD_IFS="$IFS"
        IFS=""
        while read -r install_path; do
            if [ -z "$found_paths" ]; then
                found_paths="$install_path"
            else
                found_paths="${found_paths};${install_path}"
            fi
        done < "$temp_results"
        IFS="$OLD_IFS"
        
        # Clean up temp file
        rm -f "$temp_results"
    else
        found_count=0
        found_paths=""
    fi
    
    # Set global return variables based on results
    if [ $found_count -gt 0 ]; then
        DETECT_INSTALL_STATUS="installed"
        DETECT_INSTALL_COUNT=$found_count
        DETECT_INSTALL_PATHS="$found_paths"
        log "Disk detection complete for ${product_id}: ${found_count} installation(s) found"
    else
        DETECT_INSTALL_STATUS="not-installed"
        DETECT_INSTALL_COUNT=0
        DETECT_INSTALL_PATHS=""
        logD "Disk detection complete for ${product_id}: No installations found"
    fi
    
    logD "=== Disk-based detection complete ==="
    logD "Status: ${DETECT_INSTALL_STATUS}"
    logD "Count: ${DETECT_INSTALL_COUNT}"
    logD "Paths: ${DETECT_INSTALL_PATHS}"
}

# Function to detect running webMethods products
detect_products() { 
    # Load product detection config from detection-config (contract-level configuration)
    product_config_file="$IWDLI_DETECTION_CONFIG_DIR/product-detection-config.csv"
    
    logD "Starting product detection using: ${product_config_file}"
    
    if [ ! -f "$product_config_file" ]; then
        log "ERROR: Required product detection config file not found: $product_config_file"
        log "ERROR: This file must exist in detection-config directory"
        exit 1
    fi
    
    # Load node configuration to determine PROD/NON_PROD
    load_node_config
    
    # If debug mode is on, capture the full process listing once before filtering
    if [ "${IWDLI_DEBUG}" = "ON" ]; then

        logD "Capturing \"ps -ef\" ---"
        ps -ef > "${iwdli_session_audit_dir}/c_ps-ef.out" 2>"${iwdli_session_audit_dir}/c_ps-ef.err"

        logD "Capturing \"ps auxww\" ---"
        ps -ef > "${iwdli_session_audit_dir}/c_ps_auxww.out" 2>"${iwdli_session_audit_dir}/c_ps_auxww.err"

        if [ -x /bin/ucb/ps ]; then
            logD "Capturing \"ps auxww\" ---"
            /usr/ucb/ps -ef > "${iwdli_session_audit_dir}/c_ucb_ps_auxww.out" 2>"${iwdli_session_audit_dir}/c_ucb_ps_auxww.err"
        fi

        case "${OS_NAME}" in
            "AIX"|"Solaris")
                ps -ef > "${iwdli_session_audit_dir}/ps-ef.out" 2>"${iwdli_session_audit_dir}/ps-ef.err"
                logD "Full process list captured: ${iwdli_session_audit_dir}/ps-ef.out"
                ;;
            *)
                # Linux and others
                ps aux > "${iwdli_session_audit_dir}/ps-aux.out" 2>"${iwdli_session_audit_dir}/ps-aux.err"
                logD "Full process list captured: ${iwdli_session_audit_dir}/ps-aux.out"
                ;;
        esac
    fi
    
    # Skip header line and process each product detection rule
    while IFS=',' read -r grep_pattern prod_id nonprod_id process_type disk_search_enabled disk_folder_name disk_exclude_pattern notes || [ -n "$grep_pattern" ]; do
        # Skip empty lines and comments
        [ -z "$grep_pattern" ] && continue
        echo "$grep_pattern" | grep '^#' >/dev/null 2>&1 && continue
        [ "$grep_pattern" = "process-grep-pattern" ] && continue  # Skip header
        
        logD "Processing product detection rule:"
        logD "  Pattern: $grep_pattern"
        logD "  Process type: $process_type"
        logD "  Disk search: ${disk_search_enabled:-<not set>}"
        logD "  Disk folder: ${disk_folder_name:-<not set>}"
        logD "  Exclude pattern: ${disk_exclude_pattern:-<not set>}"
        
        # Determine which product ID to use based on node type
        if [ "$NODE_TYPE" = "NON_PROD" ]; then
            product_id="$nonprod_id"
        else
            product_id="$prod_id"
        fi
        
        logD "Using product ID: ${product_id} (Node type: ${NODE_TYPE})"
        
        # ========================================
        # PART 1: Process-based detection
        # ========================================
        
        # Initialize detection status flags
        process_running="false"
        installation_detected="false"
        __running_process_count=0
        process_cmdlines=""
        
        # Check if any processes match the pattern and count them
        case "$OS_NAME" in
            "AIX"|"Solaris")
                # Count matching processes
                __running_process_count=$(ps -ef | grep -v grep | grep -c "$grep_pattern" 2>/dev/null || echo "0")
                __running_process_count=${__running_process_count:-0}
                if [ "$__running_process_count" -gt 0 ]; then
                    process_running="true"
                    # Capture command lines for running processes (limit to avoid CSV issues)
                    process_cmdlines=$(ps -ef | grep -v grep | grep "$grep_pattern" | head -3 | awk '{for(i=8;i<=NF;i++) printf "%s ", $i; print ""}' | tr '\n' ';' | sed 's/;$//' 2>/dev/null || echo "")
                fi
                ;;
            *)
                # Linux and others
                __running_process_count=$(ps aux | grep -v grep | grep -c "$grep_pattern" 2>/dev/null || echo "0")
                __running_process_count=${__running_process_count:-0}
                if [ "$__running_process_count" -gt 0 ]; then
                    process_running="true"
                    # Capture command lines for running processes (limit to avoid CSV issues)
                    process_cmdlines=$(ps aux | grep -v grep | grep "$grep_pattern" | head -3 | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | tr '\n' ';' | sed 's/;$//' 2>/dev/null || echo "")
                fi
                ;;
        esac
        
        logD "Process detection for ${product_id}: running=${process_running}, count=${__running_process_count}"
        
        # ========================================
        # PART 2: Disk-based installation detection
        # ========================================
        
        # Check if disk-based detection is enabled for this product
        if [ "$disk_search_enabled" = "yes" ] && [ -n "$disk_folder_name" ]; then
            logD "Disk-based detection enabled for ${product_id}"
            
            # Call disk detection function
            detect_product_installations "$product_id" "$disk_folder_name" "$disk_exclude_pattern"
            
            # Check if installations were found
            if [ "$DETECT_INSTALL_STATUS" = "installed" ]; then
                installation_detected="true"
            fi
            
            logD "Disk detection for ${product_id}: installed=${installation_detected}, count=${DETECT_INSTALL_COUNT}"
        else
            logD "Disk-based detection NOT enabled for ${product_id}"
            # Set default values when disk detection is disabled
            DETECT_INSTALL_STATUS="not-installed"
            DETECT_INSTALL_COUNT="0"
            DETECT_INSTALL_PATHS=""
        fi
        
        # ========================================
        # PART 3: Determine overall product presence and write results
        # ========================================
        
        # Product is "present" if it's either running OR installed (or both)
        if [ "$process_running" = "true" ] || [ "$installation_detected" = "true" ]; then
            product_present="true"
        else
            product_present="false"
        fi
        
        logD "Overall product status for ${product_id}: present=${product_present} (running=${process_running}, installed=${installation_detected})"
        
        # Write product section ONLY if product is detected (present)
        if [ "$product_present" = "true" ]; then
            # Get IBM product code mapping - ALWAYS populate for detected products
            ibm_product_code=$(get_product_code "$product_id")
            logD "Product $product_id maps to IBM code: $ibm_product_code"
            
            write_csv "$product_id" "present"
            write_csv "${product_id}_IBM_PRODUCT_CODE" "$ibm_product_code"
        else
            # Product is truly absent (neither running nor installed)
            # NO CSV section created - omit entirely to avoid bloat
            logD "Product $product_id is absent - no CSV section will be created"
        fi
        
        # Write detailed status keys ONLY for detected (present) products
        if [ "$product_present" = "true" ]; then
            # Write running status keys
            if [ "$process_running" = "true" ]; then
                write_csv "${product_id}_RUNNING_STATUS" "running"
                write_csv "${product_id}_RUNNING_COUNT" "$__running_process_count"
                write_csv "${product_id}_RUNNING_COMMANDLINES" "$process_cmdlines"
                
                # If debug mode is on, capture the specific grep results for this product
                if [ "$IWDLI_DEBUG" = "ON" ]; then
                    debug_file="${iwdli_session_audit_dir}/processes_${product_id}.out"
                    case "$OS_NAME" in
                        "AIX"|"Solaris")
                            ps -ef | grep -v grep | grep "$grep_pattern" > "$debug_file" 2>/dev/null
                            ;;
                        *)
                            ps aux | grep -v grep | grep "$grep_pattern" > "$debug_file" 2>/dev/null
                            ;;
                    esac
                    logD "Process details saved to: $debug_file"
                fi
            else
                write_csv "${product_id}_RUNNING_STATUS" "not-running"
                write_csv "${product_id}_RUNNING_COUNT" "0"
                write_csv "${product_id}_RUNNING_COMMANDLINES" ""
            fi
            
            # Write installation status keys
            write_csv "${product_id}_INSTALL_STATUS" "$DETECT_INSTALL_STATUS"
            write_csv "${product_id}_INSTALL_COUNT" "$DETECT_INSTALL_COUNT"
            
            # Handle paths - escape or sanitize if needed
            if [ -n "$DETECT_INSTALL_PATHS" ]; then
                write_csv "${product_id}_INSTALL_PATHS" "$DETECT_INSTALL_PATHS"
            else
                write_csv "${product_id}_INSTALL_PATHS" ""
            fi
        fi
        # Note: No CSV keys written for absent products (neither running nor installed)
        
        # Clean up private loop variables
        unset __running_process_count
        
    done < "$product_config_file"
    
    logD "Product detection completed (process and disk)"
}

# Main execution
main() {
  # Handle command line arguments
  if [ -n "$1" ]; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
      show_usage
      exit 0
    fi
  fi
  
  # Log all session information in debug mode
  log_session_info

  # Create audit directory for this session (debug output, logs)
  mkdir -p "${iwdli_session_audit_dir}" || {
      echo "Error: Cannot create session audit directory: ${iwdli_session_audit_dir}" >&2
      exit 1
  }
  
  # Create data directory if it doesn't exist
  mkdir -p "${IWDLI_DATA_DIR}" || {
      echo "Error: Cannot create data directory: ${IWDLI_DATA_DIR}" >&2
      exit 2
  }
        
  # Initialize session log
  echo "=== System Detection Session Started ===" >> "$iwdli_session_log"
  echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$iwdli_session_log"
  echo "Session Audit Directory: $iwdli_session_audit_dir" >> "$iwdli_session_log"
  echo "Script Directory: $script_dir" >> "$iwdli_session_log"
  echo "Data Directory: ${IWDLI_DATA_DIR}" >> "$iwdli_session_log"
  echo "Detection Config Directory: ${IWDLI_DETECTION_CONFIG_DIR}" >> "$iwdli_session_log"
  echo "Landscape Config Directory: ${IWDLI_LANDSCAPE_CONFIG_DIR}" >> "$iwdli_session_log"
  echo "Debug Mode: ${IWDLI_DEBUG:-OFF}" >> "$iwdli_session_log"
  echo "IWDLI Home (env): ${IWDLI_HOME:-<not set>}" >> "$iwdli_session_log"
  echo "=========================================" >> "$iwdli_session_log"
  echo "" >> "$iwdli_session_log"
    
  log "Starting system detection"
  log "Session audit directory: ${iwdli_session_audit_dir}"
  log "Output file: ${iwdli_output_file}"
  log "Session log: ${iwdli_session_log}"
    
  # Create CSV file with header
  echo "Parameter,Value" > "$iwdli_output_file"
  write_csv "detection_timestamp" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  write_csv "session_audit_directory" "$iwdli_session_audit_dir"
    
  # Detect system information
  detect_os
  detect_cpu_count
  detect_virtualization
  detect_processor
    
  # Detect host/physical CPU information for licensing calculations
  detect_host_physical_cpus
  
  # Detect physical host identifier for VM aggregation
  detect_physical_host_id
  
  # Check eligibility
  check_processor_eligibility
  check_os_virt_eligibility
  
  # Calculate considered CPUs based on eligibility and physical constraints
  calculate_considered_cpus
  
  # Detect running webMethods products
  detect_products
    
  log "Detection complete. Results written to: ${iwdli_output_file}"
  log "Session log available at: ${iwdli_session_log}"
  
  # Final session log entry
  echo "" >> "$iwdli_session_log"
  echo "=== System Detection Session Completed ===" >> "$iwdli_session_log"
  echo "End Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$iwdli_session_log"
  echo "==========================================" >> "$iwdli_session_log"
}

# Execute main function with all arguments
main "$@"
