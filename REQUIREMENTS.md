# Requirements

This repository encapsulates tools to inspect and centralize license metrics for webMethods landscapes whenever the official metrics are insufficient.

It contains multiple smaller applications that group into two categories:

1. **Inspectors**: applications that run on the inspected node, usually a virtual machine or a physical box. These are run on a scheduled manner, for example under the cron job, and gather the necessary information in files.
2. **Reporters**: applications that are run centrally on a node of administrator's choice, gather all files from the inspectors in the landscape and produce reporting aggregates.

## License terms and their mapping

License terms are IBM public documents like `https://www.ibm.com/support/customer/csol/terms/?id=L-USRQ-RKUUCN&lc=en`. These have a code, like `L-USRQ-RKUUCN`, that participate as resource ID in the URL like this `https://www.ibm.com/support/customer/csol/terms/?id=${TERMS_DOCUMENT_ID}&lc=en`

License terms participate in "programs" that have identifiers like `5900-BGP`. Multiple terms may participate to a program.

Products installed are identified according to a different coding table, that is provided for all application in the csv file `product-codes.csv` present in the root folder of the repository. This file will grow as more products are considered in time. This file also provides the mapping between a product code and its license terms identifier.

License terms are articulated and change in time. This repository has to me maintained accordingly. It is important to note that evaluating the license terms requires the ingestion of relevant parameters like operating system type, virtualization type, parameters of the virtualization configuration such as partitioning, reservation, capacity of the virtualizing host, processor type. IBM also defines a list of "eligible" processor types and virtualization technologies and establishes rules on how to consider the metrics in function of this eligibility. For example, if a virtualization technology is not eligible and the license metric is virtual CPU (vcpu), then the tool must measure all the cores of the virtualizing host.

## Repository File Structure

The repository is organized as a multi-inspector, multi-reporter system with the following structure:

### Top-Level Organization

- **`inspectors/`**: Contains different inspector implementations for various use cases
- **`reporters/`**: Contains reporting applications that aggregate inspector outputs
- **`local/`**: Directory containing test cases and results (excluded from version control)

### Default Inspector (`inspectors/default/`)

The primary inspector implementation for webMethods license monitoring:

#### Common Resources (`inspectors/default/common/`)

- **`detect_system_info.sh`**: Primary system inspection script (POSIX-compliant)

#### Landscape Configuration (`inspectors/default/landscape-config/`)

- **`<hostname>/node-config.conf`**: Host-specific configuration directories based on system hostname
- **`product-detection-config.csv`**: Shared process detection patterns for all nodes
- **`ibm-eligible-processors.csv`**: Shared processor eligibility reference
- **`ibm-eligible-virt-and-os.csv`**: Shared OS/virtualization eligibility reference  
- **`product-codes.csv`**: Shared product code mappings
- **Additional CSV files**: processor-codes.csv, virt-tech-codes.csv for extended categorization
- **Example configurations**: `aix-61-host1/`, `aix-72-host2/`, `sunos-58-host3/`

**Configuration Management Strategy:**
- Configuration files are versioned and deployed separately from code
- This allows updating eligibility rules when IBM releases new eligible processors/OS without code changes
- Configuration directory location can be customized via `IWDLI_CONFIG_DIR` environment variable
- Inspector fails with clear error if required CSV files are not found in configured location

#### Release and Deployment System (`inspectors/default/`)

- **`release.sh`**: Creates versioned tar.gz deployment packages
- **`install.sh`**: Auto-generated installation script (created during release process)
- **`test.sh`**: Comprehensive test suite for validation
- **Deployment packages**: `ibm-webmethods-license-inspector-<version>.tar.gz`

**Code/Configuration Separation:**
- Inspector code (scripts in `common/`) can be updated independently of configuration
- Configuration files (`landscape-config/`) can be updated independently of code
- Use `IWDLI_CONFIG_DIR` environment variable to point to configuration location
- Typical deployment:
  - Code: `/opt/iwdli/common/`, `/opt/iwdli/test.sh`
  - Config: `/etc/iwdli-config/landscape-config/` or `/opt/landscape-config/`
  - Data: `/var/data/iwdli-output/` (controlled by `IWDLI_DATA_DIR`)

#### Test Infrastructure (`inspectors/default/`)

- **`test.sh`**: Comprehensive test harness for validating system detection functionality

### Reporters

#### Go SQLite CLI Reporter (`reporters/go-sqlite-cli/`)

**Status**: Planned implementation for future development

**Purpose**: Centralized reporting application that aggregates inspector outputs and provides license compliance reporting.

**Key Features** (planned):
- SQLite-based data storage for inspector results aggregation
- Command-line interface for data import and reporting
- Go-based implementation for single-file deployment
- Minimal dependencies on target environment
- Support for both push and pull data collection modes

**Data Flow**:
1. Inspectors generate CSV outputs on monitored nodes
2. Reporter collects CSV files via file transfer (push/pull)
3. Data is imported into SQLite database with validation
4. Reports generated for license compliance analysis


### Reference Data Format

The CSV reference files follow these schemas:

**`ibm-eligible-processors.csv`**:
- processor-vendor, processor-brand, processor-type, os, earliest-version-with-ilmt-support

**`ibm-eligible-virt-and-os.csv`**:
- virtualization-vendor, eligible-virtualization-technology, eligible-os, sub-capacity-eligible-form, earliest-version-having-ilmt-support

**`product-codes.csv`**:
- product-mnemo-id, product-code, product-name, mode, license-terms-id, notes

**`product-detection-config.csv`**:
- process-grep-pattern, product-mnemo-id-prod, product-mnemo-id-nonprod, process-type, notes


## Inspectors

Inspectors are implemented as POSIX-compliant shell scripts with maximum portability for operating systems like Solaris SunOS, IBM AIX, Linux. For Windows hosts, PowerShell and batch file implementations are acceptable.

### Current Implementation

The primary inspector is implemented as `common/detect_system_info.sh`, a comprehensive system detection script that:

- **Detects system parameters**: Operating system, version, CPU count, virtualization status, processor information
- **Performs eligibility checking**: Uses CSV-based reference files to determine IBM license eligibility for processors, OS, and virtualization technologies
- **Calculates license metrics**: Determines the appropriate CPU count for licensing based on eligibility rules and physical constraints
- **Detects running products**: Scans running processes to identify webMethods components and maps them to appropriate product codes
- **Generates structured output**: Creates timestamped session directories with CSV results and detailed logs
- **Supports debugging**: Includes optional debug mode for troubleshooting and validation
- **Hostname-based configuration**: Automatically loads configuration from `landscape-config/<hostname>/` directory structure
- **Enhanced tracing**: Captures full process listings (ps-aux.out, ps-ef.out) for comprehensive debugging
- **Physical host identification**: Captures unique identifiers for physical hosts to enable proper license aggregation in virtualized environments

### Physical Host Identification Requirements

**Business Requirement**: When multiple virtual machines run on the same physical host, license aggregation must count the physical host's CPU cores only once, rather than summing the virtual CPU allocations of individual VMs.

**Technical Requirements**:
1. **Host Identifier Detection**: Each inspector must attempt to determine a unique identifier for the underlying physical host when running in a virtualized environment
2. **Cross-VM Correlation**: The identifier must be consistent across all VMs running on the same physical host
3. **Fallback Strategy**: When physical host identification is not possible, the system must clearly indicate this limitation
4. **Reporter Aggregation**: The reporter must use physical host identifiers to aggregate CPU counts at the physical host level

**Implementation Approach**:
- **AIX PowerVM**: Use hardware serial numbers, system identifiers, or hypervisor-provided host information
- **Linux Virtualization**: Attempt to detect hypervisor-specific host identifiers (VMware host UUID, KVM host info, etc.)
- **Solaris Zones**: Extract global zone or host system identifiers when possible
- **Fallback**: When host identification fails, use virtual machine's own identifier with clear marking

**CSV Output Enhancement**: The inspector output must include:
- `PHYSICAL_HOST_ID`: Unique identifier for the physical host (when detectable)
- `HOST_ID_METHOD`: Method used to determine the host ID (e.g., "hypervisor-uuid", "hardware-serial", "fallback-vm-id")
- `HOST_ID_CONFIDENCE`: Confidence level ("high", "medium", "low") indicating reliability of host identification

### File Structure and Dependencies

The default inspector implementation consists of:

- **Main detection script**: `inspectors/default/common/detect_system_info.sh`
- **Landscape configuration**: `inspectors/default/landscape-config/<hostname>/node-config.conf` with fallback to common directory
- **Reference tables**: CSV files in `inspectors/default/landscape-config/`
- **Release system**: `inspectors/default/release.sh` for creating deployment packages
- **Installation system**: Auto-generated `install.sh` for target system deployment

### Output Structure

Inspectors create session-based output directories with the following structure:
```
<output_base_dir>/
├── YYYYMMDD_HHMMSS/          # Timestamped session directory
│   ├── inspect_output.csv     # Structured system metrics in CSV format
│   ├── session.log           # Detailed execution log
│   ├── processes_<product>.out # Process details for detected products (debug mode)
│   └── <command>.out/.err    # Raw command outputs (when debug mode enabled)
```

### Product Detection

The inspector detects webMethods products through both process scanning and disk-based installation detection:

**Detection Methods:**
- **Process Detection**: Scans for running processes using configurable patterns from `product-detection-config.csv`
- **Disk Detection**: Searches filesystem for product installation directories when enabled per product
- **Dual Detection**: Products can be detected as installed, running, or both

**Product Detection Semantics:**

1. **Section Presence**: `<PRODUCT_CODE>` section MUST be present if product is detected as either running OR installed
2. **IBM Product Code**: `<PRODUCT_CODE>_IBM_PRODUCT_CODE=<value>` MUST be present when section exists (never N/A for detected products)
3. **Install Keys**: `<PRODUCT_CODE>_INSTALL_STATUS`, `<PRODUCT_CODE>_INSTALL_COUNT`, `<PRODUCT_CODE>_INSTALL_PATHS`
4. **Running Keys**: `<PRODUCT_CODE>_RUNNING_STATUS`, `<PRODUCT_CODE>_RUNNING_COUNT`, `<PRODUCT_CODE>_RUNNING_COMMANDLINES`

**Product Status Logic:**
- `<PRODUCT_CODE>,present`: Product is either running OR installed (or both) - section exists in CSV
- Products that are neither running nor installed: NO section created (omitted entirely from CSV)
- IBM product codes are populated for ALL detected products (only when sections exist)

**Configuration:**
- Products are mapped to appropriate license codes based on node type (PROD/NON_PROD)
- Configuration stored in `product-detection-config.csv` and `node-config.conf`
- Disk detection can be enabled/disabled per product via CSV configuration

**Example Output:**
```csv
# Product detected as installed but not running:
IS_ONP_PRD,present
IS_ONP_PRD_IBM_PRODUCT_CODE,D0YYWZX
IS_ONP_PRD_INSTALL_STATUS,installed
IS_ONP_PRD_INSTALL_COUNT,7
IS_ONP_PRD_INSTALL_PATHS,/app/webmethods/ISFE65/IntegrationServer;/app/webmethods/ISFE02/IntegrationServer
IS_ONP_PRD_RUNNING_STATUS,not-running
IS_ONP_PRD_RUNNING_COUNT,0
IS_ONP_PRD_RUNNING_COMMANDLINES,

# Product detected as running and installed:
IS_ONP_NPR,present
IS_ONP_NPR_IBM_PRODUCT_CODE,D0YZ2ZX
IS_ONP_NPR_INSTALL_STATUS,installed
IS_ONP_NPR_INSTALL_COUNT,19
IS_ONP_NPR_INSTALL_PATHS,/app/webmethods/ISFE80/IntegrationServer;...
IS_ONP_NPR_RUNNING_STATUS,running
IS_ONP_NPR_RUNNING_COUNT,3
IS_ONP_NPR_RUNNING_COMMANDLINES,java -Dwm.is.name=ISFE80...

# Product not detected (no section created - absent products are omitted):
# BRK_ONP_PRD section omitted entirely when neither running nor installed
```

### Usage Examples

**Basic system inspection:**
```bash
./detect_system_info.sh
```

**Debug mode with comprehensive tracing:**
```bash
./detect_system_info.sh debug
```

**Debug mode creates additional outputs:**
- `ps-aux.out` and `ps-ef.out`: Full process listings for comprehensive debugging
- `processes_<product>.out`: Product-specific process details when detected
- Enhanced trace output showing configuration lookup and detection steps

### Requirements

- Inspectors need administrative permissions to inspect core system configuration, including virtualization parameters required by IBM license terms
- Each inspector MUST be independently deployable with its reference CSV files
- Output MUST include all parameters required for license metric calculation according to IBM subcapacity licensing rules

## Eligibility Determination Framework

The current implementation includes a sophisticated eligibility checking system that determines whether detected system components qualify for IBM subcapacity licensing benefits.

### Eligibility Rules

1. **Processor Eligibility**: Determined by matching detected processor vendor/brand against `ibm-eligible-processors.csv`
2. **OS and Virtualization Eligibility**: Determined by matching OS and virtualization technology combinations against `ibm-eligible-virt-and-os.csv`
3. **CPU Count Calculation**: The final `CONSIDERED_CPUS` value is calculated based on:
   - If virtualization technology is not eligible: uses host physical CPU count
   - If virtualization technology is eligible: uses partition/VM allocated CPU count
   - Physical constraints: cannot exceed actual host physical CPU count

### Eligibility Data Sources

The eligibility determination is based on official IBM documentation:
- IBM Eligible Processor Technology documents
- IBM Eligible Virtualization Technology and OS combinations
- IBM Subcapacity Licensing terms and conditions

These are maintained as CSV reference files that can be updated as IBM eligibility rules evolve.

## Reporters

Reporters are independent applications, runnable from commandline on demand and on a scheduled basis. As the aggregation benefits from relational databases capabilities for ad-hoc queries and the data volume is low, data will be stored on a local sqlite file.

It is preferable to intersect as little as possible with the target environment, therefore a preferred solution is having the reporters written in go and statically linked so that the code deliverable is a single file.

### Reporter Testing

The go-sqlite-cli reporter includes comprehensive acceptance testing that validates end-to-end functionality:

**Test Framework**: The acceptance test harness uses shunit2 for shell-based testing and is integrated with the build process.

**Test Location**: `reporters/go-sqlite-cli/acceptance-test/`

**Test Execution**: Acceptance tests run automatically after a successful static binary build within the licmon-dev01 devcontainer.

**Test Scenarios**: The acceptance test suite validates the following workflow:
1. **Database Initialization**: Create a new SQLite database with complete schema
2. **Reference Data Loading**: Import structural data including product codes and license terms
3. **Inspection Data Import**: Load inspector-generated CSV files with measurement data (repeatable)
4. **Report Generation**: Produce license compliance reports against imported data

**Test Data**: The test harness uses fixture files including:
- Sample inspector CSV outputs from multiple nodes
- Product code mappings (product-codes.csv)
- Expected output validation files

**Integration**: Tests are integrated into the Makefile build process and can be run via:
```bash
make acceptance-test     # Run acceptance tests only
make test-all           # Run unit tests and acceptance tests
```

## Transport

The transport of information between inspectors and reporters occur via file transfer, either in push or pull mode, according to administrator's preference.

```

## Release and Deployment System

### Release Creation (`release.sh`)

The release system creates versioned deployment packages containing all necessary files for external testing and production deployment:

**Features:**
- Creates timestamped tar.gz packages: `ibm-webmethods-license-inspector-<version>.tar.gz`
- Automatically generates embedded `install.sh` script for target systems
- Validates file integrity and provides deployment instructions
- Includes all common resources, landscape-config structure, and documentation

**Usage:**
```bash
./release.sh [version]
```

**Package Contents:**
- All files from `common/` directory
- Complete `landscape-config/` directory structure with sample configurations
- Auto-generated `install.sh` for target system deployment
- Documentation (`README.md`, `REQUIREMENTS.md`)

### Installation System (`install.sh`)

The installation script is auto-generated during release creation and provides:

**Deployment Features:**
- Automatic backup creation of existing installations
- Permission setting for script execution
- Clear usage instructions and next steps
- Validates deployment environment

**Installation Process:**
1. Extract deployment package on target system
2. Run `./install.sh` to deploy files
3. Configure hostname-specific settings in `landscape-config/<hostname>/`
4. Execute `./detect_system_info.sh` for system inspection

**Backup Management:**
- Creates timestamped backups: `backup-<timestamp>/`
- Preserves existing configurations during upgrades
- Provides restoration instructions if needed

## Data Model for Reporters

The database is expected to contain the following tables:

1. landscape-nodes

    - **main-fqdn**, primary key, mandatory: FQDN of the node.
    - **hostname**, mandatory: Hostname of the node as seen from a shell inside the node
    - **mode**, mandatory: (`PROD` or `NON PROD`)
    - **expected-product-codes-list**, optional: CSV of product codes allocated to this node at design time. Usually a node should be intended to host a single product, but sometimes more products are installed for architectural convenience. Each token MUST have an entry in the product-codes table.
    - **expected-cpu-no**, optional: Number of cpus allocated at design time

2. license-terms

    - **term-id**, primary key, mandatory: Term identifier according to IBM's official terms and condition site. e.g. `L-USRQ-RKUUCN`
    - **program-number**, mandatory: Program number according to IBM's official terms and condition site. E.g. `5900-BGP`
    - **program-name**, mandatory. Full name of the program mentioned in the terms document. e.g. `IBM webMethods Integration Server 11.1`

3. product-codes

    - **product-mnemo-code**, primary key, mandatory. E.g. `IS_PRD` standing for `Integration Server Production Use`
    - **ibm-product-code**, mandatory. E.g. `D0R4NZX`
    - **product-name**: mandatory. E.g. `IBM webMethods Integration Server`
    - **mode**, mandatory: ( "PROD" or "NON PROD" )
    - **term-id**, mandatory: foreign key pointing to `license-terms.term-id`

4. measurements

    - **main-fqdn**, part of primary key, foreign key to landscape-nodes.main-fqdn
    - **product-mnemo-code**, part of primary Key, foreign key to products.product-code  
    - **timestamp**, part of primary Key (corresponds to detection_timestamp from CSV)
    - **session-directory**, optional: Path to the session directory containing detailed logs
    - **os-name**, mandatory: Operating system name (OS_NAME from CSV)
    - **os-version**, mandatory: Operating system version (OS_VERSION from CSV)
    - **cpu-count**, mandatory: Number of CPUs detected on the node (CPU_COUNT from CSV)
    - **is-virtualized**, mandatory: Boolean indicating if running in virtual environment (IS_VIRTUALIZED from CSV)
    - **virt-type**, optional: Type of virtualization technology detected (VIRT_TYPE from CSV)
    - **processor-vendor**, optional: Processor manufacturer (PROCESSOR_VENDOR from CSV)
    - **processor-brand**, optional: Processor model/brand (PROCESSOR_BRAND from CSV)
    - **host-physical-cpus**, optional: Physical CPUs of the virtualizing host (HOST_PHYSICAL_CPUS from CSV)
    - **partition-cpus**, optional: CPUs allocated to partition if applicable (PARTITION_CPUS from CSV)
    - **processor-eligible**, mandatory: Boolean indicating IBM license eligibility of processor (PROCESSOR_ELIGIBLE from CSV)
    - **os-eligible**, mandatory: Boolean indicating IBM license eligibility of OS (OS_ELIGIBLE from CSV)
    - **virt-eligible**, mandatory: Boolean indicating IBM license eligibility of virtualization technology (VIRT_ELIGIBLE from CSV)
    - **considered-cpus**, mandatory: Final CPU count for licensing calculation based on eligibility rules (CONSIDERED_CPUS from CSV)
    - **physical-host-id**, optional: Unique identifier of the physical host when running in virtualized environment (PHYSICAL_HOST_ID from CSV)
    - **host-id-method**, optional: Method used to determine physical host ID (HOST_ID_METHOD from CSV)
    - **host-id-confidence**, optional: Confidence level of physical host identification (HOST_ID_CONFIDENCE from CSV)

6. physical-hosts

    - **physical-host-id**, primary key, mandatory: Unique identifier for a physical host
    - **host-id-method**, mandatory: Method used to determine this ID (e.g., "hypervisor-uuid", "hardware-serial")
    - **host-id-confidence**, mandatory: Confidence level ("high", "medium", "low")
    - **first-seen**, mandatory: Timestamp when this physical host was first detected
    - **last-seen**, mandatory: Timestamp when this physical host was last detected
    - **max-physical-cpus**, optional: Maximum number of physical CPUs detected across all measurements
    - **notes**, optional: Additional information about the physical host

5. detected-products

    - **main-fqdn**, part of primary key, foreign key to landscape-nodes.main-fqdn
    - **product-mnemo-code**, part of primary key, foreign key to product-codes.product-mnemo-code
    - **timestamp**, part of primary key (corresponds to detection_timestamp from CSV)
    - **status**, mandatory: Detection status ("present" or "absent") indicating if product is running on the node

## License Aggregation Rules for Physical Hosts

When multiple virtual machines run on the same physical host, license calculation must follow these aggregation rules:

### CPU Count Aggregation

1. **Single Physical Host Detection**: When multiple VMs are identified as running on the same physical host (same `physical-host-id`), the reporter must count the physical host's CPU cores only once for licensing purposes.

2. **Aggregation Logic**:
   - Group all measurements by `physical-host-id` where `physical-host-id` is not null/unknown
   - For each physical host group, use the maximum `host-physical-cpus` value detected across all VMs
   - For VMs without reliable physical host identification, count their individual `considered-cpus` values
   - Apply IBM licensing eligibility rules at the physical host level when possible

3. **Confidence-Based Handling**:
   - **High confidence** host IDs: Aggregate CPU counts with full confidence
   - **Medium confidence** host IDs: Aggregate but flag for manual review
   - **Low confidence** host IDs: Count individually but report potential duplications

4. **Fallback Strategy**: When physical host identification fails or has low confidence, default to individual VM CPU counting to ensure compliance (may result in over-counting but maintains license compliance).

### Example Scenarios

**Scenario 1: Two VMs on Same Physical Host**
- VM1: `physical-host-id=HOST123`, `host-physical-cpus=16`, `considered-cpus=4`
- VM2: `physical-host-id=HOST123`, `host-physical-cpus=16`, `considered-cpus=8`
- **Result**: Count 16 physical CPUs once (not 4+8=12)

**Scenario 2: Mixed Environment**
- VM1: `physical-host-id=HOST123`, `host-physical-cpus=16`
- VM2: `physical-host-id=unknown`, `considered-cpus=4`
- **Result**: Count 16 CPUs for HOST123 + 4 CPUs for VM2 = 20 total

## Relevant Official Documents

- [IBM's subcapacity licensing general terms](https://www.ibm.com/software/passportadvantage/subcaplicensing.html)
- [IBM's container licensing general terms](https://www.ibm.com/software/passportadvantage/containerlicenses.html)
- [IBM's eligible virtualization technology and eligible OS technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Virtualization_Technology.pdf)
- [IBM's eligible processor technology](https://public.dhe.ibm.com/software/passportadvantage/SubCapacity/Eligible_Processor_Technology.pdf)
