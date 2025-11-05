#!/bin/bash
#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#
# Installation script for IBM webMethods License Inspector
#
# Usage: ./install.sh [install_directory]
#
# If install_directory is not provided, defaults to /tmp/ibm-inspector

set -e

# Default installation directory
DEFAULT_INSTALL_DIR="/tmp/ibm-inspector"
INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}"

echo "=== IBM webMethods License Inspector Installation ==="
echo "Target directory: $INSTALL_DIR"
echo ""

# Create backup if directory exists
if [ -d "$INSTALL_DIR" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_DIR="${INSTALL_DIR%-inspector}-inspector-bak-${TIMESTAMP}"
  echo "Existing installation found. Creating backup: $BACKUP_DIR"
  mv "$INSTALL_DIR" "$BACKUP_DIR"
  echo "Backup created: $BACKUP_DIR"
fi

# Create installation directory
echo "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Get script directory (where install.sh is located)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy files
echo "Installing files..."
cp -r "$SCRIPT_DIR/common" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/config-example" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/test*.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"

# Copy license if exists
if [ -f "$SCRIPT_DIR/LICENSE" ]; then
  cp "$SCRIPT_DIR/LICENSE" "$INSTALL_DIR/"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/common/detect_system_info.sh"
chmod +x "$INSTALL_DIR/test*.sh"

echo ""
echo "Installation completed successfully!"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo "Main script: $INSTALL_DIR/common/detect_system_info.sh"
echo "Meta test script: $INSTALL_DIR/test_meta.sh"
echo "Test script: $INSTALL_DIR/test.sh"
echo ""
echo "Installed Components:"
echo "- Detection scripts: $INSTALL_DIR/common/"
echo "- Configuration templates: $INSTALL_DIR/config-example/"
echo ""
echo "⚠️  CONFIGURATION REQUIRED:"
echo "Before running the inspector, you must set up the 3-tier configuration:"
echo ""
echo "1. Set required environment variables (all mandatory):"
echo "   export IWDLI_IBM_TERMS_DIR=/path/to/ibm-terms"
echo "   export IWDLI_CONTRACT_PRODUCTS_DIR=/path/to/contract-products"
echo "   export IWDLI_LANDSCAPE_CONFIG_DIR=/path/to/landscapes/<domain>/<subdomain>"
echo ""
echo "2. Configuration structure (see config-example/ for templates):"
echo "   - IBM terms: ibm-eligible-processors.csv, ibm-eligible-virt-and-os.csv"
echo "   - Contract products: product-codes.csv"
echo "   - Landscape: product-detection-config.csv, <hostname>/node-config.conf"
echo ""
echo "Example using included templates:"
echo "   export IWDLI_IBM_TERMS_DIR=$INSTALL_DIR/config-example/ibm-terms"
echo "   export IWDLI_CONTRACT_PRODUCTS_DIR=$INSTALL_DIR/config-example/contract-products"
echo "   export IWDLI_LANDSCAPE_CONFIG_DIR=$INSTALL_DIR/config-example/landscapes/EAI/PROD/subdomain"
echo ""
echo "To run the inspector:"
echo "  cd $INSTALL_DIR"
echo "  ./common/detect_system_info.sh"
echo ""
echo "To run tests:"
echo "  cd $INSTALL_DIR"
echo "  ./test.sh"
echo ""
