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

// GetCurrentSchemaVersion retrieves version from database
func GetCurrentSchemaVersion(db *sql.DB) (string, error) {
	var version string
	query := `SELECT value FROM schema_metadata WHERE key = 'schema_version'`
	err := db.QueryRow(query).Scan(&version)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("failed to get schema version: %w", err)
	}
	return version, nil
}

// SetSchemaVersion updates version in database
func SetSchemaVersion(db *sql.DB, version string) error {
	query := `INSERT OR REPLACE INTO schema_metadata (key, value) 
              VALUES ('schema_version', ?)`
	_, err := db.Exec(query, version)
	if err != nil {
		return fmt.Errorf("failed to set schema version: %w", err)
	}
	return nil
}
