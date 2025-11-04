# AIX 7.2 Build Configuration
# 
# This file contains platform-specific build settings for AIX 7.2
# 
# Usage:
#   1. Copy or symlink this file as build-config.mk
#      ln -s build-config-aix72.mk build-config.mk
#   2. Run make as usual: make build
# 
# Note: build-config.mk should be added to .gitignore to keep
#       platform-specific settings local to each build environment
#

# Compiler: gccgo on AIX requires -gccgoflags instead of -ldflags
# The flags include:
#   -lpthread : Link pthread library (required for Go runtime)
#   -s        : Strip symbol table (reduce binary size)
#   -w        : Strip DWARF debug info (reduce binary size)
BUILD_LDFLAGS=-gccgoflags "-lpthread -s -w"

# Static builds are not supported on AIX due to:
#   1. ELF vs XCOFF object format incompatibility
#   2. Assembler directive mismatches
#   3. Limited static library availability
#   4. Not standard practice on AIX systems
STATIC_BUILD_ENABLED=no

# Platform identifier for documentation and logging
PLATFORM=aix-7.2-ppc64

# Optional: Override binary name for platform-specific builds
# BINARY_NAME=seed-go-sqlite-api-aix72
