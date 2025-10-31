# Build variables
BINARY_NAME=seed-go-sqlite-api
BUILD_DIR=target/bin
CMD_DIR=cmd/seed-go-sqlite-api
DATA_DIR=data
ACCEPTANCE_TEST_DIR=acceptance-test
ACCEPTANCE_DB=$(ACCEPTANCE_TEST_DIR)/acceptance-test.db
REFERENCE_DATA_DIR=../../inspectors/default/detection-config
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

.PHONY: all build clean test test-verbose coverage lint init-db build-production build-static build-all build-aix-info acceptance-test test-all help acceptance-test-clean acceptance-test-init acceptance-test-load acceptance-test-verify acceptance-test-full

# Default target
all: clean test build

# Build the application
build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./$(CMD_DIR)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Build for production (Linux amd64)
build-production:
	@echo "Building for production (Linux amd64)..."
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 ./$(CMD_DIR)
	@echo "Production build complete: $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64"

# Build static binary for containers (FROM scratch)
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
		--reference-dir $(REFERENCE_DATA_DIR) \
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
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  make acceptance-test-full  - Run complete acceptance test from scratch"
