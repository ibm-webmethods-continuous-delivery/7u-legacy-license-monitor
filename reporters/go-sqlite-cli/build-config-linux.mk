# Linux Build Configuration
# 
# This file contains platform-specific build settings for Linux
# 
# Usage:
#   1. Copy or symlink this file as build-config.mk
#      ln -s build-config-linux.mk build-config.mk
#   2. Run make as usual: make build
# 
# Note: build-config.mk should be added to .gitignore to keep
#       platform-specific settings local to each build environment
#

# Compiler: Standard Go compiler with standard ldflags
# The flags include:
#   -s        : Strip symbol table (reduce binary size)
#   -w        : Strip DWARF debug info (reduce binary size)
BUILD_LDFLAGS=-ldflags "-s -w"

# Static builds are supported on Linux
# This enables building fully static binaries for containers
# using: make build-static
STATIC_BUILD_ENABLED=yes

# Platform identifier for documentation and logging
PLATFORM=linux-amd64

# Optional: Override binary name for platform-specific builds
# For alternative binary naming:
# BINARY_NAME=iwldr-linux

# Made with Bob
