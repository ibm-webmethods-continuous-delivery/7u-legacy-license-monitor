# Build variables
BINARY_NAME=iwldr
BUILD_DIR=target/bin
CMD_DIR=cmd/iwldr
DATA_DIR=data
ACCEPTANCE_TEST_DIR=acceptance-test
ACCEPTANCE_DB=$(ACCEPTANCE_TEST_DIR)/acceptance-test.db
REFERENCE_DATA_DIR=../../config-example
FIXTURES_DIR=$(ACCEPTANCE_TEST_DIR)/fixtures

# Go variables
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

# Build flags
LDFLAGS=-ldflags "-s -w"
BUILD_FLAGS=-v $(LDFLAGS)

# Default values (can be overridden via build-config.mk)
BUILD_LDFLAGS = $(LDFLAGS)
STATIC_BUILD_ENABLED = yes
PLATFORM = linux-amd64

# Platform-specific configuration (optional)
# Create build-config.mk for platform-specific settings
# Example for AIX: cp build-config-aix72.mk build-config.mk
# This will override the defaults above
include build-config.mk

.PHONY: all build clean test test-verbose coverage lint init-db build-production build-static build-all build-aix-info acceptance-test test-all help acceptance-test-clean acceptance-test-init acceptance-test-load acceptance-test-verify acceptance-test-full platform-info release-for-aix aix-release

# Default target
all: clean test build

# Build the application
build:
	@echo "Building $(BINARY_NAME) for $(PLATFORM)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) -v $(BUILD_LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./$(CMD_DIR)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Build for production (Linux amd64)
build-production:
	@echo "Building for production (Linux amd64)..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 ./$(CMD_DIR)
	@echo "Production build complete: $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64"

# Build static binary for containers (FROM scratch)
# Note: Not supported on AIX - use 'make build' instead
build-static:
	@echo "Building static binary for containers..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags '-linkmode external -extldflags "-static" -s -w' -o $(BUILD_DIR)/$(BINARY_NAME)-static ./$(CMD_DIR)
	@echo "Static build complete: $(BUILD_DIR)/$(BINARY_NAME)-static"
	@echo "Binary size: $$(du -h $(BUILD_DIR)/$(BINARY_NAME)-static | cut -f1)"
	@echo ""
	@echo "To build container on Windows host:"
	@echo "  1. Exit devcontainer"
	@echo "  2. cd prodcontainer"
	@echo "  3. build.bat"

# Build static binary and run acceptance tests
build-static-with-tests: build-static acceptance-test
	@echo "Build and acceptance tests complete"

# Build for multiple platforms
build-all:
	@echo "Building for multiple platforms..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 ./$(CMD_DIR)
	GOOS=windows GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe ./$(CMD_DIR)
	GOOS=darwin GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 ./$(CMD_DIR)
	GOOS=darwin GOARCH=arm64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 ./$(CMD_DIR)
	@echo "Multi-platform build complete:"
	@ls -la $(BUILD_DIR)/$(BINARY_NAME)-*

# Build for AIX (requires native compilation on AIX system)
build-aix-info:
	@echo "AIX Cross-compilation note:"
	@echo "Due to CGO SQLite dependency, AIX builds require:"
	@echo "1. Native compilation on AIX 7.2 system"
	@echo "2. Go 1.24+ installed on AIX"
	@echo "3. SQLite development libraries"
	@echo "4. Command: GOOS=aix GOARCH=ppc64 go build ./cmd/$(BINARY_NAME)"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	$(GOCLEAN)
	@rm -rf $(BUILD_DIR)
	@rm -rf target
	@echo "Clean complete"

# Run tests
test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

# Run tests with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	$(GOTEST) -v -race ./...

# Generate test coverage report
coverage:
	@echo "Generating coverage report..."
	$(GOTEST) -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Clean acceptance test database
acceptance-test-clean:
	@echo "Cleaning acceptance test database..."
	@rm -f $(ACCEPTANCE_DB)
	@echo "Acceptance test database cleaned"

# Initialize acceptance test database
acceptance-test-init: build
	@echo "Initializing acceptance test database..."
	@if [ -f $(ACCEPTANCE_DB) ]; then \
		echo "Warning: Database already exists at $(ACCEPTANCE_DB)"; \
		echo "Run 'make acceptance-test-clean' first to start fresh"; \
		exit 1; \
	fi
	./$(BUILD_DIR)/$(BINARY_NAME) init --db-path $(ACCEPTANCE_DB)
	@echo "Acceptance test database initialized"

# Load reference data and import test fixtures
acceptance-test-load: build
	@echo "Loading reference data and importing test fixtures..."
	@if [ ! -f $(ACCEPTANCE_DB) ]; then \
		echo "Error: Database not found. Run 'make acceptance-test-init' first"; \
		exit 1; \
	fi
	./$(BUILD_DIR)/$(BINARY_NAME) import \
		--db-path $(ACCEPTANCE_DB) \
		--load-reference \
		--product-codes $(ACCEPTANCE_TEST_DIR)/fixtures/config/contract-products/product-codes.csv \
		--license-terms $(REFERENCE_DATA_DIR)/ibm-terms/license-terms.csv \
		--dir $(FIXTURES_DIR)
	@echo "Test data loaded"

# Verify acceptance test data
acceptance-test-verify:
	@echo ""
	@echo "========================================="
	@echo "Acceptance Test Verification"
	@echo "========================================="
	@echo ""
	@echo "License Terms (should be 7):"
	@sqlite3 $(ACCEPTANCE_DB) "SELECT COUNT(*) as count FROM license_terms"
	@echo ""
	@echo "Product Codes (should be 16):"
	@sqlite3 $(ACCEPTANCE_DB) "SELECT COUNT(*) as count FROM product_codes"
	@echo ""
	@echo "Measurements:"
	@sqlite3 $(ACCEPTANCE_DB) "SELECT COUNT(*) as count FROM measurements"
	@echo ""
	@echo "Detected Products:"
	@sqlite3 $(ACCEPTANCE_DB) "SELECT COUNT(*) as count FROM detected_products"
	@echo ""
	@echo "Unique Hosts (should be 8):"
	@sqlite3 $(ACCEPTANCE_DB) "SELECT COUNT(DISTINCT main_fqdn) as count FROM measurements"
	@echo ""
	@echo "License Terms with Real Program Numbers:"
	@sqlite3 -header -column $(ACCEPTANCE_DB) "SELECT term_id, program_number FROM license_terms ORDER BY term_id"
	@echo ""
	@echo "View Test - Product Summary:"
	@sqlite3 -header -column $(ACCEPTANCE_DB) "SELECT DISTINCT product_mnemo_code, ibm_product_code, program_number FROM v_daily_product_summary LIMIT 5"
	@echo ""
	@echo "Session Directory Check (should have values):"
	@sqlite3 -header -column $(ACCEPTANCE_DB) "SELECT main_fqdn, session_directory FROM measurements LIMIT 3"
	@echo ""
	@echo "Import Statistics:"
	@sqlite3 -header -column $(ACCEPTANCE_DB) "SELECT COUNT(*) as total_imports, SUM(records_created) as total_records, COUNT(CASE WHEN status = 'success' THEN 1 END) as successful FROM import_sessions"
	@echo ""
	@echo "========================================="
	@echo "Testing All Report Commands"
	@echo "========================================="
	@echo ""
	@echo "1. Compliance Report (first 5 rows):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report compliance --db-path $(ACCEPTANCE_DB) --format table | head -7
	@echo ""
	@echo "2. Cores Report (first 5 rows):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report cores --db-path $(ACCEPTANCE_DB) --format table | head -7
	@echo ""
	@echo "3. Daily Summary Report (first 5 rows):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report daily-summary --db-path $(ACCEPTANCE_DB) --format table | head -7
	@echo ""
	@echo "4. Host Detail Report (first 5 rows):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report host-detail --db-path $(ACCEPTANCE_DB) --format table | head -7
	@echo ""
	@echo "5. Hosts Report (first 5 rows):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report hosts --db-path $(ACCEPTANCE_DB) --format table | head -7
	@echo ""
	@echo "6. Peak Usage Report (last 31 days):"
	@./$(BUILD_DIR)/$(BINARY_NAME) report peak --db-path $(ACCEPTANCE_DB) --format table
	@echo ""
	@echo "========================================="
	@echo "Verification Complete"
	@echo "========================================="

# Run full acceptance test (clean, init, load, verify)
acceptance-test-full: build acceptance-test-clean acceptance-test-init acceptance-test-load acceptance-test-verify
	@echo ""
	@echo "Full acceptance test complete!"

# Run acceptance tests (requires static binary to be built)
acceptance-test:
	@echo "Running acceptance tests..."
	@if [ ! -f $(BUILD_DIR)/$(BINARY_NAME)-static ]; then \
		echo "Error: Static binary not found. Run 'make build-static' first."; \
		exit 1; \
	fi
	@cd $(ACCEPTANCE_TEST_DIR) && ./test_acceptance.sh
	@echo "Acceptance tests complete"

# Run all tests (unit tests + acceptance tests)
test-all: test build-static acceptance-test
	@echo "All tests complete (unit + acceptance)"

# Run linter
lint:
	@echo "Running linter..."
	golangci-lint run ./...

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

# Initialize the database with default schema
init-db: build
	@echo "Initializing database..."
	@mkdir -p $(DATA_DIR)
	./$(BUILD_DIR)/$(BINARY_NAME) init
	@echo "Database initialized"

# Install the application
install: build
	@echo "Installing $(BINARY_NAME)..."
	cp $(BUILD_DIR)/$(BINARY_NAME) $(GOPATH)/bin/
	@echo "Installation complete"

# Run the application with help
run-help: build
	./$(BUILD_DIR)/$(BINARY_NAME) --help

# Development target - build and run with sample commands
dev: build init-db
	@echo "Development setup complete"
	@echo "Run './target/bin/$(BINARY_NAME) --help' for usage"

# Show platform configuration
platform-info:
	@echo "Platform Configuration:"
	@echo "  Platform: $(PLATFORM)"
	@echo "  Build flags: $(BUILD_LDFLAGS)"
	@echo "  Static builds: $(STATIC_BUILD_ENABLED)"
	@echo "  Go command: $(GOBUILD)"
	@echo ""
	@echo "System information:"
	@echo "  OS: $$(uname -s)"
	@echo "  Arch: $$(uname -m)"
	@echo "  Go version: $$($(GOCMD) version 2>/dev/null || echo 'not available')"
	@echo ""
	@if [ -f build-config.mk ]; then \
		echo "Using platform config: build-config.mk"; \
		echo "Content:"; \
		cat build-config.mk; \
	else \
		echo "No platform config file (using defaults)"; \
	fi

# Create AIX release package with bundled dependencies
# Usage: make release-for-aix VERSION=25B06_1
# If VERSION is not specified, defaults to timestamp
aix-release: release-for-aix
release-for-aix: build
	@echo "========================================================================"
	@echo "Creating AIX Release Package"
	@echo "========================================================================"
	@echo ""
	@VERSION="$${VERSION:-$$(date +%Y%m%d_%H%M%S)}"; \
	RELEASE_NAME="iwldr-aix72-$$VERSION"; \
	echo "Version: $$VERSION"; \
	echo "Release: $${RELEASE_NAME}.tar.gz"; \
	echo ""; \
	echo "Step 1: Building binary..."; \
	mkdir -p target/$${RELEASE_NAME}/bin; \
	mkdir -p target/$${RELEASE_NAME}/lib; \
	mkdir -p target/$${RELEASE_NAME}/acceptance-test/fixtures; \
	mkdir -p target/$${RELEASE_NAME}/acceptance-test/test-data; \
	echo ""; \
	echo "Step 2: Copying binary..."; \
	cp $(BUILD_DIR)/$(BINARY_NAME) target/$${RELEASE_NAME}/bin/$(BINARY_NAME).bin; \
	echo "  Binary: $(BUILD_DIR)/$(BINARY_NAME) -> target/$${RELEASE_NAME}/bin/$(BINARY_NAME).bin"; \
	echo ""; \
	echo "Step 3: Detecting and copying required libraries..."; \
	if command -v ldd >/dev/null 2>&1; then \
		echo "  Using ldd to detect dependencies..."; \
		ldd $(BUILD_DIR)/$(BINARY_NAME) > target/$${RELEASE_NAME}/DETECTED_DEPENDENCIES.txt; \
		echo "  Dependencies saved to: target/$${RELEASE_NAME}/DETECTED_DEPENDENCIES.txt"; \
		echo ""; \
		echo "  Copying gcc-go runtime libraries..."; \
		for libpath in /opt/freeware/lib/gcc/powerpc-ibm-aix*/*/ppc64/libgo.a; do \
			if [ -f "$$libpath" ]; then \
				cp "$$libpath" target/$${RELEASE_NAME}/lib/; \
				echo "    Copied: $$libpath"; \
				break; \
			fi; \
		done; \
		for libpath in /opt/freeware/lib/gcc/powerpc-ibm-aix*/*/ppc64/libgcc_s.a; do \
			if [ -f "$$libpath" ]; then \
				cp "$$libpath" target/$${RELEASE_NAME}/lib/; \
				echo "    Copied: $$libpath"; \
				break; \
			fi; \
		done; \
	else \
		echo "  Warning: ldd not available, attempting to copy libraries anyway..."; \
		cp /opt/freeware/lib/gcc/powerpc-ibm-aix7.2.0.0/13/ppc64/libgo.a target/$${RELEASE_NAME}/lib/ 2>/dev/null || true; \
		cp /opt/freeware/lib/gcc/powerpc-ibm-aix7.2.0.0/13/ppc64/libgcc_s.a target/$${RELEASE_NAME}/lib/ 2>/dev/null || true; \
	fi; \
	echo ""; \
	echo "Step 4: Creating wrapper script..."; \
	cp release-templates/wrapper-script.sh target/$${RELEASE_NAME}/bin/$(BINARY_NAME); \
	chmod +x target/$${RELEASE_NAME}/bin/$(BINARY_NAME); \
	chmod +x target/$${RELEASE_NAME}/bin/$(BINARY_NAME).bin; \
	echo "  Wrapper created: target/$${RELEASE_NAME}/bin/$(BINARY_NAME)"; \
	echo ""; \
	echo "Step 5: Creating deployment documentation..."; \
	sed 's/{{BUILD_DATE}}/'"$$(date '+%Y-%m-%d %H:%M:%S')"'/g' release-templates/DEPLOY_ON_AIX.md > target/$${RELEASE_NAME}/DEPLOY_ON_AIX.md; \
	echo "  Deployment guide created: target/$${RELEASE_NAME}/DEPLOY_ON_AIX.md"; \
	echo ""; \
	echo "Step 6: Creating README and RELEASE.TXT..."; \
	sed 's/{{BUILD_DATE}}/'"$$(date '+%Y-%m-%d %H:%M:%S')"'/g' release-templates/README.txt > target/$${RELEASE_NAME}/README.txt; \
	echo "=== IBM webMethods License Data Reporter (AIX) ===" > target/$${RELEASE_NAME}/RELEASE.TXT; \
	echo "Version: $$VERSION" >> target/$${RELEASE_NAME}/RELEASE.TXT; \
	echo "Release Date: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> target/$${RELEASE_NAME}/RELEASE.TXT; \
	echo "Platform: AIX 7.2 (ppc64)" >> target/$${RELEASE_NAME}/RELEASE.TXT; \
	echo "  README created: target/$${RELEASE_NAME}/README.txt"; \
	echo "  RELEASE.TXT created: target/$${RELEASE_NAME}/RELEASE.TXT"; \
	echo ""; \
	echo "Step 7: Copying acceptance test..."; \
	cp release-templates/acceptance-test/RUN_TEST.sh target/$${RELEASE_NAME}/acceptance-test/; \
	cp release-templates/acceptance-test/README.md target/$${RELEASE_NAME}/acceptance-test/; \
	cp release-templates/acceptance-test/fixtures/*.csv target/$${RELEASE_NAME}/acceptance-test/fixtures/; \
	mkdir -p target/$${RELEASE_NAME}/acceptance-test/fixtures/config; \
	cp release-templates/acceptance-test/fixtures/config/product-codes.csv target/$${RELEASE_NAME}/acceptance-test/fixtures/config/; \
	chmod +x target/$${RELEASE_NAME}/acceptance-test/RUN_TEST.sh; \
	echo "  Acceptance test copied: target/$${RELEASE_NAME}/acceptance-test/"; \
	echo "  Test fixtures: $$(ls target/$${RELEASE_NAME}/acceptance-test/fixtures/*.csv | wc -l | tr -d ' ') files"; \
	echo "  Reference data: product-codes.csv"; \
	echo ""; \
	echo "Step 8: Creating release archive..."; \
	cd target && mv $${RELEASE_NAME} iwldr && tar -cf $${RELEASE_NAME}.tar iwldr/ && mv iwldr $${RELEASE_NAME} && gzip -f $${RELEASE_NAME}.tar && cd ..; \
	echo "  Archive created: target/$${RELEASE_NAME}.tar.gz"; \
	echo ""; \
	echo "Step 9: Calculating checksums..."; \
	cd target && sum $${RELEASE_NAME}.tar.gz > $${RELEASE_NAME}.tar.gz.sum && cd ..; \
	echo "  Checksum: target/$${RELEASE_NAME}.tar.gz.sum"; \
	echo ""; \
	echo "========================================================================"; \
	echo "Release Package Complete!"; \
	echo "========================================================================"; \
	echo ""; \
	echo "Package: target/$${RELEASE_NAME}.tar.gz"; \
	ls -lh target/$${RELEASE_NAME}.tar.gz 2>/dev/null | awk '{print "Size: " $$5}' || echo "Size: $$(ls -l target/$${RELEASE_NAME}.tar.gz | awk '{print $$5}') bytes"; \
	echo ""; \
	echo "Contents:"; \
	gunzip -c target/$${RELEASE_NAME}.tar.gz | tar -tf - | head -20; \
	echo ""; \
	echo "To deploy on target AIX system:"; \
	echo "  1. Transfer target/$${RELEASE_NAME}.tar.gz to target system"; \
	echo "  2. Extract: gunzip -c $${RELEASE_NAME}.tar.gz | tar -xf -"; \
	echo "  3. Read: iwldr/DEPLOY_ON_AIX.md"; \
	echo "  4. Run acceptance test: cd iwldr/acceptance-test && ./RUN_TEST.sh"; \
	echo "  5. If tests pass, proceed with production deployment"; \
	echo ""

# Help target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Build Targets:"
	@echo "  all        - Clean, test, and build"
	@echo "  build      - Build the application"
	@echo "  build-production - Build for production (Linux amd64)"
	@echo "  build-static - Build static binary for containers"
	@echo "  build-static-with-tests - Build static binary and run acceptance tests"
	@echo "  build-all  - Build for multiple platforms"
	@echo "  clean      - Clean build artifacts"
	@echo ""
	@echo "Test Targets:"
	@echo "  test       - Run unit tests"
	@echo "  test-verbose - Run unit tests with verbose output"
	@echo "  test-all   - Run all tests (unit + acceptance)"
	@echo "  coverage   - Generate test coverage report"
	@echo ""
	@echo "Acceptance Test Targets:"
	@echo "  acceptance-test-clean  - Clean acceptance test database"
	@echo "  acceptance-test-init   - Initialize acceptance test database"
	@echo "  acceptance-test-load   - Load reference data and import test fixtures"
	@echo "  acceptance-test-verify - Verify acceptance test data"
	@echo "  acceptance-test-full   - Run full acceptance test (clean + init + load + verify)"
	@echo "  acceptance-test        - Run legacy acceptance tests (requires build-static)"
	@echo ""
	@echo "Other Targets:"
	@echo "  lint       - Run linter"
	@echo "  deps       - Download and tidy dependencies"
	@echo "  init-db    - Initialize the database"
	@echo "  install    - Install the application to GOPATH/bin"
	@echo "  run-help   - Build and show application help"
	@echo "  dev        - Development setup (build and init-db)"
	@echo "  build-aix-info - Show information about AIX compilation"
	@echo "  platform-info - Display platform configuration"
	@echo "  release-for-aix - Create AIX release package with bundled dependencies"
	@echo "  aix-release - Alias for release-for-aix"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  make acceptance-test-full  - Run complete acceptance test from scratch"
	@echo ""
	@echo "AIX Build:"
	@echo "  make platform-info         - Show current platform configuration"
	@echo "  make build                 - Build for current platform"
	@echo "  make release-for-aix       - Create deployment package (auto-version)"
	@echo "  make release-for-aix VERSION=25B06_1  - Create deployment package with version"
	@echo ""
	@echo "Release versioning:"
	@echo "  VERSION parameter is optional (defaults to timestamp YYYYMMDD_HHMMSS)"
	@echo "  Version is stored in RELEASE.TXT file, not in archive filename"
	@echo "  Archive name: iwldr-aix72-VERSION.tar.gz"
	@echo "  Extract folder: iwldr/"
