#!/bin/sh
# Test script to validate enhanced functionality

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
cd common
bash detect_system_info.sh ../test_enhanced_output.csv
echo "Script completed. Exit code: $?"

# Display results
echo "Results:"
cat ../test_enhanced_output.csv

echo "Test completed."