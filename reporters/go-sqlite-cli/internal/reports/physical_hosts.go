package reports

import (
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"
)

// PhysicalHostRow represents a row from v_physical_host_cores_aggregated
type PhysicalHostRow struct {
	MeasurementDate    string `json:"measurement_date"`
	PhysicalHostID     string `json:"physical_host_id"`
	HostIDMethod       string `json:"host_id_method"`
	HostIDConfidence   string `json:"host_id_confidence"`
	PhysicalCores      int    `json:"physical_cores"`
	VMCount            int    `json:"vm_count"`
	VMList             string `json:"vm_list"`
	TotalVMCores       int    `json:"total_vm_cores"`
	LatestMeasurement  string `json:"latest_measurement"`
}

// PhysicalHostReport generates reports from v_physical_host_cores_aggregated view
type PhysicalHostReport struct {
	db *sql.DB
}

// NewPhysicalHostReport creates a new report generator
func NewPhysicalHostReport(db *sql.DB) *PhysicalHostReport {
	return &PhysicalHostReport{db: db}
}

// Query retrieves data from the view with optional filters
func (r *PhysicalHostReport) Query(systemType string) ([]PhysicalHostRow, error) {
	query := `
		SELECT 
			measurement_date,
			physical_host_id,
			host_id_method,
			host_id_confidence,
			physical_cores,
			vm_count,
			vm_list,
			total_vm_cores,
			latest_measurement
		FROM v_physical_host_cores_aggregated
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	// Note: system_type filter removed as it doesn't exist in the view
	// The view groups by date and physical host
	
	query += " ORDER BY measurement_date DESC, physical_host_id"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query physical hosts: %w", err)
	}
	defer rows.Close()
	
	var results []PhysicalHostRow
	for rows.Next() {
		var row PhysicalHostRow
		var physicalCores sql.NullInt64
		
		err := rows.Scan(
			&row.MeasurementDate,
			&row.PhysicalHostID,
			&row.HostIDMethod,
			&row.HostIDConfidence,
			&physicalCores,
			&row.VMCount,
			&row.VMList,
			&row.TotalVMCores,
			&row.LatestMeasurement,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		// Handle NULL physical_cores
		if physicalCores.Valid {
			row.PhysicalCores = int(physicalCores.Int64)
		} else {
			row.PhysicalCores = 0
		}
		
		results = append(results, row)
	}
	
	return results, rows.Err()
}

// WriteTable writes data in ASCII table format
func (r *PhysicalHostReport) WriteTable(w io.Writer, rows []PhysicalHostRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "DATE\tPHYS_HOST_ID\tMETHOD\tCONFIDENCE\tPHYS_CORES\tVM_COUNT\tVM_CORES")
	fmt.Fprintln(tw, strings.Repeat("-", 100))
	
	// Data rows
	totalPhysCores := 0
	totalVMs := 0
	totalVMCores := 0
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%d\t%d\t%d\n",
			row.MeasurementDate,
			row.PhysicalHostID,
			row.HostIDMethod,
			row.HostIDConfidence,
			row.PhysicalCores,
			row.VMCount,
			row.TotalVMCores,
		)
		totalPhysCores += row.PhysicalCores
		totalVMs += row.VMCount
		totalVMCores += row.TotalVMCores
	}
	
	// Summary
	if len(rows) > 0 {
		fmt.Fprintln(tw, strings.Repeat("-", 100))
		fmt.Fprintf(tw, "TOTAL (%d hosts)\t\t\t\t%d\t%d\t%d\n", len(rows), totalPhysCores, totalVMs, totalVMCores)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *PhysicalHostReport) WriteCSV(w io.Writer, rows []PhysicalHostRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"measurement_date",
		"physical_host_id",
		"host_id_method",
		"host_id_confidence",
		"physical_cores",
		"vm_count",
		"vm_list",
		"total_vm_cores",
		"latest_measurement",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.MeasurementDate,
			row.PhysicalHostID,
			row.HostIDMethod,
			row.HostIDConfidence,
			fmt.Sprintf("%d", row.PhysicalCores),
			fmt.Sprintf("%d", row.VMCount),
			row.VMList,
			fmt.Sprintf("%d", row.TotalVMCores),
			row.LatestMeasurement,
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

// WriteJSON writes data in JSON format
func (r *PhysicalHostReport) WriteJSON(w io.Writer, rows []PhysicalHostRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
