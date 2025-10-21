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
	PhysicalHostID   string `json:"physical_host_id"`
	SystemType       string `json:"system_type"`
	TotalCores       int    `json:"total_cores"`
	VMCount          int    `json:"vm_count"`
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
			physical_host_id,
			system_type,
			total_cores,
			vm_count
		FROM v_physical_host_cores_aggregated
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	if systemType != "" {
		query += " AND system_type = ?"
		args = append(args, systemType)
	}
	
	query += " ORDER BY system_type, physical_host_id"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query physical hosts: %w", err)
	}
	defer rows.Close()
	
	var results []PhysicalHostRow
	for rows.Next() {
		var row PhysicalHostRow
		var hostID sql.NullString
		var systemType sql.NullString
		
		err := rows.Scan(
			&hostID,
			&systemType,
			&row.TotalCores,
			&row.VMCount,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		
		if hostID.Valid {
			row.PhysicalHostID = hostID.String
		} else {
			row.PhysicalHostID = "N/A"
		}
		
		if systemType.Valid {
			row.SystemType = systemType.String
		} else {
			row.SystemType = "Unknown"
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
	fmt.Fprintln(tw, "PHYSICAL HOST ID\tSYSTEM TYPE\tTOTAL CORES\tVM COUNT")
	fmt.Fprintln(tw, strings.Repeat("-", 80))
	
	// Data rows
	totalCores := 0
	totalVMs := 0
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%d\t%d\n",
			row.PhysicalHostID,
			row.SystemType,
			row.TotalCores,
			row.VMCount,
		)
		totalCores += row.TotalCores
		totalVMs += row.VMCount
	}
	
	// Summary
	if len(rows) > 0 {
		fmt.Fprintln(tw, strings.Repeat("-", 80))
		fmt.Fprintf(tw, "TOTAL (%d hosts)\t\t%d\t%d\n", len(rows), totalCores, totalVMs)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *PhysicalHostReport) WriteCSV(w io.Writer, rows []PhysicalHostRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"physical_host_id",
		"system_type",
		"total_cores",
		"vm_count",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.PhysicalHostID,
			row.SystemType,
			fmt.Sprintf("%d", row.TotalCores),
			fmt.Sprintf("%d", row.VMCount),
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
