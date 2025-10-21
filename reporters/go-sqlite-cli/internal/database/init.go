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

package database

import (
	"database/sql"
	"fmt"
)

// InitSchema creates all tables, indexes, and views
func InitSchema(db *sql.DB) error {
	// Execute schema DDL
	_, err := db.Exec(SchemaSQL)
	if err != nil {
		return fmt.Errorf("failed to execute schema: %w", err)
	}

	// Create reporting views
	_, err = db.Exec(ViewsSQL)
	if err != nil {
		return fmt.Errorf("failed to create views: %w", err)
	}

	// Set schema version
	err = SetSchemaVersion(db, GetSchemaVersion())
	if err != nil {
		return fmt.Errorf("failed to set schema version: %w", err)
	}

	return nil
}

// VerifySchema checks that all required tables exist
func VerifySchema(db *sql.DB) error {
	requiredTables := []string{
		"schema_metadata",
		"license_terms",
		"product_codes",
		"landscape_nodes",
		"physical_hosts",
		"measurements",
		"detected_products",
		"import_sessions",
	}

	for _, table := range requiredTables {
		var count int
		query := `SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?`
		err := db.QueryRow(query, table).Scan(&count)
		if err != nil {
			return fmt.Errorf("failed to check table %s: %w", table, err)
		}
		if count == 0 {
			return fmt.Errorf("required table %s does not exist", table)
		}
	}

	return nil
}
