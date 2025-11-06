# Acceptance Test for iwldr

This acceptance test validates that the `iwldr` binary works correctly on your AIX 7.2 system after deployment.

## What This Test Does

The test performs comprehensive validation including:

1. **Binary Check** - Verifies the binary exists and is executable
2. **Help Command** - Tests basic command execution
3. **Database Initialization** - Creates a new SQLite database
4. **CSV Import** - Imports 7 inspector CSV files from multiple hosts
5. **Host Count Verification** - Validates logical and physical host detection
6. **OS Distribution Check** - Verifies AIX and Solaris system identification
7. **Physical Host Deduplication** - Tests VM detection on shared hardware
8. **Report Generation** - Generates daily summary, hosts, and compliance reports
9. **Database Verification** - Confirms database schema and queryability

## Test Data Coverage

The test includes **7 different hosts** across multiple OS types:

### AIX Systems (6 hosts)
- **i23** - AIX 6.1 VM (shares physical host with i45)
- **i45** - AIX 6.1 VM (shares physical host with i23)
- **i90** - AIX 6.1 standalone
- **i86** - AIX 7.2
- **i88** - AIX 7.2
- **i95** - AIX 7.2

### Solaris Systems (1 host)
- **i40** - Solaris 10

### Physical Host Deduplication Test
The test verifies that **i23** and **i45** are correctly identified as VMs running on the same physical host (aix-machine-00FAF2264C00), resulting in **6 unique physical hosts** from 7 logical hosts.

## Prerequisites

- AIX 7.2 or higher
- The iwldr package extracted to a directory
- Write permissions in the acceptance-test directory

## Running the Test

### Quick Start

From the package root directory:

```bash
cd acceptance-test
./RUN_TEST.sh
```

### Expected Output

```
========================================================================
IBM webMethods License Data Reporter (iwldr)
Acceptance Test Suite
Platform: AIX 7.2
Date: 2025-11-06 12:00:00
========================================================================
[INFO] Checking prerequisites...
[INFO] Found 7 fixture files
========================================================================
[INFO] Running acceptance tests...
========================================================================

[INFO] Test 1: Binary exists and is executable
[PASS] Binary found and is executable

[INFO] Test 2: Help command works
[PASS] Help command executed successfully

[INFO] Test 3: Database initialization
[INFO] Cleaning up test data...
[PASS] Database created successfully

[INFO] Test 4: Import all inspector CSV files
[INFO] Importing 7 CSV files...
[PASS] All 7 CSV files imported successfully

[INFO] Test 5: Verify imported host data
[PASS] Found 7 logical hosts (expected 7)
[PASS] Found 6 physical hosts (expected 6 - deduplication working)

[INFO] Test 6: Verify OS type distribution
[PASS] Found 3 AIX 6.1 hosts
[PASS] Found 3 AIX 7.2 hosts
[PASS] Found 1 Solaris hosts

[INFO] Test 7: Verify physical host deduplication (VMs on same host)
[PASS] i23 and i45 correctly share physical host: aix-machine-00FAF2264C00

[INFO] Test 8: Generate daily summary report
[PASS] Daily summary report generated successfully
[INFO] Report preview (first 10 lines):
    Daily Product Summary Report
    ...

[INFO] Test 9: Generate hosts report
[PASS] Hosts report generated (45 lines)

[INFO] Test 10: Generate compliance report
[PASS] Compliance report command executed (may be empty without reference data)

[INFO] Test 11: Verify database schema and queryability
[PASS] Database schema is valid
[INFO] Total measurements in database: 7

========================================================================
Test Summary
========================================================================
Tests run:    11
Tests passed: 11
Tests failed: 0
========================================================================

✓ All tests passed!

[INFO] Test Data Summary:
[INFO]   - 7 logical hosts tested
[INFO]   - 6 unique physical hosts (includes VM deduplication)
[INFO]   - 3 AIX 6.1 hosts (2 VMs on shared hardware + 1 standalone)
[INFO]   - 3 AIX 7.2 hosts
[INFO]   - 1 Solaris 10 host

[INFO] The iwldr binary is working correctly on this system.
[INFO] You can now proceed with production deployment.
```

## What Gets Created

The test creates a temporary directory structure:

```
acceptance-test/
├── test-data/              # Created during test (not in package)
│   ├── acceptance-test.db  # Test database
│   └── report-output.txt   # Sample report
└── ...
```

## Interpreting Results

### All Tests Pass ✓

If all tests pass, the binary is working correctly and you can proceed with production deployment.

### Some Tests Fail ✗

If tests fail, check the following:

#### "Binary not found" or "Binary is not executable"
```bash
# Verify the binary exists
ls -l ../bin/iwldr

# Make it executable
chmod +x ../bin/iwldr
chmod +x ../bin/iwldr.bin
```

#### "Dependent module could not be loaded"
```bash
# Check dependencies
ldd ../bin/iwldr.bin

# Verify LIBPATH includes bundled libraries
echo $LIBPATH

# The wrapper script should set this automatically
# If not, manually set:
LIBPATH="$(pwd)/../lib:$LIBPATH"
export LIBPATH
```

#### "Permission denied" or "Cannot create file"
```bash
# Check write permissions
ls -ld acceptance-test/

# Ensure you have write access to create test-data directory
chmod u+w acceptance-test/
```

#### "CSV import failed"
```bash
# Verify fixtures exist
ls -l fixtures/

# Check if the CSV file is readable
cat fixtures/iwdli_output_i45_2025-11-06_133525.csv
```

## Cleaning Up

Test data is automatically cleaned between test runs. To manually clean:

```bash
rm -rf test-data/
```

## Support

For issues or questions:

1. Review the main DEPLOY_ON_AIX.md documentation
2. Check the DETECTED_DEPENDENCIES.txt file in the package root
3. Verify all prerequisites are met
4. Review error messages in the test output

## Next Steps

After successful acceptance testing:

1. Review DEPLOY_ON_AIX.md for production deployment instructions
2. Initialize your production database
3. Import reference data (license-terms.csv, product-codes.csv)
4. Set up scheduled imports for inspector data
5. Configure report generation

## Test Fixture Information

The test includes **7 representative CSV files** from actual system measurements across multiple operating systems:

### AIX 6.1 Systems (3 files)
- **iwdli_output_i23_2025-11-06_133525.csv** - AIX 6.1 VM
- **iwdli_output_i45_2025-11-06_133525.csv** - AIX 6.1 VM (same physical host as i23)
- **iwdli_output_i90_2025-11-06_133523.csv** - AIX 6.1 standalone

### AIX 7.2 Systems (3 files)
- **iwdli_output_i86_2025-11-06_133522.csv** - AIX 7.2
- **iwdli_output_i88_2025-11-06_133522.csv** - AIX 7.2
- **iwdli_output_i95_2025-11-06_133522.csv** - AIX 7.2

### Solaris Systems (1 file)
- **iwdli_output_i40_2025-11-06_133520.csv** - Solaris 10

These files demonstrate:
- System information capture across multiple OS versions
- Product detection data (if products are installed)
- Physical host identification and CPU type detection
- Virtual machine detection (i23 and i45 share physical host aix-machine-00FAF2264C00)
- Cross-platform support (AIX and Solaris)

The test validates that the reporter correctly:
- Imports data from all 7 hosts
- Identifies 6 unique physical hosts (VM deduplication)
- Handles different OS types and versions
- Generates accurate reports from the imported data

This comprehensive test coverage ensures the binary will work correctly with your production landscape data.
