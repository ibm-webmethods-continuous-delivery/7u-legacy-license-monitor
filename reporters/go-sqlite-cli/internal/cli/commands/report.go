package commands

import (
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/database"
	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/reports"
)

// NewReportCmd creates the report command
func NewReportCmd() *cobra.Command {
	return reportCmd
}

var reportCmd = &cobra.Command{
	Use:   "report",
	Short: "Generate license compliance reports",
	Long:  "Generate various license compliance reports from the database",
}

var reportCoresCmd = &cobra.Command{
	Use:   "cores",
	Short: "Generate core aggregation report by product",
	Long:  "Shows core counts aggregated by product with eligibility breakdown",
	RunE:  runReportCores,
}

var (
	reportDBPath       string
	reportFormat       string
	reportOutput       string
	reportProduct      string
	reportFromDate     string
	reportToDate       string
	reportSystemType   string
	reportNonCompliant bool
)

func init() {
	// Add subcommands to report
	reportCmd.AddCommand(reportCoresCmd)
	
	// Global report flags
	reportCmd.PersistentFlags().StringVar(&reportDBPath, "db-path", "data/license-monitor.db", "Path to the SQLite database file")
	reportCmd.PersistentFlags().StringVarP(&reportFormat, "format", "f", "table", "Output format: table, csv, json")
	reportCmd.PersistentFlags().StringVarP(&reportOutput, "output", "o", "", "Output file (default: stdout)")
	reportCmd.PersistentFlags().StringVar(&reportProduct, "product", "", "Filter by product code")
	reportCmd.PersistentFlags().StringVar(&reportFromDate, "from", "", "Filter from date (YYYY-MM-DD)")
	reportCmd.PersistentFlags().StringVar(&reportToDate, "to", "", "Filter to date (YYYY-MM-DD)")
}

func runReportCores(cmd *cobra.Command, args []string) error {
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
	report := reports.NewCoreAggregationReport(db)
	
	// Query data
	rows, err := report.Query(reportProduct, fromDate, toDate)
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
