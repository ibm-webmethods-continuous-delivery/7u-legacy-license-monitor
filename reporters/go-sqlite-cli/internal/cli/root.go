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

package cli

import (
	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/cli/commands"
	"github.com/spf13/cobra"
)

var (
	dbFile string
)

var rootCmd = &cobra.Command{
	Use:   "go-sqlite-cli",
	Short: "License monitor database management tool",
	Long: `A CLI tool for managing webMethods license monitoring database.
Supports database initialization, CSV import, and compliance reporting.

The tool provides commands for:
- Initializing a new database with complete schema
- Importing inspector CSV files
- Generating license compliance reports
- Querying measurement data`,
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&dbFile, "database", "d", "data/default.db", "SQLite database file path")

	// Register commands
	rootCmd.AddCommand(commands.NewInitCmd())
	rootCmd.AddCommand(commands.NewImportCmd())
	rootCmd.AddCommand(commands.NewReportCmd())
}

// Execute runs the root command
func Execute() error {
	return rootCmd.Execute()
}

// GetDBFile returns the configured database file path
func GetDBFile() string {
	if dbFile == "" {
		return "data/default.db"
	}
	return dbFile
}
