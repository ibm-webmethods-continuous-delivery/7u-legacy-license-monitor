# IBM webMethods License Inspector - Default Inspector

## Overview

The default inspector is a POSIX-compliant shell script that monitors system configurations and running webMethods processes to support IBM license compliance tracking. It detects system parameters, validates eligibility against IBM subcapacity licensing rules, and produces structured CSV output for centralized reporting.

**Key Features:**
- **Cross-platform support**: AIX, Linux, Solaris SunOS
- **POSIX-compliant**: Maximum portability across Unix-like systems
- **IBM eligibility validation**: Processor, OS, and virtualization technology checking
- **Physical host identification**: Tracks underlying physical hosts for VM aggregation
- **Product detection**: Automatically identifies running webMethods components
- **Structured output**: Timestamped session directories with CSV results and detailed logs
- **Debug capabilities**: Optional comprehensive tracing for troubleshooting

## Quick Start

### Basic Usage

```bash
cd "${IWDLI_HOME}/common"
./detect_system_info.sh
```

This creates a timestamped directory under `detection-output/` (in current directory) with inspection results.

### With Custom Output Directory

```bash
./detect_system_info.sh /var/data/inspections
```

### Debug Mode

```bash
export IWDLI_DEBUG=ON
./detect_system_info.sh
```

Debug mode creates additional trace files including full process listings and command outputs.

### Using Environment Variables

```bash
# Set inspector home directory
export IWDLI_HOME=~/iwdli

# Set custom detection configuration directory (contract-level, fixed per deployment)
export IWDLI_DETECTION_CONFIG_DIR=/opt/inspector-detection-config

# Set custom landscape configuration directory (per environment)
export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/inspector-landscape-config

# Set custom data output directory
export IWDLI_DATA_DIR=/var/data/inspector-output

# Enable debug mode
export IWDLI_DEBUG=ON

# Run the inspector
./detect_system_info.sh
```

## Environment Variables

The inspector supports the following environment variables for flexible deployment:

| Variable | Default | Description |
|----------|---------|-------------|
| `IWDLI_DEBUG` | `OFF` | Set to `ON` to enable debug logging and capture detailed command outputs |
| `IWDLI_HOME` | `/tmp/iwdli-home` | Inspector home directory (used as base for default paths) |
| `IWDLI_AUDIT_DIR` | `$IWDLI_HOME/audit` | Directory for audit logs and session logs |
| `IWDLI_DATA_DIR` | `$IWDLI_HOME/data` | Directory for CSV output files |
| `IWDLI_DETECTION_CONFIG_DIR` | `$IWDLI_HOME/detection-config` | Contract-level configuration (eligibility CSVs, product codes) |
| `IWDLI_LANDSCAPE_CONFIG_DIR` | `$IWDLI_HOME/landscape-config` | Environment-specific configuration (hostname configs) |

**Variable Naming Convention:**
- All inspector environment variables use the `IWDLI_` prefix
- IWDLI stands for "IBM webMethods Default License Inspector"
- This prevents interference with other applications' environment variables

**Configuration Directory Separation:**
- **Detection Config** (`IWDLI_DETECTION_CONFIG_DIR`): Contract-level configuration that rarely changes
  - IBM eligibility reference files (processors, OS, virtualization)
  - Product code mappings
  - Detection patterns
- **Landscape Config** (`IWDLI_LANDSCAPE_CONFIG_DIR`): Environment-specific configuration
  - Hostname-specific node configurations
  - Varies per deployment landscape

**Benefits of Environment Variables:**
- **Code/Config/Data Separation**: Upgrade inspector code without touching configuration or historical data
- **Centralized Configuration**: Point multiple inspector installations to shared configuration
- **Flexible Data Storage**: Direct output to centralized storage, mounted volumes, or specific partitions
- **Debug Control**: Enable/disable debug mode without modifying scripts

## Installation

### Using the Release Package

1. **Download the release package** to your target system:
   ```bash
   # Transfer ibm-webmethods-license-inspector-<version>.tar.gz to target system
   ```

2. **Extract the package**:
   ```bash
   tar -xzf ibm-webmethods-license-inspector-<version>.tar.gz
   cd ibm-webmethods-license-inspector-<version>
   ```

3. **Run the installation script**:
   ```bash
   ./install.sh
   ```

4. **Configure for your hostname**:
   ```bash
   # Create hostname-specific configuration directory
   mkdir -p landscape-config/$(hostname)
   
   # Copy and customize the node configuration
   cp landscape-config/node-config.conf landscape-config/$(hostname)/
   vi landscape-config/$(hostname)/node-config.conf
   ```

5. **Run the inspector**:
   ```bash
   ./detect_system_info.sh
   ```

### Creating a Release Package

From the `inspectors/default/` directory:

```bash
./release.sh [version]
```

This creates a `ibm-webmethods-license-inspector-<version>.tar.gz` package containing:
- Detection script and common resources
- Sample landscape configurations
- Auto-generated installation script
- Documentation

## Configuration

### Code/Config/Data Separation

The inspector follows a clean separation of concerns:

**Code** (`/opt/inspector/` or installation directory):
- Shell scripts that perform detection
- Minimal, upgradeable without touching configuration or data

**Detection Configuration** (configurable via `IWDLI_DETECTION_CONFIG_DIR`):
- Contract-level configuration files (fixed per customer deployment)
- `ibm-eligible-processors.csv`: IBM's eligible processor list
- `ibm-eligible-virt-and-os.csv`: IBM's eligible OS/virtualization combinations
- `product-codes.csv`: Product code mappings
- `product-detection-config.csv`: Process detection patterns
- Default: `$IWDLI_HOME/detection-config`
- Shared across all environments within same contract

**Landscape Configuration** (configurable via `IWDLI_LANDSCAPE_CONFIG_DIR`):
- Environment-specific configuration files (varies per landscape)
- `<hostname>/node-config.conf`: Host-specific node configuration
- Default: `$IWDLI_HOME/landscape-config`
- Can be set to different location for each environment

**Data** (configurable via `IWDLI_DATA_DIR`):
- Detection output with timestamped CSV files
- Default: `$IWDLI_HOME/data`
- Should be on persistent storage, separate from code

**Audit Logs** (configurable via `IWDLI_AUDIT_DIR`):
- Session logs and debug outputs
- Default: `$IWDLI_HOME/audit`
- Timestamped session directories for each execution

**Example Deployment:**
```bash
# Install code (upgradeable)
/opt/iwl/default-inspector/
  └── common/detect_system_info.sh

# Detection configuration (contract-level, shared across environments)
/opt/iwl/detection-config/
  ├── ibm-eligible-processors.csv
  ├── ibm-eligible-virt-and-os.csv
  ├── product-detection-config.csv
  └── product-codes.csv

# Landscape configuration (environment-specific)
/opt/iwl/landscape-config/
  └── <hostname>/
      └── node-config.conf

# Data storage (persistent, never deleted during upgrades)
/var/data/iwl/default-inspector-output/
  └── iwdli_output_<hostname>_<timestamp>.csv

# Audit logs (session logs and debug outputs)
/var/log/iwl/inspector-audit/
  └── YYYYMMDD_HHMMSS/
      ├── iwdli_session.log
      └── <debug-files>

# Environment configuration
export IWDLI_HOME=/opt/iwl/default-inspector
export IWDLI_DETECTION_CONFIG_DIR=/opt/iwl/detection-config
export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/iwl/landscape-config
export IWDLI_DATA_DIR=/var/data/iwl/default-inspector-output
export IWDLI_AUDIT_DIR=/var/log/iwl/inspector-audit
```

### Directory Structure

```
inspectors/default/
├── common/
│   ├── detect_system_info.sh          # Main detection script
│   └── node-config.conf                # Default fallback configuration
├── detection-config/                   # Contract-level configuration (IWDLI_DETECTION_CONFIG_DIR)
│   ├── ibm-eligible-processors.csv     # Processor eligibility reference
│   ├── ibm-eligible-virt-and-os.csv    # OS/virtualization eligibility reference
│   ├── product-codes.csv               # Product code mappings
│   └── product-detection-config.csv    # Process detection patterns
└── landscape-config/                   # Environment-specific configuration (IWDLI_LANDSCAPE_CONFIG_DIR)
    └── <hostname>/                     # Hostname-specific configurations
        └── node-config.conf            # Host-specific node configuration

# Data directory (separate, via IWDLI_DATA_DIR)
data/
└── iwdli_output_<hostname>_<timestamp>.csv

# Audit directory (separate, via IWDLI_AUDIT_DIR)
audit/
└── YYYYMMDD_HHMMSS/                    # Timestamped session directories
    ├── iwdli_session.log
    └── <debug-files>
```

### Node Configuration (`node-config.conf`)

Each system should have a configuration file in `landscape-config/<hostname>/node-config.conf`:

```properties
# Node type: PROD or NON_PROD
NODE_TYPE=PROD

# Environment identifier
ENVIRONMENT=production

# Inspection detail level
INSPECTION_LEVEL=full
```

**Configuration Lookup Logic:**
1. First attempts: `$IWDLI_LANDSCAPE_CONFIG_DIR/<hostname>/node-config.conf`
2. Falls back to: `$script_dir/node-config.conf` (in common directory)

### Product Detection Configuration (`product-detection-config.csv`)

Located in `$IWDLI_DETECTION_CONFIG_DIR/product-detection-config.csv`

Defines patterns to detect running webMethods processes:

```csv
process-grep-pattern,product-mnemo-id-prod,product-mnemo-id-nonprod,process-type,notes
IntegrationServer,IS_ONP_PRD,IS_ONP_NPR,java,Java process with IntegrationServer in command line
awbrokermon,BRK_ONP_PRD,BRK_ONP_NPR,native,Native process with awbrokermon in command line
```

**Columns:**
- `process-grep-pattern`: Pattern to search in process command lines
- `product-mnemo-id-prod`: Product code for production environments
- `product-mnemo-id-nonprod`: Product code for non-production environments
- `process-type`: Process technology (java, native)
- `notes`: Documentation

### Reference Data Files

Located in `$IWDLI_DETECTION_CONFIG_DIR/`

#### `ibm-eligible-processors.csv`
Defines IBM-eligible processor types for subcapacity licensing:

```csv
processor-vendor,processor-brand,processor-type,os,earliest-version-with-ilmt-support
IBM,POWER8,physical,AIX,7.1
Intel,Xeon,physical,Linux,*
```

#### `ibm-eligible-virt-and-os.csv`
Defines eligible OS and virtualization technology combinations:

```csv
virtualization-vendor,eligible-virtualization-technology,eligible-os,sub-capacity-eligible-form,earliest-version-having-ilmt-support
IBM,PowerVM,AIX,Micro-Partition,6.1
VMware,ESXi,Linux,Guest,5.0
```

## Upgrading the Inspector

The code/config/data separation allows safe upgrades without losing historical data:

### Upgrade Process

1. **Download new release package**:
   ```bash
   wget ibm-webmethods-license-inspector-<new-version>.tar.gz
   ```

2. **Extract to temporary location**:
   ```bash
   tar -xzf ibm-webmethods-license-inspector-<new-version>.tar.gz
   ```

3. **Backup current installation** (optional but recommended):
   ```bash
   cp -r /opt/inspector /opt/inspector.bak.$(date +%Y%m%d)
   ```

4. **Install new code** (replaces scripts only):
   ```bash
   cd ibm-webmethods-license-inspector-<new-version>
   ./install.sh /opt/inspector
   ```

5. **Verify configuration** (configurations are preserved if using separate directories):
   ```bash
   # Check that your detection config still exists
   ls -la /opt/iwl/detection-config/
   
   # Check that your landscape config still exists  
   ls -la /opt/iwl/landscape-config/
   ```

6. **Test the new version**:
   ```bash
   export IWDLI_DETECTION_CONFIG_DIR=/opt/iwl/detection-config
   export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/iwl/landscape-config
   export IWDLI_DATA_DIR=/var/data/inspector-output
   export IWDLI_AUDIT_DIR=/var/log/inspector-audit
   export IWDLI_DEBUG=ON
   /opt/inspector/common/detect_system_info.sh
   ```

7. **Review output**:
   ```bash
   # Check latest session directory in audit logs
   ls -lrt /var/log/inspector-audit/
   cat /var/log/inspector-audit/<latest>/iwdli_session.log
   
   # Check CSV output
   ls -lrt /var/data/inspector-output/
   ```

### What Gets Upgraded

- ✅ **Code**: Shell scripts with bug fixes and new features
- ✅ **Default configurations**: Sample configurations in package
- ❌ **Historical data**: Data directory remains untouched
- ❌ **Detection config**: If using `IWDLI_DETECTION_CONFIG_DIR`, contract-level configs are separate
- ❌ **Landscape config**: If using `IWDLI_LANDSCAPE_CONFIG_DIR`, environment configs are separate

### Best Practices

1. **Use environment variables** for production deployments:
   ```bash
   # In /etc/profile.d/iwdli.sh or similar
   export IWDLI_HOME=/opt/inspector
   export IWDLI_DETECTION_CONFIG_DIR=/opt/iwl/detection-config
   export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/iwl/landscape-config
   export IWDLI_DATA_DIR=/var/data/inspector-output
   export IWDLI_AUDIT_DIR=/var/log/inspector-audit
   ```

2. **Version control your configuration**:
   ```bash
   # Detection config (contract-level)
   cd /opt/iwl/detection-config
   git init
   git add *.csv
   git commit -m "Initial detection configuration"
   
   # Landscape config (environment-specific)
   cd /opt/iwl/landscape-config
   git init
   git add */node-config.conf
   git commit -m "Initial landscape configuration"
   ```

3. **Separate data storage** on dedicated partition or mount:
   ```bash
   # Mount dedicated storage
   mount /dev/vg01/lv_inspector_data /var/data/inspector-output
   ```

4. **Test before production**: Run in debug mode after upgrade to verify functionality

## Output Format

### Output Structure

The inspector creates two types of output in separate locations:

**CSV Data Output** (in `IWDLI_DATA_DIR`):
```
data/
└── iwdli_output_<hostname>_<timestamp>.csv    # Structured system metrics (main output)
```

**Audit/Debug Output** (in `IWDLI_AUDIT_DIR`):
```
audit/
└── YYYYMMDD_HHMMSS/                           # Timestamped session directories
    ├── iwdli_session.log                      # Detailed execution log
    ├── ps-aux.out                             # Full process listing (debug mode)
    ├── ps-ef.out                              # Full process listing (debug mode)
    ├── processes_<product>.out                # Product-specific process details (debug mode)
    └── <command>.out/.err                     # Raw command outputs (debug mode)
```

### CSV Output Schema

The `inspect_output.csv` file contains the following fields:

#### System Identification
- `DETECTION_TIMESTAMP`: Timestamp when detection was performed
- `HOSTNAME`: System hostname
- `NODE_TYPE`: PROD or NON_PROD (from configuration)

#### Operating System
- `OS_NAME`: Operating system name (AIX, Linux, SunOS)
- `OS_VERSION`: Operating system version
- `OS_ELIGIBLE`: true/false - IBM license eligibility

#### CPU and Virtualization
- `CPU_COUNT`: Number of CPUs detected on the system
- `IS_VIRTUALIZED`: yes/no - Running in virtual environment
- `VIRT_TYPE`: Virtualization technology (PowerVM, VMware, KVM, etc.)
- `VIRT_ELIGIBLE`: true/false - IBM license eligibility

#### Processor Information
- `PROCESSOR_VENDOR`: Processor manufacturer (IBM, Intel, AMD)
- `PROCESSOR_BRAND`: Processor model/brand
- `PROCESSOR_ELIGIBLE`: true/false - IBM license eligibility

#### Physical Host Identification
- `PHYSICAL_HOST_ID`: Unique identifier for physical host (for VM aggregation)
- `HOST_ID_METHOD`: Detection method (hypervisor-uuid, hardware-serial, etc.)
- `HOST_ID_CONFIDENCE`: Confidence level (high, medium, low)

#### License Calculation
- `HOST_PHYSICAL_CPUS`: Physical CPUs of virtualizing host
- `PARTITION_CPUS`: CPUs allocated to partition/VM
- `CONSIDERED_CPUS`: Final CPU count for licensing (based on eligibility rules)

#### Product Detection
- `<PRODUCT_CODE>`: present/absent for each configured product (e.g., IS_ONP_PRD, BRK_ONP_PRD)

### Example Output

```csv
DETECTION_TIMESTAMP,2025-10-15 14:32:01
HOSTNAME,webm-prod-server1
NODE_TYPE,PROD
OS_NAME,AIX
OS_VERSION,7.2
CPU_COUNT,8
IS_VIRTUALIZED,yes
VIRT_TYPE,PowerVM
PROCESSOR_VENDOR,IBM
PROCESSOR_BRAND,POWER8
HOST_PHYSICAL_CPUS,32
PARTITION_CPUS,8
PROCESSOR_ELIGIBLE,true
OS_ELIGIBLE,true
VIRT_ELIGIBLE,true
CONSIDERED_CPUS,8
PHYSICAL_HOST_ID,powervm-system-abc123
HOST_ID_METHOD,hardware-serial
HOST_ID_CONFIDENCE,high
IS_ONP_PRD,present
BRK_ONP_PRD,absent
```

## Eligibility Rules and License Calculation

### IBM Subcapacity Licensing

The inspector implements IBM subcapacity licensing rules to calculate the correct CPU count for licensing purposes.

**Eligibility Checks:**

1. **Processor Eligibility**: Matches detected processor vendor/brand against IBM's eligible processor list
2. **OS and Virtualization Eligibility**: Validates OS and virtualization technology combination
3. **CPU Count Calculation**: Determines `CONSIDERED_CPUS` based on eligibility:

**Calculation Logic:**

```
IF virtualization technology is NOT eligible:
    CONSIDERED_CPUS = HOST_PHYSICAL_CPUS
ELSE IF virtualization technology is eligible:
    CONSIDERED_CPUS = min(PARTITION_CPUS, HOST_PHYSICAL_CPUS)
ELSE (physical machine):
    CONSIDERED_CPUS = CPU_COUNT
```

**Important:** The `CONSIDERED_CPUS` value is what should be used for license compliance calculations, not the raw `CPU_COUNT`.

## Physical Host Identification

When multiple virtual machines run on the same physical host, license aggregation must count the physical host's CPUs only once. The inspector attempts to identify the underlying physical host using various methods:

### Detection Methods by Platform

**AIX PowerVM:**
- Hardware serial numbers
- System identifiers
- PowerVM system name

**Linux Virtualization:**
- VMware: Hypervisor host UUID
- KVM: Host system information
- Other: Hypervisor-specific identifiers

**Solaris:**
- Global zone identifiers
- Host system ID
- Banner information

### Confidence Levels

- **high**: Physical host identification is reliable and consistent
- **medium**: Identification method is reasonable but may have limitations
- **low**: Fallback methods used; manual verification recommended
- **none**: Physical host identification failed

## Product Detection

The inspector automatically detects running webMethods products by scanning system processes:

### Detection Process

1. **Process Scanning**: Uses `ps` command to list all running processes
2. **Pattern Matching**: Applies grep patterns from `product-detection-config.csv`
3. **Product Mapping**: Maps detected processes to appropriate product codes based on `NODE_TYPE`
4. **Status Recording**: Records "present" or "absent" for each configured product

### Supported Products

Currently configured to detect:

- **Integration Server** (`IS_ONP_PRD`/`IS_ONP_NPR`): Java processes with "IntegrationServer" in command line
- **Broker Server** (`BRK_ONP_PRD`/`BRK_ONP_NPR`): Native processes with "awbrokermon" in command line

### Adding New Products

To detect additional products, add entries to `landscape-config/product-detection-config.csv`:

```csv
process-grep-pattern,product-mnemo-id-prod,product-mnemo-id-nonprod,process-type,notes
MyService,MYSVC_PRD,MYSVC_NPR,java,Custom service detection
```

And ensure product codes are defined in `landscape-config/product-codes.csv`.

## Scheduled Execution

### Using Cron (Linux/AIX/Solaris)

Add to crontab for daily execution at 2 AM:

```bash
crontab -e

# Add this line (with environment variables for production):
0 2 * * * export IWDLI_DETECTION_CONFIG_DIR=/opt/iwl/detection-config; export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/iwl/landscape-config; export IWDLI_DATA_DIR=/var/data/inspector-output; export IWDLI_AUDIT_DIR=/var/log/inspector-audit; /opt/inspector/common/detect_system_info.sh >> /var/log/license-inspector.log 2>&1
```

**Alternative: Use a wrapper script for cleaner cron setup**

Create `/opt/inspector/bin/run-inspector.sh`:
```bash
#!/bin/sh
# Wrapper script for scheduled inspector execution

# Set environment
export IWDLI_HOME=/opt/inspector
export IWDLI_DETECTION_CONFIG_DIR=/opt/iwl/detection-config
export IWDLI_LANDSCAPE_CONFIG_DIR=/opt/iwl/landscape-config
export IWDLI_DATA_DIR=/var/data/inspector-output
export IWDLI_AUDIT_DIR=/var/log/inspector-audit
export PATH=/usr/bin:/bin

# Run inspector
/opt/inspector/common/detect_system_info.sh

# Exit with inspector's exit code
exit $?
```

Then in crontab:
```bash
0 2 * * * /opt/inspector/bin/run-inspector.sh >> /var/log/license-inspector.log 2>&1
```

### Output Management

Consider implementing data retention and cleanup:

```bash
# Keep only last 90 days of CSV output files
find /var/data/inspector-output -name "iwdli_output_*.csv" -mtime +90 -delete

# Keep only last 90 days of audit logs
find /var/log/inspector-audit -type d -name "20*" -mtime +90 -exec rm -rf {} \;
```

**Note**: With separate data and audit directories, you can safely upgrade code without affecting historical data or logs.

## Troubleshooting

### Debug Mode

Enable debug mode to see detailed execution traces:

```bash
export IWDLI_DEBUG=ON
./detect_system_info.sh
```

Or set the environment variable:

```bash
export IWDLI_DEBUG=ON
./detect_system_info.sh
```

### Debug Output Files

Debug mode creates additional files in the session audit directory:

- `ps-aux.out`: Complete process listing (BSD-style)
- `ps-ef.out`: Complete process listing (Unix-style)
- `<command>.out`: Standard output of each system command
- `<command>.err`: Standard error of each system command
- `iwdli_session.log`: Comprehensive execution log with timestamps

### Common Issues

**Issue: No product detected**
- Verify webMethods processes are actually running
- Check patterns in `product-detection-config.csv`
- Review `processes_<product>.out` files in debug mode

**Issue: Incorrect CPU count**
- Review eligibility determination in `session.log`
- Verify processor/OS/virt entries in eligibility CSV files
- Check `HOST_PHYSICAL_CPUS` and `PARTITION_CPUS` values

**Issue: Configuration not found**
- Ensure `$IWDLI_LANDSCAPE_CONFIG_DIR/<hostname>/node-config.conf` exists
- Verify hostname matches: `hostname` command output
- Check fallback to `$script_dir/node-config.conf`
- Verify `IWDLI_DETECTION_CONFIG_DIR` contains required CSV files

**Issue: Physical host identification failed**
- Review `HOST_ID_METHOD` and `HOST_ID_CONFIDENCE` in output
- Check platform-specific detection logs in session directory
- Low confidence is acceptable; reporter handles aggregation carefully

### Administrative Permissions

The script requires elevated permissions to access:
- Virtualization parameters (hypervisor information)
- Hardware details (processor information)
- System configuration (partition details on AIX)

Run with appropriate sudo/root access as needed for your platform.

## Integration with Reporters

### CSV File Collection

Inspection results are designed for centralized collection. With the code/data separation, you can use consistent directories across all nodes:

**Push Mode:**
```bash
# From inspector node, push latest CSV to central server
LATEST_FILE=$(ls -t ${IWDLI_DATA_DIR:-/var/data/inspector-output}/iwdli_output_*.csv | head -1)
scp "$LATEST_FILE" user@central-server:/data/inspections/$(hostname)/
```

**Pull Mode:**
```bash
# From central server, pull results from inspector nodes
HOSTNAME=webm-prod-server1
DATA_DIR=/var/data/inspector-output
ssh user@${HOSTNAME} "ls -t ${DATA_DIR}/iwdli_output_*.csv | head -1" | \
  xargs -I {} scp user@${HOSTNAME}:{} /data/inspections/${HOSTNAME}/
```

**Automated Collection Script:**
```bash
#!/bin/sh
# collect-inspector-data.sh - Centralized data collection

CENTRAL_DATA_DIR=/data/central-inspections
NODES_FILE=/etc/inspector-nodes.txt

while read hostname; do
    echo "Collecting from $hostname..."
    REMOTE_DATA_DIR=/var/data/inspector-output
    
    # Get latest CSV file
    LATEST=$(ssh user@${hostname} "ls -t ${REMOTE_DATA_DIR}/iwdli_output_*.csv 2>/dev/null | head -1")
    
    if [ -n "$LATEST" ]; then
        # Create target directory
        mkdir -p "${CENTRAL_DATA_DIR}/${hostname}"
        
        # Copy the data
        scp "user@${hostname}:${LATEST}" "${CENTRAL_DATA_DIR}/${hostname}/"
        echo "✓ Collected $(basename $LATEST) from $hostname"
    else
        echo "✗ No data found on $hostname"
    fi
done < "$NODES_FILE"
```

### Expected Reporter Functionality

The reporter application (planned) will:
1. Import CSV files into SQLite database
2. Validate data integrity
3. Aggregate CPU counts at physical host level using `PHYSICAL_HOST_ID`
4. Generate license compliance reports
5. Track trends over time

## Maintenance

### Updating Eligibility Data

As IBM updates their eligible processor and virtualization technology lists:

1. **Download latest IBM documentation**:
   - [Eligible Virtualization Technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Virtualization_Technology.pdf)
   - [Eligible Processor Technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Processor_Technology.pdf)

2. **Update CSV files**:
   - `$IWDLI_DETECTION_CONFIG_DIR/ibm-eligible-processors.csv`
   - `$IWDLI_DETECTION_CONFIG_DIR/ibm-eligible-virt-and-os.csv`

3. **Redistribute to all nodes** using the release system or by updating the shared detection-config directory

### Version Management

Track inspector versions for audit purposes:

```bash
# Create release with version number
./release.sh 1.2.0

# Document in change log
echo "Version 1.2.0 - Updated processor eligibility list" >> CHANGELOG.md
```

## Security Considerations

### Data Sensitivity

Inspection results contain system configuration details:
- Ensure appropriate file permissions on output directories
- Use encrypted channels for file transfers (scp, sftp)
- Restrict access to configuration files containing environment details

### Recommended Permissions

```bash
# Restrict access to configuration and output directories
chmod 750 /opt/iwl/detection-config/
chmod 750 /opt/iwl/landscape-config/
chmod 750 /var/data/inspector-output/
chmod 750 /var/log/inspector-audit/
chown root:sysadmin /opt/iwl/detection-config/
chown root:sysadmin /opt/iwl/landscape-config/
chown inspector:sysadmin /var/data/inspector-output/
chown inspector:sysadmin /var/log/inspector-audit/
```

## Reference Documentation

For additional context and requirements:

- **`../../README.md`**: Repository overview and component architecture
- **`../../REQUIREMENTS.md`**: Detailed requirements and data model specifications
- **`../../IMPLEMENTATION_GUIDE.md`**: Integration instructions and technical details

### IBM Official Resources

- [IBM Subcapacity Licensing Terms](https://www.ibm.com/software/passportadvantage/subcaplicensing.html)
- [IBM Container Licensing Terms](https://www.ibm.com/software/passportadvantage/containerlicenses.html)
- [IBM Eligible Virtualization Technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Virtualization_Technology.pdf)
- [IBM Eligible Processor Technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Processor_Technology.pdf)

## Support and Contributions

### Issue Reporting

When reporting issues, include:
- Platform details (OS, version)
- Inspector version
- Session log from debug mode
- Anonymized `inspect_output.csv` if relevant

### Testing

The inspector includes a comprehensive test suite for validation:

#### Comprehensive Test Suite (`test.sh`) - **RECOMMENDED**

Runs all test scenarios in an organized structure for complete validation:

```bash
./test.sh
```

**Test Scenarios:**
1. **Test 01:** Debug mode ON - Full diagnostic output
2. **Test 02:** Debug mode OFF - Normal execution (cron-ready)
3. **Test 03:** Debug mode OFF - Redirected output (automation-ready)
4. **Test 04:** Raw system commands - Unfiltered command outputs
5. **Test 05:** Permission check - Access and permission validation
6. **Test 06:** Configuration validation - CSV file integrity check

**Features:**
- All tests organized in `/tmp/iwdlm/test/<timestamp>/`
- Comprehensive summary file for quick analysis
- Separate directories for each test scenario
- Captures all relevant diagnostic information
- Perfect for remote execution and offline analysis

**Quick Results:**
```bash
# Run complete test suite
./test.sh

# View summary
cat /tmp/iwdlm/test/*/test_summary.txt

# Package for remote analysis
tar -czf test-results.tar.gz /tmp/iwdlm/test/*
```

See the test suite output for detailed results of all test scenarios.

## License

Copyright IBM Corp. 2025 - 2025  
SPDX-License-Identifier: Apache-2.0

See `../../LICENSE` for full license text.
