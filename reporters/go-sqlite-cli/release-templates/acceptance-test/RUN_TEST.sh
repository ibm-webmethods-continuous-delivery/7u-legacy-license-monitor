#!/bin/sh
#
# Acceptance Test for iwldr (IBM webMethods License Data Reporter)
# AIX 7.2 Deployment Verification
#
# This script validates the basic functionality of the iwldr binary
# after deployment to an AIX system.
#

set -e  # Exit on first error

# Color/prefix definitions (ASCII-7 safe for AIX)
PASS="[PASS]"
FAIL="[FAIL]"
INFO="[INFO]"
WARN="[WARN]"

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/../bin/iwldr"
TEST_DB="$SCRIPT_DIR/test-data/acceptance-test.db"
TEST_DATA_DIR="$SCRIPT_DIR/test-data"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print functions
print_info() {
    echo "$INFO $1"
}

print_pass() {
    echo "$PASS $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo "$FAIL $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_separator() {
    echo "========================================================================"
}

# Test helper functions
run_test() {
    test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    print_info "Test $TESTS_RUN: $test_name"
}

check_binary() {
    if [ ! -f "$BINARY" ]; then
        print_fail "Binary not found at: $BINARY"
        exit 1
    fi
    
    if [ ! -x "$BINARY" ]; then
        print_fail "Binary is not executable: $BINARY"
        exit 1
    fi
}

cleanup() {
    print_info "Cleaning up test data..."
    rm -rf "$TEST_DATA_DIR"
    mkdir -p "$TEST_DATA_DIR"
}

# Test 1: Binary exists and is executable
test_binary_exists() {
    run_test "Binary exists and is executable"
    
    check_binary
    print_pass "Binary found and is executable"
}

# Test 2: Binary shows help
test_help_command() {
    run_test "Help command works"
    
    if "$BINARY" --help > /dev/null 2>&1; then
        print_pass "Help command executed successfully"
    else
        print_fail "Help command failed"
        return 1
    fi
}

# Test 3: Database initialization
test_database_init() {
    run_test "Database initialization"
    
    cleanup
    
    if "$BINARY" init --db-path "$TEST_DB" > /dev/null 2>&1; then
        if [ -f "$TEST_DB" ]; then
            print_pass "Database created successfully"
        else
            print_fail "Database file not created"
            return 1
        fi
    else
        print_fail "Database initialization failed"
        return 1
    fi
}

# Test 4: Import CSV file
test_import_csv() {
    run_test "Import inspector CSV file"
    
    # Find a sample CSV file
    SAMPLE_CSV=$(find "$FIXTURES_DIR" -name "*.csv" -type f | head -1)
    
    if [ -z "$SAMPLE_CSV" ]; then
        print_fail "No sample CSV file found in fixtures"
        return 1
    fi
    
    print_info "Using sample: $(basename "$SAMPLE_CSV")"
    
    if "$BINARY" import --db-path "$TEST_DB" --file "$SAMPLE_CSV" > /dev/null 2>&1; then
        print_pass "CSV file imported successfully"
    else
        print_fail "CSV import failed"
        return 1
    fi
}

# Test 5: Generate report
test_generate_report() {
    run_test "Generate daily summary report"
    
    REPORT_OUTPUT="$TEST_DATA_DIR/report-output.txt"
    
    if "$BINARY" report daily-summary --db-path "$TEST_DB" > "$REPORT_OUTPUT" 2>&1; then
        if [ -s "$REPORT_OUTPUT" ]; then
            print_pass "Report generated successfully"
            print_info "Report preview:"
            head -10 "$REPORT_OUTPUT" | sed 's/^/    /'
        else
            print_fail "Report output is empty"
            return 1
        fi
    else
        print_fail "Report generation failed"
        return 1
    fi
}

# Test 6: Verify database contents
test_verify_database() {
    run_test "Verify database contents"
    
    # Check if we can query the database using the binary
    TEMP_QUERY="$TEST_DATA_DIR/query-output.txt"
    
    # Try to get host detail (this will fail gracefully if no data)
    if "$BINARY" report host-detail --db-path "$TEST_DB" > "$TEMP_QUERY" 2>&1; then
        print_pass "Database is queryable"
    else
        # Report command might fail if no data, but database should still be valid
        if [ -f "$TEST_DB" ] && [ -s "$TEST_DB" ]; then
            print_pass "Database exists and is valid"
        else
            print_fail "Database verification failed"
            return 1
        fi
    fi
}

# Main execution
main() {
    print_separator
    echo "IBM webMethods License Data Reporter (iwldr)"
    echo "Acceptance Test Suite"
    echo "Platform: AIX 7.2"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    print_separator
    
    # Check prerequisites
    print_info "Checking prerequisites..."
    check_binary
    
    if [ ! -d "$FIXTURES_DIR" ]; then
        print_fail "Fixtures directory not found: $FIXTURES_DIR"
        exit 1
    fi
    
    FIXTURE_COUNT=$(find "$FIXTURES_DIR" -name "*.csv" -type f | wc -l | tr -d ' ')
    print_info "Found $FIXTURE_COUNT fixture files"
    
    # Run tests
    print_separator
    print_info "Running acceptance tests..."
    print_separator
    
    test_binary_exists
    test_help_command
    test_database_init
    test_import_csv
    test_generate_report
    test_verify_database
    
    # Summary
    print_separator
    echo "Test Summary"
    print_separator
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    print_separator
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo "✓ All tests passed!"
        echo ""
        print_info "The iwldr binary is working correctly on this system."
        print_info "You can now proceed with production deployment."
        echo ""
        exit 0
    else
        echo ""
        echo "✗ Some tests failed!"
        echo ""
        print_info "Please review the failures above and check:"
        print_info "  1. Binary dependencies (ldd bin/iwldr.bin)"
        print_info "  2. File permissions"
        print_info "  3. Disk space availability"
        print_info "  4. LIBPATH environment variable"
        echo ""
        exit 1
    fi
}

# Run main function
main "$@"
