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
required_files="common/detect_system_info.sh test.sh test_meta.sh"
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
required_dirs="common detection-config landscape-config"
for dir in $required_dirs; do
    if [ ! -d "$dir" ]; then
        missing_files="$missing_files $dir/"
    else
        echo "✓ Found: $dir/"
    fi
done

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
TEMP_DIR="/tmp/${RELEASE_NAME}"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Copying files to release directory..."

# Copy main directories
cp -r common "$TEMP_DIR/"
cp -r detection-config "$TEMP_DIR/"
cp -r landscape-config "$TEMP_DIR/"

# Copy inspector files
cp test*.sh "${TEMP_DIR}/"

# Copy repository root files
cp ../../README.md "$TEMP_DIR/"
cp ../../REQUIREMENTS.md "$TEMP_DIR/"

# Copy license if exists
if [ -f "../../LICENSE" ]; then
    cp ../../LICENSE "$TEMP_DIR/"
fi

# Create install script
echo "Creating install.sh script..."
cat > "$TEMP_DIR/install.sh" << 'EOF'
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
cp -r "$SCRIPT_DIR/landscape-config" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/detection-config" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/test.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"

# Copy license if exists
if [ -f "$SCRIPT_DIR/LICENSE" ]; then
    cp "$SCRIPT_DIR/LICENSE" "$INSTALL_DIR/"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/common/detect_system_info.sh"
chmod +x "$INSTALL_DIR/test.sh"

echo ""
echo "Installation completed successfully!"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo "Main script: $INSTALL_DIR/common/detect_system_info.sh"
echo "Test script: $INSTALL_DIR/test.sh"
echo ""
echo "To run the inspector:"
echo "  cd $INSTALL_DIR"
echo "  ./common/detect_system_info.sh output-directory"
echo ""
echo "To run tests:"
echo "  cd $INSTALL_DIR"
echo "  ./test.sh"
echo ""
echo "Configuration:"
echo "- Node-specific config: $INSTALL_DIR/landscape-config/<hostname>/"
echo "- CSV reference files: $INSTALL_DIR/landscape-config/"
EOF

chmod +x "$TEMP_DIR/install.sh"

# Create release tar.gz
echo "Creating release archive: $RELEASE_FILE"
cd /tmp
tar -czf "$SCRIPT_DIR/$RELEASE_FILE" "$RELEASE_NAME"

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
echo "3. Install: cd $RELEASE_NAME && ./install.sh [install_directory]"
echo ""