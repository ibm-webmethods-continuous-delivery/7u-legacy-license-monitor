#!/bin/sh
#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#
# Release script to create deployment package for IBM webMethods License Monitor
#
# Usage: ./release.sh [version]
#
# This script creates a tar.gz file containing all necessary files for
# deployment to target systems.
#
# NOTE: For production deployments, consider separating code and configuration:
#   - Code: common/, test.sh, documentation
#   - Config: landscape-config/ (CSV files, node configs)
# This allows configuration updates without code changes.

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Version from parameter or timestamp
VERSION="${1:-$(date +%Y%m%d_%H%M%S)}"
RELEASE_NAME="ibm-webmethods-license-inspector-${VERSION}"
RELEASE_FILE="${RELEASE_NAME}.tar.gz"

echo "=== IBM webMethods License Inspector Release Builder ==="
echo "Version: $VERSION"
echo "Release file: $RELEASE_FILE"
echo ""

# Check required files exist
echo "Checking required files..."
required_files="common/detect_system_info.sh test.sh test_meta.sh install.sh"
repo_root_files="../../README.md ../../REQUIREMENTS.md"
missing_files=""

for file in $required_files; do
  if [ ! -f "$file" ]; then
    missing_files="$missing_files $file"
  else
    echo "✓ Found: $file"
  fi
done

# Check repository root files
for file in $repo_root_files; do
  if [ ! -f "$file" ]; then
    missing_files="$missing_files $file"
  else
    echo "✓ Found: $file"
  fi
done

# Check required directories
required_dirs="common"
for dir in $required_dirs; do
  if [ ! -d "$dir" ]; then
    missing_files="$missing_files $dir/"
  else
    echo "✓ Found: $dir/"
  fi
done

# Check for config-example (required, at repository root)
if [ ! -d "../../config-example" ]; then
  echo "ERROR: config-example/ directory not found at repository root"
  echo "This directory contains required configuration templates:"
  echo "  - ibm-terms/"
  echo "  - contract-products/"
  echo "  - landscapes/"
  exit 1
else
  echo "✓ Found: ../../config-example/ (required configuration templates)"
fi

if [ -n "$missing_files" ]; then
  echo ""
  echo "ERROR: Missing required files/directories:"
  for file in $missing_files; do
    echo "  - $file"
  done
  exit 1
fi

echo ""
echo "Creating release directory..."
TEMP_DIR="/tmp/${RELEASE_NAME}/iwdli"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Copying files to release directory..."

# Copy main directories
cp -r common "$TEMP_DIR/"

# Copy configuration example from repository root (required)
cp -r ../../config-example "$TEMP_DIR/"

# Copy inspector files
for file in $required_files; do
  cp "$file" "$TEMP_DIR/"
done

# Copy repository root files
for file in $repo_root_files; do
  cp "$file" "$TEMP_DIR/"
done

# Copy license if exists
if [ -f "../../LICENSE" ]; then
  cp ../../LICENSE "$TEMP_DIR/"   
fi

echo "=== IBM webMethods License Inspector ===" > "$TEMP_DIR/RELEASE.TXT" 
echo "Version: $VERSION" >> "$TEMP_DIR/RELEASE.TXT" 

# install.sh is copied from source (not generated)

# Create release tar.gz
echo "Creating release archive: $RELEASE_FILE"
cd /tmp/${RELEASE_NAME}
tar -czf "$SCRIPT_DIR/$RELEASE_FILE" "iwdli"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== Release Created Successfully ==="
echo "File: $RELEASE_FILE"
echo "Size: $(ls -lh "$RELEASE_FILE" | awk '{print $5}')"
echo ""
echo "To deploy on target system:"
echo "1. Copy $RELEASE_FILE to target system"
echo "2. Extract: tar -xzf $RELEASE_FILE"
echo "3. Install: cd $RELEASE_NAME/iwdli && ./install.sh [install_directory]"
echo "4. Set required environment variables (see install.sh output for details)"
echo "5. Run: ./common/detect_system_info.sh"
echo ""
echo "Package contents:"
echo "- common/ (inspector code)"
echo "- config-example/ (configuration templates for all 3 tiers)"
echo "- test.sh, test_meta.sh (validation scripts)"
echo "- install.sh (deployment script)"
echo ""