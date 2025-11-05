package reports

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"text/tabwriter"
)

// PeakBreakdownRow represents a row from v_peak_usage_breakdown
type PeakBreakdownRow struct {
	MeasurementDate      string `json:"measurement_date"`
	ProductMnemoCode     string `json:"product_mnemo_code"`
	IBMProductCode       string `json:"ibm_product_code"`
	ProductName          string `json:"product_name"`
	Mode                 string `json:"mode"`
	MainFQDN             string `json:"main_fqdn"`
	Hostname             string `json:"hostname"`
	VMCores              int    `json:"vm_cores"`
	LicenseCores         int    `json:"license_cores"`
	PhysicalHostID       string `json:"physical_host_id"`
	PhysicalHostCores    sql.NullInt64 `json:"physical_host_cores"`
	EligibleCores        int    `json:"eligible_cores"`
	IneligibleCores      int    `json:"ineligible_cores"`
	ProcessorEligible    string `json:"processor_eligible"`
	OSEligible           string `json:"os_eligible"`
	VirtEligible         string `json:"virt_eligible"`
	ProductStatus        string `json:"product_status"`
	InstallCount         int    `json:"install_count"`
	InstanceCount        int    `json:"instance_count"`
	OSName               string `json:"os_name"`
	OSVersion            string `json:"os_version"`
	IsVirtualized        string `json:"is_virtualized"`
	DailyRunningTotal    int    `json:"daily_running_total"`
	DailyRunningNodes    int    `json:"daily_running_nodes"`
	DeduplicatedCores    int    `json:"deduplicated_cores"`
}

// PeakBreakdownReport generates detailed breakdown reports
type PeakBreakdownReport struct {
	db *sql.DB
}

// NewPeakBreakdownReport creates a new report generator
func NewPeakBreakdownReport(db *sql.DB) *PeakBreakdownReport {
	return &PeakBreakdownReport{db: db}
}

// Query retrieves breakdown data for a specific product
func (r *PeakBreakdownReport) Query(productCode string, fromDate, toDate string) ([]PeakBreakdownRow, error) {
	query := `
		SELECT 
			measurement_date,
			product_mnemo_code,
			ibm_product_code,
			product_name,
			mode,
			main_fqdn,
			hostname,
			vm_cores,
			license_cores,
			physical_host_id,
			physical_host_cores,
			eligible_cores,
			ineligible_cores,
			processor_eligible,
			os_eligible,
			virt_eligible,
			product_status,
			install_count,
			instance_count,
			os_name,
			os_version,
			is_virtualized,
			daily_running_total,
			daily_running_nodes,
			deduplicated_cores
		FROM v_peak_usage_breakdown
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	if productCode != "" {
		query += " AND product_mnemo_code = ?"
		args = append(args, productCode)
	}
	
	if fromDate != "" {
		query += " AND measurement_date >= ?"
		args = append(args, fromDate)
	}
	
	if toDate != "" {
		query += " AND measurement_date <= ?"
		args = append(args, toDate)
	}
	
	// Only show running instances by default
	query += " AND product_status = 'present'"
	query += " ORDER BY measurement_date DESC, daily_running_total DESC, license_cores DESC"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query peak breakdown: %w", err)
	}
	defer rows.Close()
	
	var results []PeakBreakdownRow
	for rows.Next() {
		var row PeakBreakdownRow
		
		err := rows.Scan(
			&row.MeasurementDate,
			&row.ProductMnemoCode,
			&row.IBMProductCode,
			&row.ProductName,
			&row.Mode,
			&row.MainFQDN,
			&row.Hostname,
			&row.VMCores,
			&row.LicenseCores,
			&row.PhysicalHostID,
			&row.PhysicalHostCores,
			&row.EligibleCores,
			&row.IneligibleCores,
			&row.ProcessorEligible,
			&row.OSEligible,
			&row.VirtEligible,
			&row.ProductStatus,
			&row.InstallCount,
			&row.InstanceCount,
			&row.OSName,
			&row.OSVersion,
			&row.IsVirtualized,
			&row.DailyRunningTotal,
			&row.DailyRunningNodes,
			&row.DeduplicatedCores,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		results = append(results, row)
	}
	
	return results, rows.Err()
}

// WriteTable writes data in ASCII table format
func (r *PeakBreakdownReport) WriteTable(w io.Writer, rows []PeakBreakdownRow) error {
	if len(rows) == 0 {
		return nil
	}
	
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Print summary header
	firstRow := rows[0]
	fmt.Fprintf(w, "Peak Usage Breakdown for %s (%s)\n", firstRow.ProductMnemoCode, firstRow.ProductName)
	fmt.Fprintf(w, "Mode: %s | IBM Code: %s\n", firstRow.Mode, firstRow.IBMProductCode)
	fmt.Fprintln(w, "=====================================================================================================")
	fmt.Fprintln(w, "")
	
	// Group by date
	currentDate := ""
	for _, row := range rows {
		if row.MeasurementDate != currentDate {
			if currentDate != "" {
				fmt.Fprintln(tw, "")
			}
			currentDate = row.MeasurementDate
			
			fmt.Fprintf(w, "DATE: %s | TOTAL CORES: %d | NODES: %d\n", 
				currentDate, row.DailyRunningTotal, row.DailyRunningNodes)
			fmt.Fprintln(w, "-----------------------------------------------------------------------------------------------------")
			
			// Column headers
			fmt.Fprintln(tw, "HOST\tHOSTNAME\tINST\tVM_CORES\tLIC_CORES\tELIG\tINELIG\tPHYS_HOST\tPHYS_CORES\tOS")
			fmt.Fprintln(tw, "----\t--------\t----\t--------\t---------\t----\t------\t---------\t----------\t--")
		}
		
		physCores := "N/A"
		if row.PhysicalHostCores.Valid {
			physCores = fmt.Sprintf("%d", row.PhysicalHostCores.Int64)
		}
		
		// Format license cores with deduplicated cores in parentheses if applicable
		licCoresDisplay := fmt.Sprintf("%d", row.LicenseCores)
		if row.DeduplicatedCores > 0 {
			licCoresDisplay = fmt.Sprintf("(%d)", row.LicenseCores)
		}
		
		fmt.Fprintf(tw, "%s\t%s\t%d\t%d\t%s\t%d\t%d\t%s\t%s\t%s %s\n",
			row.MainFQDN,
			row.Hostname,
			row.InstanceCount,
			row.VMCores,
			licCoresDisplay,
			row.EligibleCores,
			row.IneligibleCores,
			row.PhysicalHostID,
			physCores,
			row.OSName,
			row.OSVersion,
		)
	}
	
	fmt.Fprintln(w, "")
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *PeakBreakdownReport) WriteCSV(w io.Writer, rows []PeakBreakdownRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"measurement_date",
		"product_mnemo_code",
		"ibm_product_code",
		"product_name",
		"mode",
		"main_fqdn",
		"hostname",
		"vm_cores",
		"license_cores",
		"physical_host_id",
		"physical_host_cores",
		"eligible_cores",
		"ineligible_cores",
		"processor_eligible",
		"os_eligible",
		"virt_eligible",
		"product_status",
		"install_count",
		"instance_count",
		"os_name",
		"os_version",
		"is_virtualized",
		"daily_running_total",
		"daily_running_nodes",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		physCores := ""
		if row.PhysicalHostCores.Valid {
			physCores = fmt.Sprintf("%d", row.PhysicalHostCores.Int64)
		}
		
		err := writer.Write([]string{
			row.MeasurementDate,
			row.ProductMnemoCode,
			row.IBMProductCode,
			row.ProductName,
			row.Mode,
			row.MainFQDN,
			row.Hostname,
			fmt.Sprintf("%d", row.VMCores),
			fmt.Sprintf("%d", row.LicenseCores),
			row.PhysicalHostID,
			physCores,
			fmt.Sprintf("%d", row.EligibleCores),
			fmt.Sprintf("%d", row.IneligibleCores),
			row.ProcessorEligible,
			row.OSEligible,
			row.VirtEligible,
			row.ProductStatus,
			fmt.Sprintf("%d", row.InstallCount),
			fmt.Sprintf("%d", row.InstanceCount),
			row.OSName,
			row.OSVersion,
			row.IsVirtualized,
			fmt.Sprintf("%d", row.DailyRunningTotal),
			fmt.Sprintf("%d", row.DailyRunningNodes),
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *PeakBreakdownReport) WriteJSON(w io.Writer, rows []PeakBreakdownRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
