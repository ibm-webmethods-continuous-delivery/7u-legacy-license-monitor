package reports

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"text/tabwriter"
	"time"
)

// ComplianceRow represents a row from v_license_compliance_report
type ComplianceRow struct {
	MeasurementDate        time.Time `json:"measurement_date"`
	ProductMnemoCode       string    `json:"product_mnemo_code"`
	ProductName            string    `json:"product_name"`
	Mode                   string    `json:"mode"`
	TermID                 string    `json:"term_id"`
	ProgramNumber          string    `json:"program_number"`
	ProgramName            string    `json:"program_name"`
	TotalNodes             int       `json:"total_nodes"`
	RunningNodes           int       `json:"running_nodes"`
	TotalInstallations     int       `json:"total_installations"`
	TotalVMCores           int       `json:"total_vm_cores"`
	TotalLicenseCoresRaw   int       `json:"total_license_cores_raw"`
	EligibleCoresSum       int       `json:"eligible_cores_sum"`
	IneligibleCoresSum     int       `json:"ineligible_cores_sum"`
	UniquePhysicalHosts    int       `json:"unique_physical_hosts"`
	VirtualizedNodes       int       `json:"virtualized_nodes"`
	PhysicalNodes          int       `json:"physical_nodes"`
}

// ComplianceReport generates reports from v_license_compliance_report view
type ComplianceReport struct {
	db *sql.DB
}

// NewComplianceReport creates a new report generator
func NewComplianceReport(db *sql.DB) *ComplianceReport {
	return &ComplianceReport{db: db}
}

// Query retrieves data from the view with optional filters
func (r *ComplianceReport) Query(productCode string, fromDate, toDate *time.Time, nonCompliantOnly bool) ([]ComplianceRow, error) {
	query := `
		SELECT 
			measurement_date,
			product_mnemo_code,
			product_name,
			mode,
			term_id,
			program_number,
			program_name,
			total_nodes,
			running_nodes,
			total_installations,
			total_vm_cores,
			total_license_cores_raw,
			eligible_cores_sum,
			ineligible_cores_sum,
			unique_physical_hosts,
			virtualized_nodes,
			physical_nodes
		FROM v_license_compliance_report
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
	
	// Note: nonCompliantOnly filter removed as view doesn't have compliance_status
	
	query += " ORDER BY measurement_date DESC, product_mnemo_code"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query compliance: %w", err)
	}
	defer rows.Close()
	
	var results []ComplianceRow
	for rows.Next() {
		var row ComplianceRow
		var dateStr string
		
		err := rows.Scan(
			&dateStr,
			&row.ProductMnemoCode,
			&row.ProductName,
			&row.Mode,
			&row.TermID,
			&row.ProgramNumber,
			&row.ProgramName,
			&row.TotalNodes,
			&row.RunningNodes,
			&row.TotalInstallations,
			&row.TotalVMCores,
			&row.TotalLicenseCoresRaw,
			&row.EligibleCoresSum,
			&row.IneligibleCoresSum,
			&row.UniquePhysicalHosts,
			&row.VirtualizedNodes,
			&row.PhysicalNodes,
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
func (r *ComplianceReport) WriteTable(w io.Writer, rows []ComplianceRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "DATE\tPRODUCT\tMODE\tPROGRAM\tNODES\tRUN\tINST\tVM_CORES\tELIG\tINELIG")
	fmt.Fprintln(tw, "----\t-------\t----\t-------\t-----\t---\t----\t--------\t----\t------")
	
	// Data rows
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n",
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductMnemoCode,
			row.Mode,
			row.ProgramNumber,
			row.TotalNodes,
			row.RunningNodes,
			row.TotalInstallations,
			row.TotalVMCores,
			row.EligibleCoresSum,
			row.IneligibleCoresSum,
		)
	}
	
	// Summary
	if len(rows) > 0 {
		totalNodes := 0
		totalVM := 0
		totalElig := 0
		totalInelig := 0
		for _, row := range rows {
			totalNodes += row.TotalNodes
			totalVM += row.TotalVMCores
			totalElig += row.EligibleCoresSum
			totalInelig += row.IneligibleCoresSum
		}
		
		fmt.Fprintln(tw, "----\t-------\t----\t-------\t-----\t---\t----\t--------\t----\t------")
		fmt.Fprintf(tw, "TOTAL\t\t\t\t%d\t\t\t%d\t%d\t%d\n", totalNodes, totalVM, totalElig, totalInelig)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *ComplianceReport) WriteCSV(w io.Writer, rows []ComplianceRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"measurement_date",
		"product_mnemo_code",
		"product_name",
		"mode",
		"term_id",
		"program_number",
		"program_name",
		"total_nodes",
		"running_nodes",
		"total_installations",
		"total_vm_cores",
		"total_license_cores_raw",
		"eligible_cores_sum",
		"ineligible_cores_sum",
		"unique_physical_hosts",
		"virtualized_nodes",
		"physical_nodes",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductMnemoCode,
			row.ProductName,
			row.Mode,
			row.TermID,
			row.ProgramNumber,
			row.ProgramName,
			fmt.Sprintf("%d", row.TotalNodes),
			fmt.Sprintf("%d", row.RunningNodes),
			fmt.Sprintf("%d", row.TotalInstallations),
			fmt.Sprintf("%d", row.TotalVMCores),
			fmt.Sprintf("%d", row.TotalLicenseCoresRaw),
			fmt.Sprintf("%d", row.EligibleCoresSum),
			fmt.Sprintf("%d", row.IneligibleCoresSum),
			fmt.Sprintf("%d", row.UniquePhysicalHosts),
			fmt.Sprintf("%d", row.VirtualizedNodes),
			fmt.Sprintf("%d", row.PhysicalNodes),
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *ComplianceReport) WriteJSON(w io.Writer, rows []ComplianceRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
