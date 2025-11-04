// Copyright 2025 Mihai Ungureanu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package database_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/ibm-webmethods-aftermarket-tools/iwldr/internal/database"
)

func TestConnect(t *testing.T) {
	// Create temp directory
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Test connection
	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	// Verify file exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		t.Error("Database file was not created")
	}

	// Verify foreign keys are enabled
	var fkEnabled int
	err = db.QueryRow("PRAGMA foreign_keys").Scan(&fkEnabled)
	if err != nil {
		t.Fatalf("Failed to check foreign keys: %v", err)
	}
	if fkEnabled != 1 {
		t.Error("Foreign keys are not enabled")
	}
}

func TestInitSchema(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	// Initialize schema
	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Verify schema
	err = database.VerifySchema(db)
	if err != nil {
		t.Errorf("Schema verification failed: %v", err)
	}
}

func TestVerifySchemaAllTables(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Check that all expected tables exist
	expectedTables := []string{
		"schema_metadata",
		"license_terms",
		"product_codes",
		"landscape_nodes",
		"physical_hosts",
		"measurements",
		"detected_products",
		"import_sessions",
	}

	for _, table := range expectedTables {
		var count int
		query := `SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?`
		err := db.QueryRow(query, table).Scan(&count)
		if err != nil {
			t.Errorf("Failed to check table %s: %v", table, err)
		}
		if count == 0 {
			t.Errorf("Table %s does not exist", table)
		}
	}
}

func TestForeignKeyEnforcement(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Try to insert product_code with invalid term_id
	_, err = db.Exec(`
		INSERT INTO product_codes 
		(product_mnemo_code, ibm_product_code, product_name, mode, term_id) 
		VALUES ('TEST', 'TEST123', 'Test Product', 'PROD', 'INVALID_TERM')
	`)

	if err == nil {
		t.Error("Expected foreign key constraint violation, but insert succeeded")
	}
}

func TestSchemaVersion(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Get version
	version, err := database.GetCurrentSchemaVersion(db)
	if err != nil {
		t.Fatalf("Failed to get version: %v", err)
	}

	expectedVersion := database.GetSchemaVersion()
	if version != expectedVersion {
		t.Errorf("Expected version %s, got %s", expectedVersion, version)
	}
}

func TestCheckConstraints(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// First insert a license term
	_, err = db.Exec(`
		INSERT INTO license_terms (term_id, program_number, program_name)
		VALUES ('TEST-TERM', 'TEST-001', 'Test Program')
	`)
	if err != nil {
		t.Fatalf("Failed to insert license term: %v", err)
	}

	// Test invalid mode in product_codes
	_, err = db.Exec(`
		INSERT INTO product_codes 
		(product_mnemo_code, ibm_product_code, product_name, mode, term_id)
		VALUES ('TEST', 'TEST123', 'Test Product', 'INVALID', 'TEST-TERM')
	`)

	if err == nil {
		t.Error("Expected check constraint violation for invalid mode")
	}

	// Test valid PROD mode
	_, err = db.Exec(`
		INSERT INTO product_codes 
		(product_mnemo_code, ibm_product_code, product_name, mode, term_id)
		VALUES ('TEST_PROD', 'TEST123', 'Test Product', 'PROD', 'TEST-TERM')
	`)

	if err != nil {
		t.Errorf("Valid PROD mode insert failed: %v", err)
	}

	// Test valid NON PROD mode
	_, err = db.Exec(`
		INSERT INTO product_codes 
		(product_mnemo_code, ibm_product_code, product_name, mode, term_id)
		VALUES ('TEST_NONPROD', 'TEST123', 'Test Product', 'NON PROD', 'TEST-TERM')
	`)

	if err != nil {
		t.Errorf("Valid NON PROD mode insert failed: %v", err)
	}
}

func TestPhysicalHostConfidenceConstraint(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Test invalid confidence level
	_, err = db.Exec(`
		INSERT INTO physical_hosts 
		(physical_host_id, host_id_method, host_id_confidence, first_seen, last_seen)
		VALUES ('HOST1', 'test', 'invalid', datetime('now'), datetime('now'))
	`)

	if err == nil {
		t.Error("Expected check constraint violation for invalid confidence level")
	}

	// Test valid confidence levels
	validLevels := []string{"high", "medium", "low"}
	for _, level := range validLevels {
		_, err = db.Exec(`
			INSERT INTO physical_hosts 
			(physical_host_id, host_id_method, host_id_confidence, first_seen, last_seen)
			VALUES (?, 'test', ?, datetime('now'), datetime('now'))
		`, "HOST_"+level, level)

		if err != nil {
			t.Errorf("Valid confidence level '%s' insert failed: %v", level, err)
		}
	}
}

func TestIndexesCreated(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Check that indexes were created
	expectedIndexes := []string{
		"idx_measurements_timestamp",
		"idx_measurements_fqdn",
		"idx_measurements_physical_host",
		"idx_detected_products_timestamp",
		"idx_detected_products_status",
		"idx_product_codes_term",
		"idx_import_sessions_hostname",
		"idx_import_sessions_timestamp",
	}

	for _, index := range expectedIndexes {
		var count int
		query := `SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?`
		err := db.QueryRow(query, index).Scan(&count)
		if err != nil {
			t.Errorf("Failed to check index %s: %v", index, err)
		}
		if count == 0 {
			t.Errorf("Index %s does not exist", index)
		}
	}
}

func TestLatestMeasurementsView(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := database.Connect(dbPath)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer db.Close()

	err = database.InitSchema(db)
	if err != nil {
		t.Fatalf("Failed to init schema: %v", err)
	}

	// Check that the view exists
	var count int
	query := `SELECT COUNT(*) FROM sqlite_master WHERE type='view' AND name='v_latest_measurements'`
	err = db.QueryRow(query).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to check view: %v", err)
	}
	if count == 0 {
		t.Error("View v_latest_measurements does not exist")
	}

	// Test that we can query the view (should be empty initially)
	_, err = db.Query("SELECT * FROM v_latest_measurements")
	if err != nil {
		t.Errorf("Failed to query v_latest_measurements: %v", err)
	}
}
