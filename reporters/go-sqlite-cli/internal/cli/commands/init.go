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

package commands

import (
	"fmt"
	"os"

	"github.com/ibm-webmethods-aftermarket-tools/iwldr/internal/database"
	"github.com/spf13/cobra"
)

var (
	dbPath string
)

// NewInitCmd creates the init command
func NewInitCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize a new license monitor database",
		Long: `Creates a new SQLite database with the complete schema for
license monitoring including tables for measurements, products, physical hosts,
and import tracking.

The database schema includes:
- license_terms: IBM license terms and programs
- product_codes: Product mappings to license terms
- landscape_nodes: Nodes in the landscape
- physical_hosts: Physical hosts for VM aggregation
- measurements: System inspection results
- detected_products: Product detection results
- import_sessions: Import audit trail

Example:
  iwdlr init --db-path ./data/license-monitor.db`,
		RunE: runInit,
	}

	cmd.Flags().StringVar(&dbPath, "db-path", "data/license-monitor.db",
		"Path to the SQLite database file")

	return cmd
}

func runInit(cmd *cobra.Command, args []string) error {
	// Check if database already exists
	if _, err := os.Stat(dbPath); err == nil {
		return fmt.Errorf("database already exists at %s\nUse a different path or delete the existing file", dbPath)
	}

	fmt.Printf("Initializing database at: %s\n", dbPath)

	// Connect to database (will create file)
	db, err := database.Connect(dbPath)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer db.Close()

	// Initialize schema
	fmt.Println("Creating database schema...")
	if err := database.InitSchema(db); err != nil {
		// Clean up on failure
		os.Remove(dbPath)
		return fmt.Errorf("failed to initialize schema: %w", err)
	}

	// Verify schema
	fmt.Println("Verifying schema...")
	if err := database.VerifySchema(db); err != nil {
		os.Remove(dbPath)
		return fmt.Errorf("schema verification failed: %w", err)
	}

	// Get and display version
	version, err := database.GetCurrentSchemaVersion(db)
	if err != nil {
		return fmt.Errorf("failed to get schema version: %w", err)
	}

	fmt.Printf("\nSuccess! Database initialized.\n")
	fmt.Printf("  Location: %s\n", dbPath)
	fmt.Printf("  Schema version: %s\n", version)
	fmt.Println("\nDatabase ready for import operations.")
	fmt.Println("\nNext steps:")
	fmt.Println("  1. Import inspector CSV files: iwdlr import --file <csv-file>")
	fmt.Println("  2. Generate reports: iwdlr report --help")

	return nil
}
