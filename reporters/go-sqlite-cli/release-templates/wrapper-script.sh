#!/bin/sh
# Wrapper script for seed-go-sqlite-api with bundled libraries
# This ensures the bundled gcc-go runtime libraries are found

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Add bundled lib directory to library path
LIBPATH="$RELEASE_ROOT/lib:$LIBPATH"
export LIBPATH

# Execute the actual binary with all arguments passed through
exec "$SCRIPT_DIR/seed-go-sqlite-api.bin" "$@"
