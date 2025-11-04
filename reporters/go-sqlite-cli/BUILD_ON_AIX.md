# Building on AIX 7.2

This project can be built on AIX 7.2 using gcc-go. Follow these steps:

## Prerequisites

- AIX 7.2 or higher
- gcc-go compiler (usually installed via `yum install gcc-go`)
- GNU make or AIX make
- Git

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/ibm-webmethods-continuous-delivery/7u-legacy-license-monitor.git
cd 7u-legacy-license-monitor/reporters/go-sqlite-cli
```

### 2. Configure for AIX

Copy the AIX-specific configuration:

```bash
cp build-config-aix72.mk build-config.mk
```

Then edit the Makefile and uncomment line 29 (the include directive):

```makefile
# Change this line:
# include build-config.mk

# To this:
include build-config.mk
```

## Building

### Build the Binary

```bash
make build
```

This will create `target/bin/iwldr` with the AIX-specific compiler flags.

### Create Release Package

```bash
make release-for-aix
```

This creates `target/iwldr-aix72.tar.gz` which includes:
- The binary (with wrapper script)
- Required runtime libraries (libgo.a, libgcc_s.a)
- Acceptance tests
- Deployment documentation

## Notes

### Why Not Use Symbolic Links?

The original instructions suggested using `ln -s`, but we use `cp` instead because:
- More explicit - you can see the actual configuration
- Easier to modify if needed
- Works consistently across different AIX versions

### Static Builds Not Supported

Static builds don't work on AIX due to:
- ELF vs XCOFF object format incompatibility
- Assembler directive mismatches
- Limited static library availability

Use the regular `make build` which creates a dynamic binary - this is the standard approach on AIX.

### Makefile Compatibility

The Makefile has been designed to work with both GNU make and AIX make by:
- Avoiding `?=` conditional assignment (GNU make only)
- Avoiding `-include` directive (GNU make only)
- Avoiding `ifeq/endif` conditionals (GNU make only)
- Using standard POSIX make syntax

## Troubleshooting

### "Dependency line needs colon or double colon operator"

Make sure you've updated to the latest version of the Makefile that removes GNU make extensions.

### "gccgoflags: command not found"

The build-config.mk is not being included. Make sure you:
1. Copied build-config-aix72.mk to build-config.mk
2. Uncommented the `include build-config.mk` line in the Makefile

### Binary won't execute - "Cannot load module"

The binary needs the bundled libraries. Use the release package (`make release-for-aix`) which includes a wrapper script that sets LIBPATH correctly.

## Platform-Specific Configuration

The `build-config-aix72.mk` file contains:

```makefile
BUILD_LDFLAGS = -gccgoflags "-lpthread -s -w"
STATIC_BUILD_ENABLED = no
PLATFORM = aix-7.2-ppc64
```

These settings ensure the binary builds correctly with gcc-go on AIX.
