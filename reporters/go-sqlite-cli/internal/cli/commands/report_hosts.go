package commands

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/database"
	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/reports"
)

var reportHostsCmd = &cobra.Command{
	Use:   "hosts",
	Short: "Generate physical host cores report",
	Long:  "Shows core counts by physical host (prevents VM double-counting)",
	RunE:  runReportHosts,
}

func init() {
	reportCmd.AddCommand(reportHostsCmd)
	reportHostsCmd.Flags().StringVar(&reportSystemType, "system-type", "", "Filter by system type")
}

func runReportHosts(cmd *cobra.Command, args []string) error {
	// Open database
	db, err := database.Connect(reportDBPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()
	
	// Create report generator
	report := reports.NewPhysicalHostReport(db)
	
	// Query data
	rows, err := report.Query(reportSystemType)
	if err != nil {
		return fmt.Errorf("failed to query data: %w", err)
	}
	
	if len(rows) == 0 {
		fmt.Println("No data found matching the criteria")
		return nil
	}
	
	// Determine output writer
	var writer *os.File
	if reportOutput != "" {
		writer, err = os.Create(reportOutput)
		if err != nil {
			return fmt.Errorf("failed to create output file: %w", err)
		}
		defer writer.Close()
	} else {
		writer = os.Stdout
	}
	
	// Write output in requested format
	switch reportFormat {
	case "table":
		err = report.WriteTable(writer, rows)
	case "csv":
		err = report.WriteCSV(writer, rows)
	case "json":
		err = report.WriteJSON(writer, rows)
	default:
		return fmt.Errorf("unknown format: %s (use table, csv, or json)", reportFormat)
	}
	
	if err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}
	
	if reportOutput != "" {
		fmt.Printf("Report written to %s\n", reportOutput)
	}
	
	return nil
}
