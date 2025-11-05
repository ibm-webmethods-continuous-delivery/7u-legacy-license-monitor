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

// CoreAggregationRow represents a row from v_core_aggregation_by_product
type CoreAggregationRow struct {
	MeasurementDate    time.Time `json:"measurement_date"`
	ProductMnemoCode   string    `json:"product_mnemo_code"`
	ProductName        string    `json:"product_name"`
	Mode               string    `json:"mode"`
	MainFQDN           string    `json:"main_fqdn"`
	Hostname           string    `json:"hostname"`
	VMCores            int       `json:"vm_cores"`
	PartitionCores     int       `json:"partition_cores"`
	ProcessorEligible  string    `json:"processor_eligible"`
	OSEligible         string    `json:"os_eligible"`
	VirtEligible       string    `json:"virt_eligible"`
	LicenseCores       int       `json:"license_cores"`
	PhysicalHostID     string    `json:"physical_host_id"`
	PhysicalHostCores  *int      `json:"physical_host_cores"`
	EligibleCores      int       `json:"eligible_cores"`
	IneligibleCores    int       `json:"ineligible_cores"`
	ProductStatus      string    `json:"product_status"`
	InstallCount       int       `json:"install_count"`
	IsVirtualized      string    `json:"is_virtualized"`
	OSName             string    `json:"os_name"`
	OSVersion          string    `json:"os_version"`
}

// CoreAggregationReport generates reports from v_core_aggregation_by_product view
type CoreAggregationReport struct {
	db *sql.DB
}

// NewCoreAggregationReport creates a new report generator
func NewCoreAggregationReport(db *sql.DB) *CoreAggregationReport {
	return &CoreAggregationReport{db: db}
}

// Query retrieves data from the view with optional filters
func (r *CoreAggregationReport) Query(productCode string, fromDate, toDate *time.Time) ([]CoreAggregationRow, error) {
	query := `
		SELECT 
			measurement_date,
			product_mnemo_code,
			product_name,
			mode,
			main_fqdn,
			hostname,
			vm_cores,
			partition_cores,
			processor_eligible,
			os_eligible,
			virt_eligible,
			license_cores,
			physical_host_id,
			physical_host_cores,
			eligible_cores,
			ineligible_cores,
			product_status,
			install_count,
			is_virtualized,
			os_name,
			os_version
		FROM v_core_aggregation_by_product
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
	
	query += " ORDER BY measurement_date DESC, product_mnemo_code, hostname"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query core aggregation: %w", err)
	}
	defer rows.Close()
	
	var results []CoreAggregationRow
	for rows.Next() {
		var row CoreAggregationRow
		var dateStr string
		var physicalHostCores sql.NullInt64
		
		err := rows.Scan(
			&dateStr,
			&row.ProductMnemoCode,
			&row.ProductName,
			&row.Mode,
			&row.MainFQDN,
			&row.Hostname,
			&row.VMCores,
			&row.PartitionCores,
			&row.ProcessorEligible,
			&row.OSEligible,
			&row.VirtEligible,
			&row.LicenseCores,
			&row.PhysicalHostID,
			&physicalHostCores,
			&row.EligibleCores,
			&row.IneligibleCores,
			&row.ProductStatus,
			&row.InstallCount,
			&row.IsVirtualized,
			&row.OSName,
			&row.OSVersion,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		// Parse date
		row.MeasurementDate, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse date: %w", err)
		}
		
		// Handle NULL physical_host_cores
		if physicalHostCores.Valid {
			cores := int(physicalHostCores.Int64)
			row.PhysicalHostCores = &cores
		}
		
		results = append(results, row)
	}
	
	return results, rows.Err()
}

// WriteTable writes data in ASCII table format
func (r *CoreAggregationReport) WriteTable(w io.Writer, rows []CoreAggregationRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "DATE\tPRODUCT\tHOSTNAME\tVM_CORES\tLIC_CORES\tELIG\tINELIG\tPHYS_ID\tSTATUS")
	fmt.Fprintln(tw, strings.Repeat("-", 120))
	
	// Data rows
	for _, row := range rows {
		physCores := "N/A"
		if row.PhysicalHostCores != nil {
			physCores = fmt.Sprintf("%d", *row.PhysicalHostCores)
		}
		
		fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s (phys: %s)\t%s\n",
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductMnemoCode,
			row.Hostname,
			row.VMCores,
			row.LicenseCores,
			row.EligibleCores,
			row.IneligibleCores,
			row.PhysicalHostID,
			physCores,
			row.ProductStatus,
		)
	}
	
	// Summary
	if len(rows) > 0 {
		totalVM := 0
		totalLic := 0
		totalElig := 0
		totalInelig := 0
		for _, row := range rows {
			totalVM += row.VMCores
			totalLic += row.LicenseCores
			totalElig += row.EligibleCores
			totalInelig += row.IneligibleCores
		}
		
		fmt.Fprintln(tw, strings.Repeat("-", 120))
		fmt.Fprintf(tw, "TOTAL\t\t\t%d\t%d\t%d\t%d\t\t\n", totalVM, totalLic, totalElig, totalInelig)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *CoreAggregationReport) WriteCSV(w io.Writer, rows []CoreAggregationRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"measurement_date",
		"product_mnemo_code",
		"product_name",
		"mode",
		"main_fqdn",
		"hostname",
		"vm_cores",
		"partition_cores",
		"processor_eligible",
		"os_eligible",
		"virt_eligible",
		"license_cores",
		"physical_host_id",
		"physical_host_cores",
		"eligible_cores",
		"ineligible_cores",
		"product_status",
		"install_count",
		"is_virtualized",
		"os_name",
		"os_version",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		physCores := ""
		if row.PhysicalHostCores != nil {
			physCores = fmt.Sprintf("%d", *row.PhysicalHostCores)
		}
		
		err := writer.Write([]string{
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductMnemoCode,
			row.ProductName,
			row.Mode,
			row.MainFQDN,
			row.Hostname,
			fmt.Sprintf("%d", row.VMCores),
			fmt.Sprintf("%d", row.PartitionCores),
			row.ProcessorEligible,
			row.OSEligible,
			row.VirtEligible,
			fmt.Sprintf("%d", row.LicenseCores),
			row.PhysicalHostID,
			physCores,
			fmt.Sprintf("%d", row.EligibleCores),
			fmt.Sprintf("%d", row.IneligibleCores),
			row.ProductStatus,
			fmt.Sprintf("%d", row.InstallCount),
			row.IsVirtualized,
			row.OSName,
			row.OSVersion,
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *CoreAggregationReport) WriteJSON(w io.Writer, rows []CoreAggregationRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
