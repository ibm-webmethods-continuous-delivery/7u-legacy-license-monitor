package reports

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"text/tabwriter"
)

// PeakUsageRow represents a row from v_peak_usage
type PeakUsageRow struct {
	ProductMnemoCode           string `json:"product_mnemo_code"`
	IBMProductCode             string `json:"ibm_product_code"`
	ProductName                string `json:"product_name"`
	Mode                       string `json:"mode"`
	TermID                     string `json:"term_id"`
	ProgramNumber              string `json:"program_number"`
	ProgramName                string `json:"program_name"`
	PeakRunningVCores          int    `json:"peak_running_vcores"`
	PeakRunningPhysicalCores   int    `json:"peak_running_physical_cores"`
	PeakRunningTotalCores      int    `json:"peak_running_total_cores"`
	PeakInstalledVCores        int    `json:"peak_installed_vcores"`
	PeakInstalledPhysicalCores int    `json:"peak_installed_physical_cores"`
	PeakInstalledTotalCores    int    `json:"peak_installed_total_cores"`
	PeakRunningNodes           int    `json:"peak_running_nodes"`
	PeakInstalledNodes         int    `json:"peak_installed_nodes"`
	PeakEligibleCores          int    `json:"peak_eligible_cores"`
	PeakIneligibleCores        int    `json:"peak_ineligible_cores"`
	PeakActualVCores           int    `json:"peak_actual_vcores"`
	PeakDate                   string `json:"peak_date"`
}

// PeakUsageReport generates reports from v_peak_usage view
type PeakUsageReport struct {
	db *sql.DB
}

// NewPeakUsageReport creates a new report generator
func NewPeakUsageReport(db *sql.DB) *PeakUsageReport {
	return &PeakUsageReport{db: db}
}

// Query retrieves data from the view with optional filters
func (r *PeakUsageReport) Query(productCode string) ([]PeakUsageRow, error) {
	query := `
		SELECT 
			product_mnemo_code,
			ibm_product_code,
			product_name,
			mode,
			term_id,
			program_number,
			program_name,
			peak_running_vcores,
			peak_running_physical_cores,
			peak_running_total_cores,
			peak_installed_vcores,
			peak_installed_physical_cores,
			peak_installed_total_cores,
			peak_running_nodes,
			peak_installed_nodes,
			peak_eligible_cores,
			peak_ineligible_cores,
			peak_actual_vcores,
			peak_date
		FROM v_peak_usage
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	if productCode != "" {
		query += " AND product_mnemo_code = ?"
		args = append(args, productCode)
	}
	
	query += " ORDER BY peak_running_total_cores DESC, product_mnemo_code"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query peak usage: %w", err)
	}
	defer rows.Close()
	
	var results []PeakUsageRow
	for rows.Next() {
		var row PeakUsageRow
		
		err := rows.Scan(
			&row.ProductMnemoCode,
			&row.IBMProductCode,
			&row.ProductName,
			&row.Mode,
			&row.TermID,
			&row.ProgramNumber,
			&row.ProgramName,
			&row.PeakRunningVCores,
			&row.PeakRunningPhysicalCores,
			&row.PeakRunningTotalCores,
			&row.PeakInstalledVCores,
			&row.PeakInstalledPhysicalCores,
			&row.PeakInstalledTotalCores,
			&row.PeakRunningNodes,
			&row.PeakInstalledNodes,
			&row.PeakEligibleCores,
			&row.PeakIneligibleCores,
			&row.PeakActualVCores,
			&row.PeakDate,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		results = append(results, row)
	}
	
	return results, rows.Err()
}

// WriteTable writes data in ASCII table format
func (r *PeakUsageReport) WriteTable(w io.Writer, rows []PeakUsageRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "PRODUCT\tIBM_CODE\tPEAK_CORES\tACTUAL_VC\tPEAK_NODES\tPEAK_DATE\tMODE\tPROGRAM")
	fmt.Fprintln(tw, "-------\t--------\t----------\t---------\t----------\t---------\t----\t-------")
	
	// Data rows
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\n",
			row.ProductMnemoCode,
			row.IBMProductCode,
			row.PeakRunningTotalCores,
			row.PeakActualVCores,
			row.PeakRunningNodes,
			row.PeakDate,
			row.Mode,
			row.ProgramNumber,
		)
	}
	
	// Summary
	if len(rows) > 0 {
		totalPeakCores := 0
		totalActualVCores := 0
		for _, row := range rows {
			totalPeakCores += row.PeakRunningTotalCores
			totalActualVCores += row.PeakActualVCores
		}
		
		fmt.Fprintln(tw, "-------\t--------\t----------\t---------\t----------\t---------\t----\t-------")
		fmt.Fprintf(tw, "TOTAL (%d products)\t\t%d\t%d\t\t\t\t\n", len(rows), totalPeakCores, totalActualVCores)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *PeakUsageReport) WriteCSV(w io.Writer, rows []PeakUsageRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"product_mnemo_code",
		"ibm_product_code",
		"product_name",
		"mode",
		"term_id",
		"program_number",
		"program_name",
		"peak_running_vcores",
		"peak_running_physical_cores",
		"peak_running_total_cores",
		"peak_installed_vcores",
		"peak_installed_physical_cores",
		"peak_installed_total_cores",
		"peak_running_nodes",
		"peak_installed_nodes",
		"peak_eligible_cores",
		"peak_ineligible_cores",
		"peak_actual_vcores",
		"peak_date",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.ProductMnemoCode,
			row.IBMProductCode,
			row.ProductName,
			row.Mode,
			row.TermID,
			row.ProgramNumber,
			row.ProgramName,
			fmt.Sprintf("%d", row.PeakRunningVCores),
			fmt.Sprintf("%d", row.PeakRunningPhysicalCores),
			fmt.Sprintf("%d", row.PeakRunningTotalCores),
			fmt.Sprintf("%d", row.PeakInstalledVCores),
			fmt.Sprintf("%d", row.PeakInstalledPhysicalCores),
			fmt.Sprintf("%d", row.PeakInstalledTotalCores),
			fmt.Sprintf("%d", row.PeakRunningNodes),
			fmt.Sprintf("%d", row.PeakInstalledNodes),
			fmt.Sprintf("%d", row.PeakEligibleCores),
			fmt.Sprintf("%d", row.PeakIneligibleCores),
			fmt.Sprintf("%d", row.PeakActualVCores),
			row.PeakDate,
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *PeakUsageReport) WriteJSON(w io.Writer, rows []PeakUsageRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
