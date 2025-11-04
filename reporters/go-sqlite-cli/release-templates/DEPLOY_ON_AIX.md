# AIX Deployment Instructions

**Package:** iwldr for AIX 7.2  
**Build Date:** {{BUILD_DATE}}  
**Build System:** AIX 7.2 with gcc-go

## What is in This Package

```
bin/iwldr        - Main executable (wrapper script)
bin/iwldr.bin    - Actual binary
lib/libgo.a                   - Go runtime library (bundled)
lib/libgcc_s.a                - GCC support library (bundled)
DEPLOY_ON_AIX.md              - This file
DETECTED_DEPENDENCIES.txt     - Full dependency list from build system
```

## Quick Start

### 1. Extract Package

```bash
gunzip -c iwldr-aix72.tar.gz | tar -xf -
cd iwldr-aix72
```

### 2. Test Binary

```bash
./bin/iwldr --help
```

If this works, you are ready to deploy!

### 3. Install to Production Location

```bash
# Create installation directory
mkdir -p /opt/license-monitor

# Copy everything
cp -r bin lib /opt/license-monitor/

# Create data directories
mkdir -p /opt/license-monitor/data
mkdir -p /opt/license-monitor/input
mkdir -p /opt/license-monitor/processed
mkdir -p /opt/license-monitor/discards

# Test installation
/opt/license-monitor/bin/iwldr --help
```

### 4. Initialize Database

```bash
/opt/license-monitor/bin/iwldr init \
  --db-path /opt/license-monitor/data/license-monitor.db
```

### 5. Import Reference Data (First Time Only)

You will need the reference CSV files from the repository:
- license-terms.csv
- product-codes.csv

```bash
/opt/license-monitor/bin/iwldr import \
  --db-path /opt/license-monitor/data/license-monitor.db \
  --load-reference \
  --reference-dir /path/to/reference-csvs \
  --file /path/to/first-measurement.csv
```

## Runtime Dependencies

This package is **self-contained** and includes all necessary libraries.

### What is Bundled

✅ **Go runtime** (libgo.a) - Included  
✅ **GCC support** (libgcc_s.a) - Included  
✅ **SQLite3** - Statically compiled into binary

### What is Required (Standard AIX)

✅ **libc.a** - Standard C library (always present)  
✅ **libpthread.a** - POSIX threads (always present)  
✅ **libcrypt.a** - Crypt library (always present)

No additional packages need to be installed!

## Troubleshooting

### Binary Won't Execute

**Error:**
```
Could not load program iwldr:
Dependent module libgo.so.22 could not be loaded.
```

**Solution:** Make sure you are running the wrapper script, not the .bin file directly:
```bash
./bin/iwldr        # Correct - uses wrapper
./bin/iwldr.bin    # Wrong - missing LIBPATH
```

### Permission Denied

```bash
chmod +x /opt/license-monitor/bin/iwldr
chmod +x /opt/license-monitor/bin/iwldr.bin
```

### Check What Libraries Are Needed

```bash
ldd ./bin/iwldr.bin
```

See DETECTED_DEPENDENCIES.txt for the full list from the build system.

## Directory Structure

Recommended production layout:

```
/opt/license-monitor/
├── bin/
│   ├── iwldr        # Main executable (wrapper)
│   └── iwldr.bin    # Actual binary
├── lib/                      # Bundled libraries
│   ├── libgo.a              # Go runtime
│   └── libgcc_s.a           # GCC support
├── data/                         # Database and working files
│   └── license-monitor.db        # Main database
├── input/                        # Incoming inspector CSV files
├── processed/                    # Successfully imported files
└── discards/                     # Failed/invalid files
```

## Usage Examples

### Import Inspector Data

```bash
/opt/license-monitor/bin/iwldr import \
  --db-path /opt/license-monitor/data/license-monitor.db \
  --dir /opt/license-monitor/input
```

### Generate Reports

```bash
# Daily summary
/opt/license-monitor/bin/iwldr report daily-summary \
  --db-path /opt/license-monitor/data/license-monitor.db

# Export to CSV
/opt/license-monitor/bin/iwldr report daily-summary \
  --db-path /opt/license-monitor/data/license-monitor.db \
  --format csv \
  --output /tmp/report.csv
```

## Scheduled Execution (Cron)

Add to crontab for automated operation:

```bash
# Edit crontab
crontab -e

# Import new data daily at 2 AM
0 2 * * * /opt/license-monitor/bin/iwldr import --db-path /opt/license-monitor/data/license-monitor.db --input-dir /opt/license-monitor/input >> /opt/license-monitor/logs/import.log 2>&1
```

## System Requirements

- **Operating System:** AIX 7.2 or higher
- **Architecture:** PowerPC 64-bit
- **Disk Space:** 100 MB minimum (more for database growth)
- **Memory:** 256 MB minimum
- **Network:** Not required (file-based operation)

## Support

For issues or questions:

1. Check DETECTED_DEPENDENCIES.txt for dependency information
2. Run with --help for usage information
3. Check logs in /opt/license-monitor/logs/
4. Verify file permissions and disk space

## Version Information

- **Binary:** iwldr  
- **Build Date:** {{BUILD_DATE}}  
- **Build Platform:** AIX 7.2 / PowerPC 64-bit
- **Compiler:** gcc-go
- **Package Type:** Self-contained with bundled dependencies