# Acceptance Test for iwldr

This acceptance test validates that the `iwldr` binary works correctly on your AIX 7.2 system after deployment.

## What This Test Does

The test performs the following validations:

1. **Binary Check** - Verifies the binary exists and is executable
2. **Help Command** - Tests basic command execution
3. **Database Initialization** - Creates a new SQLite database
4. **CSV Import** - Imports a sample inspector CSV file
5. **Report Generation** - Generates a daily summary report
6. **Database Verification** - Confirms database integrity

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
Date: 2025-11-04 12:00:00
========================================================================
[INFO] Checking prerequisites...
[INFO] Found 2 fixture files
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

[INFO] Test 4: Import inspector CSV file
[INFO] Using sample: iwdli_output_it045aia_2025-10-24_100000.csv
[PASS] CSV file imported successfully

[INFO] Test 5: Generate daily summary report
[PASS] Report generated successfully
[INFO] Report preview:
    Daily Product Summary Report
    Database: acceptance-test/test-data/acceptance-test.db
    ...

[INFO] Test 6: Verify database contents
[PASS] Database is queryable

========================================================================
Test Summary
========================================================================
Tests run:    6
Tests passed: 6
Tests failed: 0
========================================================================

✓ All tests passed!

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
cat fixtures/iwdli_output_it045aia_2025-10-24_100000.csv
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

The test includes sample inspector CSV files from actual system measurements:

- **it045aia** - AIX 6.1 system sample
- **ix40** - AIX 7.2 system sample (if included)

These files are representative of real inspector output and demonstrate:
- System information capture
- Product detection data
- Physical host identification
- Virtual machine detection

The test uses one file for basic validation. Production use will involve importing files from all your landscape nodes.
