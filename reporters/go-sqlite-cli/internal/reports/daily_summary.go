package reports

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"
	"time"
)

// DailySummaryRow represents a row from v_daily_product_summary
type DailySummaryRow struct {
	MeasurementDate                 time.Time `json:"measurement_date"`
	ProductCode                     string    `json:"product_code"`
	ProductName                     string    `json:"product_name"`
	Mode                            string    `json:"mode"`
	TermID                          string    `json:"term_id"`
	ProgramNumber                   string    `json:"program_number"`
	ProgramName                     string    `json:"program_name"`
	// Running products
	RunningNodeCount                int       `json:"running_node_count"`
	RunningVCores                   int       `json:"running_vcores"`
	RunningPhysicalCoresDirect      int       `json:"running_physical_cores_direct"`
	RunningUniquePhysHosts          int       `json:"running_unique_phys_hosts"`
	RunningPhysicalCoresFromHosts   int       `json:"running_physical_cores_from_hosts"`
	// Installed products
	TotalInstalls                   int       `json:"total_installs"`
	InstalledNodeCount              int       `json:"installed_node_count"`
	InstalledVCores                 int       `json:"installed_vcores"`
	InstalledPhysicalCoresDirect    int       `json:"installed_physical_cores_direct"`
	InstalledUniquePhysHosts        int       `json:"installed_unique_phys_hosts"`
	InstalledPhysicalCoresFromHosts int       `json:"installed_physical_cores_from_hosts"`
}

// DailySummaryReport generates reports from v_daily_product_summary view
type DailySummaryReport struct {
	db *sql.DB
}

// NewDailySummaryReport creates a new report generator
func NewDailySummaryReport(db *sql.DB) *DailySummaryReport {
	return &DailySummaryReport{db: db}
}

// Query retrieves data from the view with optional filters
func (r *DailySummaryReport) Query(productCode string, fromDate, toDate *time.Time) ([]DailySummaryRow, error) {
	query := `
		SELECT 
			measurement_date,
			product_mnemo_code,
			product_name,
			mode,
			term_id,
			program_number,
			program_name,
			running_node_count,
			running_vcores,
			running_physical_cores_direct,
			running_unique_phys_hosts,
			running_physical_cores_from_hosts,
			total_installs,
			installed_node_count,
			installed_vcores,
			installed_physical_cores_direct,
			installed_unique_phys_hosts,
			installed_physical_cores_from_hosts
		FROM v_daily_product_summary
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	if productCode != "" {
		query += " AND product_mnemo_code = ?"
		args = append(args, productCode)
	}
	
	if fromDate != nil {
		query += " AND measurement_date >= ?"
		args = append(args, fromDate.Format("2006-01-02"))
	}
	
	if toDate != nil {
		query += " AND measurement_date <= ?"
		args = append(args, toDate.Format("2006-01-02"))
	}
	
	query += " ORDER BY measurement_date DESC, product_mnemo_code"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query daily summary: %w", err)
	}
	defer rows.Close()
	
	var results []DailySummaryRow
	for rows.Next() {
		var row DailySummaryRow
		var dateStr string
		
		err := rows.Scan(
			&dateStr,
			&row.ProductCode,
			&row.ProductName,
			&row.Mode,
			&row.TermID,
			&row.ProgramNumber,
			&row.ProgramName,
			&row.RunningNodeCount,
			&row.RunningVCores,
			&row.RunningPhysicalCoresDirect,
			&row.RunningUniquePhysHosts,
			&row.RunningPhysicalCoresFromHosts,
			&row.TotalInstalls,
			&row.InstalledNodeCount,
			&row.InstalledVCores,
			&row.InstalledPhysicalCoresDirect,
			&row.InstalledUniquePhysHosts,
			&row.InstalledPhysicalCoresFromHosts,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		// Parse date
		row.MeasurementDate, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse date: %w", err)
		}
		
		results = append(results, row)
	}
	
	return results, rows.Err()
}

// WriteTable writes data in ASCII table format
func (r *DailySummaryReport) WriteTable(w io.Writer, rows []DailySummaryRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "Daily Product Summary Report")
	fmt.Fprintln(tw, strings.Repeat("=", 160))
	fmt.Fprintln(tw, "")
	
	currentDate := ""
	for _, row := range rows {
		dateStr := row.MeasurementDate.Format("2006-01-02")
		
		// Print date header if changed
		if dateStr != currentDate {
			if currentDate != "" {
				fmt.Fprintln(tw, "")
			}
			fmt.Fprintf(tw, "DATE: %s\n", dateStr)
			fmt.Fprintln(tw, strings.Repeat("-", 160))
			currentDate = dateStr
		}
		
		// Product header
		fmt.Fprintf(tw, "\nProduct:\t%s (%s) - %s\n", row.ProductName, row.ProductCode, row.Mode)
		fmt.Fprintf(tw, "License:\t%s - %s (%s)\n", row.ProgramName, row.ProgramNumber, row.TermID)
		
		// Running products section
		if row.RunningNodeCount > 0 || row.RunningVCores > 0 || row.RunningPhysicalCoresFromHosts > 0 {
			fmt.Fprintln(tw, "")
			fmt.Fprintln(tw, "RUNNING:")
			fmt.Fprintf(tw, "  Nodes:\t\t%d\n", row.RunningNodeCount)
			fmt.Fprintf(tw, "  Virtual Cores:\t%d\n", row.RunningVCores)
			fmt.Fprintf(tw, "  Physical Cores (direct):\t%d\n", row.RunningPhysicalCoresDirect)
			fmt.Fprintf(tw, "  Physical Hosts:\t%d\n", row.RunningUniquePhysHosts)
			fmt.Fprintf(tw, "  Physical Cores (deduplicated):\t%d\n", row.RunningPhysicalCoresFromHosts)
		}
		
		// Installed products section
		if row.TotalInstalls > 0 || row.InstalledNodeCount > 0 {
			fmt.Fprintln(tw, "")
			fmt.Fprintln(tw, "INSTALLED:")
			fmt.Fprintf(tw, "  Total Installations:\t%d\n", row.TotalInstalls)
			fmt.Fprintf(tw, "  Nodes:\t\t%d\n", row.InstalledNodeCount)
			fmt.Fprintf(tw, "  Virtual Cores:\t%d\n", row.InstalledVCores)
			fmt.Fprintf(tw, "  Physical Cores (direct):\t%d\n", row.InstalledPhysicalCoresDirect)
			fmt.Fprintf(tw, "  Physical Hosts:\t%d\n", row.InstalledUniquePhysHosts)
			fmt.Fprintf(tw, "  Physical Cores (deduplicated):\t%d\n", row.InstalledPhysicalCoresFromHosts)
		}
	}
	
	fmt.Fprintln(tw, "")
	fmt.Fprintln(tw, strings.Repeat("=", 160))
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *DailySummaryReport) WriteCSV(w io.Writer, rows []DailySummaryRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"measurement_date",
		"product_code",
		"product_name",
		"mode",
		"term_id",
		"program_number",
		"program_name",
		"running_node_count",
		"running_vcores",
		"running_physical_cores_direct",
		"running_unique_phys_hosts",
		"running_physical_cores_from_hosts",
		"total_installs",
		"installed_node_count",
		"installed_vcores",
		"installed_physical_cores_direct",
		"installed_unique_phys_hosts",
		"installed_physical_cores_from_hosts",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductCode,
			row.ProductName,
			row.Mode,
			row.TermID,
			row.ProgramNumber,
			row.ProgramName,
			fmt.Sprintf("%d", row.RunningNodeCount),
			fmt.Sprintf("%d", row.RunningVCores),
			fmt.Sprintf("%d", row.RunningPhysicalCoresDirect),
			fmt.Sprintf("%d", row.RunningUniquePhysHosts),
			fmt.Sprintf("%d", row.RunningPhysicalCoresFromHosts),
			fmt.Sprintf("%d", row.TotalInstalls),
			fmt.Sprintf("%d", row.InstalledNodeCount),
			fmt.Sprintf("%d", row.InstalledVCores),
			fmt.Sprintf("%d", row.InstalledPhysicalCoresDirect),
			fmt.Sprintf("%d", row.InstalledUniquePhysHosts),
			fmt.Sprintf("%d", row.InstalledPhysicalCoresFromHosts),
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *DailySummaryReport) WriteJSON(w io.Writer, rows []DailySummaryRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
