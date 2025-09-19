#!/bin/sh
#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#
# Test script to validate enhanced functionality

# shellcheck disable=SC3043


# Set debug mode
export INSPECT_DEBUG=ON

# Test the enhanced script
echo "Testing enhanced detect_system_info.sh script..."
echo "Current directory: $(pwd)"
echo "Script location: $(ls -la common/detect_system_info.sh)"

# Check if CSV files exist
echo "Checking for CSV files:"
echo "- Processors: $(ls -la common/ibm-eligible-processors.csv)"
echo "- Virt/OS: $(ls -la common/ibm-eligible-virt-and-os.csv)"

# Run the script with debug output
echo "Running enhanced script..."

# Ensure test output directory exists
mkdir -p test-detection-output

cd common || exit 1
# Use bash if available, otherwise fall back to sh
if command -v bash >/dev/null 2>&1; then
    bash detect_system_info.sh ../test-detection-output
else
    sh detect_system_info.sh ../test-detection-output
fi
echo "Script completed. Exit code: $?"

# Display results
echo "Results from latest session:"
cd ..
LATEST_SESSION=$(ls -1t test-detection-output/ | head -1)
if [ -n "$LATEST_SESSION" ]; then
    echo "Session directory: test-detection-output/$LATEST_SESSION"
    echo ""
    echo "=== CSV Results ==="
    cat "test-detection-output/$LATEST_SESSION/inspect_output.csv"
    echo ""
    echo "=== Session Log ==="
    cat "test-detection-output/$LATEST_SESSION/session.log"
    echo ""
    if [ "$INSPECT_DEBUG" = "ON" ]; then
        echo "=== Debug Files Created ==="
        ls -la "test-detection-output/$LATEST_SESSION/"
    fi
else
    echo "No session directory found"
fi

echo "Test completed."