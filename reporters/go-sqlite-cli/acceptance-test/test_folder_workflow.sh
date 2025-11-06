#!/bin/sh
# Acceptance test for folder-based import workflow
# Tests: input/processed/discards folder management and idempotent imports

set -e

# Test configuration
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="${TEST_DIR}/fixtures"
TEST_DATA_DIR="${TEST_DIR}/test-data"

# Binary location
BINARY="${TEST_DIR}/../target/bin/iwldr-static"

# Test folders
INPUT_DIR="${TEST_DATA_DIR}/input"
PROCESSED_DIR="${TEST_DATA_DIR}/processed"
DISCARDS_DIR="${TEST_DATA_DIR}/discards"
TEST_DB="${TEST_DATA_DIR}/test-workflow.db"

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Helper functions
log_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

cleanup() {
    log_info "Cleaning up test directories..."
    rm -rf "${INPUT_DIR}" "${PROCESSED_DIR}" "${DISCARDS_DIR}"
    rm -f "${TEST_DB}"
}

setup() {
    log_info "Setting up test environment..."
    cleanup
    mkdir -p "${INPUT_DIR}"
    mkdir -p "${PROCESSED_DIR}"
    mkdir -p "${DISCARDS_DIR}"
}

# Test 1: Verify binary exists
test_binary_exists() {
    log_info "Test 1: Checking if binary exists..."
    if [ ! -f "${BINARY}" ]; then
        log_error "Binary not found at ${BINARY}"
        log_error "Run 'make build-static' first"
        exit 1
    fi
    log_info "✓ Binary found"
}

# Test 2: Initialize database
test_init_database() {
    log_info "Test 2: Initializing database..."
    "${BINARY}" init --db-path "${TEST_DB}" > /dev/null 2>&1
    
    if [ ! -f "${TEST_DB}" ]; then
        log_error "Database not created"
        exit 1
    fi
    log_info "✓ Database initialized"
}

# Test 3: Copy fixtures to input folder
test_copy_fixtures() {
    log_info "Test 3: Copying test fixtures to input folder..."
    
    # Copy all sample files
    cp "${FIXTURES_DIR}/iwdli_output_"*.csv "${INPUT_DIR}/"
    
    FILE_COUNT=$(ls -1 "${INPUT_DIR}"/*.csv 2>/dev/null | wc -l)
    if [ "${FILE_COUNT}" -lt 1 ]; then
        log_error "No files copied to input folder"
        exit 1
    fi
    log_info "Copied ${FILE_COUNT} test files to input folder"
}

# Test 4: Import with folder workflow
test_import_with_folder_workflow() {
    log_info "Test 4: Running import with folder workflow..."
    
    # Load product codes reference data
    if [ -f "${FIXTURES_DIR}/product-codes.csv" ]; then
        "${BINARY}" import \
            --db-path "${TEST_DB}" \
            --input-dir "${INPUT_DIR}" \
            --load-reference \
            --product-codes "${FIXTURES_DIR}/product-codes.csv" \
            > /dev/null 2>&1
    else
        "${BINARY}" import \
            --db-path "${TEST_DB}" \
            --input-dir "${INPUT_DIR}" \
            > /dev/null 2>&1
    fi
    
    log_info "✓ Import command completed"
}

# Test 5: Verify files moved to processed folder
test_files_moved_to_processed() {
    log_info "Test 5: Verifying files moved to processed folder..."
    
    INPUT_COUNT=$(ls -1 "${INPUT_DIR}"/*.csv 2>/dev/null | wc -l)
    PROCESSED_COUNT=$(ls -1 "${PROCESSED_DIR}"/*.csv 2>/dev/null | wc -l)
    
    if [ "${INPUT_COUNT}" -ne 0 ]; then
        log_error "Expected 0 files in input folder, found ${INPUT_COUNT}"
        exit 1
    fi
    
    if [ "${PROCESSED_COUNT}" -lt 1 ]; then
        log_error "Expected at least 1 file in processed folder, found ${PROCESSED_COUNT}"
        exit 1
    fi
    
    log_info "All ${PROCESSED_COUNT} files moved to processed folder"
}

# Test 6: Verify data loaded in database
test_data_loaded() {
    log_info "Test 6: Verifying data loaded in database..."
    
    MEASUREMENT_COUNT=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM measurements;")
    if [ "${MEASUREMENT_COUNT}" -lt 1 ]; then
        log_error "Expected at least 1 measurement, found ${MEASUREMENT_COUNT}"
        exit 1
    fi
    
    DETECTED_PRODUCTS=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM detected_products WHERE status = 'present';")
    if [ "${DETECTED_PRODUCTS}" -lt 1 ]; then
        log_error "Expected at least 1 detected product, found ${DETECTED_PRODUCTS}"
        exit 1
    fi
    
    log_info "Data verified: ${MEASUREMENT_COUNT} measurements, ${DETECTED_PRODUCTS} detected products"
}

# Test 7: Test idempotent import (re-import same files)
test_idempotent_import() {
    log_info "Test 7: Testing idempotent import (re-import same files)..."
    
    # Copy files back to input folder
    cp "${PROCESSED_DIR}/iwdli_output_i4_20251021_090906.csv" "${INPUT_DIR}/"
    cp "${PROCESSED_DIR}/iwdli_output_i8_20251021_090906.csv" "${INPUT_DIR}/"
    
    # Get current record count
    BEFORE_COUNT=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM measurements;")
    
    # Re-import
    "${BINARY}" import \
        --db-path "${TEST_DB}" \
        --input-dir "${INPUT_DIR}" \
        > /dev/null 2>&1
    
    # Check count didn't increase (update, not insert)
    AFTER_COUNT=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM measurements;")
    
    if [ "${AFTER_COUNT}" -ne "${BEFORE_COUNT}" ]; then
        log_error "Record count changed on re-import: ${BEFORE_COUNT} -> ${AFTER_COUNT}"
        log_error "Expected idempotent behavior (update, not insert)"
        exit 1
    fi
    
    log_info "✓ Idempotent import verified (records updated, not duplicated)"
}

# Test 8: Test error handling with invalid CSV
test_error_handling() {
    log_info "Test 8: Testing error handling with invalid CSV..."
    
    # Create an invalid CSV file
    echo "Invalid,CSV,Format" > "${INPUT_DIR}/invalid_file.csv"
    echo "This is not a valid inspector CSV" >> "${INPUT_DIR}/invalid_file.csv"
    
    # Try to import (should fail gracefully)
    "${BINARY}" import \
        --db-path "${TEST_DB}" \
        --input-dir "${INPUT_DIR}" \
        > /dev/null 2>&1 || true
    
    # Check if invalid file moved to discards
    if [ ! -f "${DISCARDS_DIR}/invalid_file.csv" ]; then
        log_error "Invalid file not moved to discards folder"
        exit 1
    fi
    
    log_info "✓ Error handling verified (invalid file moved to discards)"
}

# Test 9: Verify folder auto-creation
test_folder_auto_creation() {
    log_info "Test 9: Testing folder auto-creation..."
    
    # Clean up folders
    rm -rf "${INPUT_DIR}" "${PROCESSED_DIR}" "${DISCARDS_DIR}"
    
    # Create only input folder with a test file
    mkdir -p "${INPUT_DIR}"
    cp "${FIXTURES_DIR}/iwdli_output_o6_20251021_090906.csv" "${INPUT_DIR}/"
    
    # Run import (should auto-create processed/discards folders)
    "${BINARY}" import \
        --db-path "${TEST_DB}" \
        --input-dir "${INPUT_DIR}" \
        > /dev/null 2>&1
    
    # Verify folders were created
    if [ ! -d "${PROCESSED_DIR}" ]; then
        log_error "Processed folder not auto-created"
        exit 1
    fi
    
    if [ ! -d "${DISCARDS_DIR}" ]; then
        log_error "Discards folder not auto-created"
        exit 1
    fi
    
    log_info "✓ Folder auto-creation verified"
}

# Test 10: Verify import session audit trail
test_audit_trail() {
    log_info "Test 10: Verifying import session audit trail..."
    
    SESSION_COUNT=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM import_sessions;")
    if [ "${SESSION_COUNT}" -lt 1 ]; then
        log_error "No import sessions recorded"
        exit 1
    fi
    
    SUCCESS_COUNT=$(sqlite3 "${TEST_DB}" "SELECT COUNT(*) FROM import_sessions WHERE status = 'success';")
    if [ "${SUCCESS_COUNT}" -lt 1 ]; then
        log_error "No successful import sessions recorded"
        exit 1
    fi
    
    log_info "✓ Audit trail verified: ${SESSION_COUNT} sessions, ${SUCCESS_COUNT} successful"
}

# Main test execution
main() {
    PRESERVE_MODE=0
    if [ "$1" = "--preserve" ]; then
        PRESERVE_MODE=1
        log_info "Running in PRESERVE mode (Test 9 skipped to keep processed files)"
        echo ""
    fi
    
    echo "========================================"
    echo "Folder-based Import Workflow Test Suite"
    echo "========================================"
    echo ""
    
    setup
    
    test_binary_exists
    test_init_database
    test_copy_fixtures
    test_import_with_folder_workflow
    test_files_moved_to_processed
    test_data_loaded
    test_idempotent_import
    test_error_handling
    
    # Test 9 removes folders - skip if preserving files
    if [ "${PRESERVE_MODE}" -eq 0 ]; then
        test_folder_auto_creation
    else
        log_warn "Skipping Test 9 (folder auto-creation) to preserve processed files"
    fi
    
    test_audit_trail
    
    echo ""
    echo "========================================"
    log_info "All tests passed!"
    echo "========================================"
    echo ""
    log_info "Test database: ${TEST_DB}"
    log_info "You can inspect it with: sqlite3 ${TEST_DB}"
    echo ""
    log_info "Folder status after tests:"
    log_info "  Input folder:     $(ls -1 "${INPUT_DIR}"/*.csv 2>/dev/null | wc -l) files"
    log_info "  Processed folder: $(ls -1 "${PROCESSED_DIR}"/*.csv 2>/dev/null | wc -l) files"
    log_info "  Discards folder:  $(ls -1 "${DISCARDS_DIR}"/*.csv 2>/dev/null | wc -l) files"
    echo ""
    log_warn "Note: Test 9 cleans folders to test auto-creation."
    log_warn "To preserve all imported files, run: ./test_folder_workflow.sh --preserve"
    echo ""
}

# Run tests
main "$@"
