# Host Detail Report Command

## Overview
The `host-detail` command displays detailed information for each host including product detection, system details, virtualization status, and eligibility flags.

## View Definition
The command queries the `v_host_detail` view which is created during database initialization. The view joins measurements and detected products tables.

## Usage

### Basic Syntax
```bash
./iwldr-static report host-detail --db-path <path-to-db> [flags]
```

### Available Flags
- `--db-path <path>`: Path to the SQLite database file (default: "data/license-monitor.db")
- `--host <fqdn>`: Filter by host FQDN (supports wildcards)
- `--product <code>`: Filter by product code
- `--from <date>`: Filter from date (YYYY-MM-DD format)
- `--to <date>`: Filter to date (YYYY-MM-DD format)
- `--format <type>`: Output format: table, csv, json (default: "table")
- `--output <file>`: Output file (default: stdout)

## Output Columns

The report includes the following columns:

1. **host_fqdn**: Fully qualified domain name of the host
2. **date**: Detection date (YYYY-MM-DD)
3. **virtual**: Whether the host is virtual (true/false)
4. **product_code**: Product mnemonic code
5. **running**: Whether the product is currently running (true/false)
6. **installed**: Whether the product is installed (true/false)
7. **virtual_cpus**: Number of virtual CPUs
8. **physical_host_id**: ID of the physical host (NULL for physical hosts)
9. **physical_cpus**: Number of physical CPUs (NULL if not applicable)
10. **operating_system**: OS name and version
11. **eligible_os**: Whether the OS is eligible (true/false)
12. **eligible_virtualization**: Whether virtualization is eligible (true/false)

## Examples

### 1. Display all host details (table format)
```bash
./iwldr-static report host-detail --db-path test-data/test-workflow.db
```

Output:
```
Host Detail Report
==========================================================================================================

Host FQDN  Date        Virt   Product      Run    Inst   vCPUs  Physical Host             pCPUs  OS         OS Elig  Virt Elig
--------   ----        ----   -------      ---    ----   -----  -------------             -----  --         -------  ---------
i8.local   2025-10-21  true   BRK_ONP_PRD  false  false  16     aix-machine-00FAF22C4C00  48     AIX 7.200  true     true
i9.local   2025-10-21  true   IS_ONP_PRD   false  false  2      aix-machine-00FAF22F4C00  48     AIX 6.100  false    false
o6.local   2025-10-21  false  BRK_ONP_PRD  true   true   16     o6                        N/A    Solaris 8  true     false
...

Total rows: 161
```

### 2. Filter by specific host
```bash
./iwldr-static report host-detail --db-path test-data/test-workflow.db --host i9.local
```

### 3. Filter by host and product
```bash
./iwldr-static report host-detail \
  --db-path test-data/test-workflow.db \
  --host i9.local \
  --product IS_ONP_PRD
```

Output:
```
Host Detail Report
==========================================================================================================

Host FQDN  Date        Virt  Product     Run    Inst   vCPUs  Physical Host             pCPUs  OS         OS Elig  Virt Elig
--------   ----        ----  -------     ---    ----   -----  -------------             -----  --         -------  ---------
i9.local   2025-10-21  true  IS_ONP_PRD  false  false  2      aix-machine-00FAF22F4C00  48     AIX 6.100  false    false
i9.local   2025-10-20  true  IS_ONP_PRD  false  false  2      aix-machine-00FAF22F4C00  48     AIX 6.100  false    false
...

Total rows: 20
```

### 4. Export to CSV
```bash
./iwldr-static report host-detail \
  --db-path test-data/test-workflow.db \
  --host o6.local \
  --format csv \
  --output host-detail.csv
```

Output:
```
Report written to host-detail.csv
```

CSV content:
```csv
host_fqdn,date,virtual,product_code,running,installed,virtual_cpus,physical_host_id,physical_cpus,operating_system,eligible_os,eligible_virtualization
o6.local,2025-10-21,false,BRK_ONP_PRD,true,true,16,o6,,Solaris 8,true,false
o6.local,2025-10-21,false,IS_ONP_PRD,false,true,16,o6,,Solaris 8,true,false
...
```

### 5. Export to JSON with date range
```bash
./iwldr-static report host-detail \
  --db-path test-data/test-workflow.db \
  --host i8.local \
  --product BRK_ONP_PRD \
  --from 2025-10-21 \
  --to 2025-10-21 \
  --format json
```

Output:
```json
[
  {
    "host_fqdn": "i8.local",
    "date": "2025-10-21T00:00:00Z",
    "virtual": "true",
    "product_code": "BRK_ONP_PRD",
    "running": "false",
    "installed": "false",
    "virtual_cpus": 16,
    "physical_host_id": "aix-machine-00FAF22C4C00",
    "physical_cpus": 48,
    "operating_system": "AIX 7.200",
    "eligible_os": "true",
    "eligible_virtualization": "true"
  },
  ...
]
```

## Use Cases

1. **Host Inspection**: Review detailed configuration and product inventory for specific hosts
2. **Virtual Machine Analysis**: Filter by virtual hosts to analyze VM deployments
3. **Product Distribution**: Check which hosts have specific products installed or running
4. **Eligibility Audits**: Identify hosts with OS or virtualization eligibility issues
5. **Physical Host Mapping**: Track virtual-to-physical host relationships
6. **Capacity Planning**: Analyze CPU allocation across virtual and physical hosts

## Technical Details

### View SQL
```sql
CREATE VIEW v_host_detail AS
SELECT 
    m.main_fqdn as host_fqdn,
    DATE(m.detection_timestamp) as date,
    CASE WHEN m.is_virtualized = 'yes' THEN 'true' ELSE 'false' END as virtual,
    d.product_mnemo_code as product_code,
    CASE WHEN d.status = 'present' THEN 'true' ELSE 'false' END as running,
    CASE WHEN d.install_count > 0 THEN 'true' ELSE 'false' END as installed,
    m.cpu_count as virtual_cpus,
    CASE 
        WHEN m.physical_host_id = '' OR m.physical_host_id = 'unknown' THEN NULL
        ELSE m.physical_host_id
    END as physical_host_id,
    CASE 
        WHEN m.host_physical_cpus = '' OR m.host_physical_cpus = 'unknown' THEN NULL
        ELSE CAST(m.host_physical_cpus AS INTEGER)
    END as physical_cpus,
    m.os_name || ' ' || m.os_version as operating_system,
    m.os_eligible as eligible_os,
    m.virt_eligible as eligible_virtualization
FROM measurements m
JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
    AND m.detection_timestamp = d.detection_timestamp
ORDER BY date DESC, host_fqdn, product_code;
```

### Implementation Files
- **View Definition**: `internal/database/views.go`
- **Report Generator**: `internal/reports/host_detail.go`
- **CLI Command**: `internal/cli/commands/report.go`

## Notes

- Physical hosts will show their own hostname in `physical_host_id`
- Physical hosts will have NULL or "N/A" for `physical_cpus` depending on output format
- Boolean values are represented as strings "true" or "false" for consistency across formats
- Date filtering uses YYYY-MM-DD format and is inclusive
- The view joins measurements and detected_products, so each row represents a product detection on a host
