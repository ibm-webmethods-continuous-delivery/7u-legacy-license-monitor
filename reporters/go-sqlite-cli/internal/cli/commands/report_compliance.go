package commands

import (
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/database"
	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/reports"
)

var reportComplianceCmd = &cobra.Command{
	Use:   "compliance",
	Short: "Generate license compliance report",
	Long:  "Shows license compliance status with gap analysis",
	RunE:  runReportCompliance,
}

func init() {
	reportCmd.AddCommand(reportComplianceCmd)
	reportComplianceCmd.Flags().BoolVar(&reportNonCompliant, "non-compliant-only", false, "Show only non-compliant products")
}

func runReportCompliance(cmd *cobra.Command, args []string) error {
	// Parse date filters
	var fromDate, toDate *time.Time
	var err error
	
	if reportFromDate != "" {
		t, err := time.Parse("2006-01-02", reportFromDate)
		if err != nil {
			return fmt.Errorf("invalid from date format: %w", err)
		}
		fromDate = &t
	}
	
	if reportToDate != "" {
		t, err := time.Parse("2006-01-02", reportToDate)
		if err != nil {
			return fmt.Errorf("invalid to date format: %w", err)
		}
		toDate = &t
	}
	
	// Open database
	db, err := database.Connect(reportDBPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()
	
	// Create report generator
	report := reports.NewComplianceReport(db)
	
	// Query data
	rows, err := report.Query(reportProduct, fromDate, toDate, reportNonCompliant)
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
