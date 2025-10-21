# Acceptance Test Suite for go-sqlite-cli Reporter

This directory contains the acceptance test harness for the go-sqlite-cli reporter application. The tests validate end-to-end functionality of the complete workflow from database initialization through report generation.

## Overview

The acceptance tests use **shunit2** (a shell-based unit testing framework) to verify that the statically-linked binary works correctly in the target environment.

## Test Framework

- **Framework**: shunit2 (included in licmon-dev01 devcontainer)
- **Language**: POSIX-compliant shell script
- **Execution Environment**: Alpine Linux (licmon-dev01 devcontainer)
- **Test Runner**: `test_acceptance.sh`

## Directory Structure

```
acceptance-test/
├── README.md                    # This file
├── test_acceptance.sh           # Main test script
├── fixtures/                    # Test input files
│   ├── product-codes.csv        # Reference data for product codes
│   ├── iwdli_output_omis446_test.csv    # Sample inspection data (Solaris)
│   ├── iwdli_output_it045aia_test.csv   # Sample inspection data (AIX)
│   └── iwdli_output_rhel_test.csv       # Sample inspection data (Linux)
├── expected-output/             # Expected output files for validation
├── test-data/                   # Generated test data (gitignored)
│   └── test-acceptance.db       # Test database (preserved for debugging)
└── .gitignore                   # Ignore test output files
```

## Test Scenarios

The acceptance test suite validates the following high-level scenarios:

### 1. Database Initialization
- **Test**: `testDatabaseInitialization`
- **Validates**: Database creation, schema initialization, version tracking
- **Expected**: Database file created with required tables

### 2. Duplicate Initialization Prevention
- **Test**: `testDatabaseInitializationFailsIfExists`
- **Validates**: Error handling when database already exists
- **Expected**: Clear error message, no data corruption

### 3. Reference Data Loading
- **Test**: `testLoadReferenceData`
- **Validates**: Import of product codes and license terms
- **Expected**: Product codes table populated from CSV

### 4. Single File Import
- **Test**: `testImportSingleInspectionFile`
- **Validates**: Import of single inspector CSV file
- **Expected**: Measurement and product detection data stored

### 5. Multiple File Import
- **Test**: `testImportMultipleInspectionFiles`
- **Validates**: Sequential import of multiple inspection files
- **Expected**: All measurements stored, distinct hosts tracked

### 6. Report Generation
- **Test**: `testGenerateCoreAggregationReport`
- **Validates**: Core aggregation report generation
- **Expected**: Report output produced (implementation in progress)

### 7. Physical Host Tracking
- **Test**: `testPhysicalHostTracking`
- **Validates**: Physical host ID capture and tracking
- **Expected**: Distinct physical hosts identified correctly

### 8. Product Detection Tracking
- **Test**: `testDetectedProductsTracking`
- **Validates**: Product presence/absence tracking
- **Expected**: Detected products recorded with status

### 9. Complete Workflow
- **Test**: `testCompleteWorkflow`
- **Validates**: Full end-to-end workflow
- **Expected**: All steps execute successfully in sequence

## Running Tests

### Prerequisites

1. Build the static binary first:
   ```bash
   cd reporters/go-sqlite-cli
   make build-static
   ```

### Run Acceptance Tests

```bash
# From the go-sqlite-cli directory
make acceptance-test
```

### Run All Tests (Unit + Acceptance)

```bash
make test-all
```

### Run Tests Standalone

```bash
# From acceptance-test directory
./test_acceptance.sh
```

## Test Output

Tests produce output in this format:

```
==========================================
Acceptance Test Suite for go-sqlite-cli
==========================================
Test directory: /path/to/acceptance-test
Binary: /path/to/target/bin/seed-go-sqlite-api-static
==========================================

Testing database initialization...
[PASS] Database initialization successful

Testing database initialization with existing database...
[PASS] Duplicate initialization correctly prevented

...

Ran 9 tests.

OK
==========================================
Acceptance Test Suite Complete
==========================================
Test database preserved at: ./test-data/test-acceptance.db
==========================================
```

## Test Data

### Fixture Files

Fixture files in the `fixtures/` directory represent realistic inspection outputs:

- **product-codes.csv**: Reference data mapping product mnemonics to IBM product codes and license terms
- **iwdli_output_omis446_test.csv**: Solaris physical server (16 cores, SPARC M7)
- **iwdli_output_it045aia_test.csv**: AIX virtualized (PowerVM, 48 host cores, 1 virtual CPU)
- **iwdli_output_rhel_test.csv**: Linux virtualized (VMware, 40 host cores, 4 virtual CPUs)

### Generated Test Data

Test execution creates files in `test-data/` (gitignored):

- **test-acceptance.db**: SQLite database with test data (preserved for debugging)
- **temp-output.txt**: Temporary command output (cleaned up after each test)

## Debugging Failed Tests

### View Test Database

After test execution, inspect the test database:

```bash
sqlite3 acceptance-test/test-data/test-acceptance.db
```

Example queries:

```sql
-- View all measurements
SELECT * FROM measurements;

-- Count measurements by host
SELECT main_fqdn, COUNT(*) FROM measurements GROUP BY main_fqdn;

-- Check physical host tracking
SELECT DISTINCT physical_host_id, host_id_method FROM measurements;

-- View detected products
SELECT * FROM detected_products WHERE status = 'present';

-- Check product codes
SELECT * FROM product_codes;
```

### Run Individual Tests

You can run specific tests by modifying `test_acceptance.sh`:

```bash
# Comment out other test functions, keep only the one you want
# testDatabaseInitialization
# testLoadReferenceData
testImportSingleInspectionFile  # <-- Only this one will run
```

### Enable Verbose Output

Modify test script to see detailed command output:

```bash
# In test_acceptance.sh, change:
${BINARY} init --db-path "${TEST_DB}" > "${TEMP_OUTPUT}" 2>&1

# To:
${BINARY} init --db-path "${TEST_DB}" 2>&1 | tee "${TEMP_OUTPUT}"
```

## Adding New Tests

To add a new test case:

1. **Create test function** in `test_acceptance.sh`:
   ```bash
   testMyNewFeature() {
       echo "Testing my new feature..."
       checkBinary
       
       # Setup
       ${BINARY} init --db-path "${TEST_DB}" > /dev/null 2>&1
       
       # Execute test
       ${BINARY} my-new-command --option value > "${TEMP_OUTPUT}" 2>&1
       
       # Assert
       assertTrue "Should succeed" "[ $? -eq 0 ]"
       
       echo "${TEST_PASSED} My new feature works"
   }
   ```

2. **Add fixture data** if needed in `fixtures/`

3. **Run tests** to verify:
   ```bash
   make acceptance-test
   ```

## Test Assertions

The test suite uses shunit2 assertion functions:

- `assertTrue "message" "condition"` - Assert condition is true
- `assertEquals "expected" "actual"` - Assert values are equal
- `fail "message"` - Fail test with message
- `assertNotNull "value"` - Assert value is not null

## Known Limitations

1. **Report Testing**: Some report generation tests may produce warnings if report commands are still in development
2. **Binary Location**: Tests assume static binary is at `../target/bin/seed-go-sqlite-api-static`
3. **Environment**: Tests are designed for Alpine Linux environment (licmon-dev01 devcontainer)

## Integration with Build Process

Acceptance tests are integrated into the Makefile:

- `make acceptance-test` - Run acceptance tests only (requires prior build)
- `make build-static-with-tests` - Build static binary and run acceptance tests
- `make test-all` - Run unit tests, build, and acceptance tests

## Continuous Integration

These tests are designed to run:

1. **After successful build** of the static binary
2. **Inside the devcontainer** (licmon-dev01)
3. **Before containerization** of the application
4. **As part of release validation**

## Troubleshooting

### Binary Not Found

**Error**: `Binary not found at .../seed-go-sqlite-api-static`

**Solution**: Build the static binary first:
```bash
make build-static
```

### Permission Denied

**Error**: `Permission denied` when running test script

**Solution**: Make script executable:
```bash
chmod +x acceptance-test/test_acceptance.sh
```

### shunit2 Not Found

**Error**: `shunit2: not found`

**Solution**: Ensure you're running in licmon-dev01 devcontainer which includes shunit2

### Database Already Exists

**Error**: Test fails because database exists

**Solution**: Clean up test data:
```bash
rm -f acceptance-test/test-data/test-acceptance.db
```

## Contributing

When adding new features to go-sqlite-cli:

1. Add corresponding acceptance test(s)
2. Update fixture data if needed
3. Update this README with new test scenarios
4. Ensure all tests pass before submitting changes

## References

- [shunit2 Documentation](https://github.com/kward/shunit2)
- [REQUIREMENTS.md](../../REQUIREMENTS.md) - Project requirements
- [Makefile](../Makefile) - Build automation
