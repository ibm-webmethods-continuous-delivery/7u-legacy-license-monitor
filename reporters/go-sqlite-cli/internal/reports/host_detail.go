// Copyright 2025 Mihai Ungureanu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

// HostDetailRow represents a row in the host detail report
// Uses sql.NullString for fields that may be NULL (from LEFT JOIN)
type HostDetailRow struct {
	HostFQDN               string         `json:"host_fqdn"`
	Date                   time.Time      `json:"date"`
	Virtual                string         `json:"virtual"`
	ProductCode            sql.NullString `json:"product_code"`
	Running                sql.NullString `json:"running"`
	Installed              sql.NullString `json:"installed"`
	VirtualCPUs            int            `json:"virtual_cpus"`
	PhysicalHostID         sql.NullString `json:"physical_host_id"`
	PhysicalCPUs           sql.NullInt64  `json:"physical_cpus"`
	OperatingSystem        string         `json:"operating_system"`
	EligibleOS             string         `json:"eligible_os"`
	EligibleVirtualization string         `json:"eligible_virtualization"`
}

// HostDetailReport generates host detail reports
type HostDetailReport struct {
	db *sql.DB
}

// NewHostDetailReport creates a new host detail report generator
func NewHostDetailReport(db *sql.DB) *HostDetailReport {
	return &HostDetailReport{db: db}
}

// Query executes the host detail query with optional filters
func (r *HostDetailReport) Query(hostFilter, productFilter, fromDate, toDate string) ([]HostDetailRow, error) {
	query := `
		SELECT 
			host_fqdn,
			date,
			virtual,
			product_code,
			running,
			installed,
			virtual_cpus,
			physical_host_id,
			physical_cpus,
			operating_system,
			eligible_os,
			eligible_virtualization
		FROM v_host_detail
		WHERE 1=1
	`

	args := []interface{}{}
	argNum := 1

	if hostFilter != "" {
		query += fmt.Sprintf(" AND host_fqdn LIKE $%d", argNum)
		args = append(args, "%"+hostFilter+"%")
		argNum++
	}

	if productFilter != "" {
		query += fmt.Sprintf(" AND product_code = $%d", argNum)
		args = append(args, productFilter)
		argNum++
	}

	if fromDate != "" {
		query += fmt.Sprintf(" AND date >= $%d", argNum)
		args = append(args, fromDate)
		argNum++
	}

	if toDate != "" {
		query += fmt.Sprintf(" AND date <= $%d", argNum)
		args = append(args, toDate)
		argNum++
	}

	query += " ORDER BY date DESC, host_fqdn, product_code"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query host detail: %w", err)
	}
	defer rows.Close()

	var results []HostDetailRow
	for rows.Next() {
		var row HostDetailRow
		var dateStr string

		err := rows.Scan(
			&row.HostFQDN,
			&dateStr,
			&row.Virtual,
			&row.ProductCode,
			&row.Running,
			&row.Installed,
			&row.VirtualCPUs,
			&row.PhysicalHostID,
			&row.PhysicalCPUs,
			&row.OperatingSystem,
			&row.EligibleOS,
			&row.EligibleVirtualization,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}

		// Parse date
		row.Date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse date: %w", err)
		}

		results = append(results, row)
	}

	return results, rows.Err()
}

// WriteTable writes the report in table format
func (r *HostDetailReport) WriteTable(w io.Writer, rows []HostDetailRow) error {
	if len(rows) == 0 {
		fmt.Fprintln(w, "No data found")
		return nil
	}

	fmt.Fprintln(w, "Host Detail Report")
	fmt.Fprintln(w, "==========================================================================================================")
	fmt.Fprintln(w, "")

	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	
	// Write header
	fmt.Fprintln(tw, "Host FQDN\tDate\tVirt\tProduct\tRun\tInst\tvCPUs\tPhysical Host\tpCPUs\tOS\tOS Elig\tVirt Elig")
	fmt.Fprintln(tw, "--------\t----\t----\t-------\t---\t----\t-----\t-------------\t-----\t--\t-------\t---------")
	
	for _, row := range rows {
		physHostID := "N/A"
		if row.PhysicalHostID.Valid {
			physHostID = row.PhysicalHostID.String
		}

		physCPUs := "N/A"
		if row.PhysicalCPUs.Valid {
			physCPUs = fmt.Sprintf("%d", row.PhysicalCPUs.Int64)
		}

		productCode := "N/A"
		if row.ProductCode.Valid {
			productCode = row.ProductCode.String
		}

		running := "N/A"
		if row.Running.Valid {
			running = row.Running.String
		}

		installed := "N/A"
		if row.Installed.Valid {
			installed = row.Installed.String
		}

		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n",
			row.HostFQDN,
			row.Date.Format("2006-01-02"),
			row.Virtual,
			productCode,
			running,
			installed,
			row.VirtualCPUs,
			physHostID,
			physCPUs,
			row.OperatingSystem,
			row.EligibleOS,
			row.EligibleVirtualization,
		)
	}

	tw.Flush()
	fmt.Fprintln(w, "")
	fmt.Fprintf(w, "Total rows: %d\n", len(rows))
	return nil
}

// WriteCSV writes the report in CSV format
func (r *HostDetailReport) WriteCSV(w io.Writer, rows []HostDetailRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()

	// Write header
	header := []string{
		"host_fqdn",
		"date",
		"virtual",
		"product_code",
		"running",
		"installed",
		"virtual_cpus",
		"physical_host_id",
		"physical_cpus",
		"operating_system",
		"eligible_os",
		"eligible_virtualization",
	}
	if err := writer.Write(header); err != nil {
		return fmt.Errorf("failed to write CSV header: %w", err)
	}

	// Write data rows
	for _, row := range rows {
		physHostID := ""
		if row.PhysicalHostID.Valid {
			physHostID = row.PhysicalHostID.String
		}

		physCPUs := ""
		if row.PhysicalCPUs.Valid {
			physCPUs = fmt.Sprintf("%d", row.PhysicalCPUs.Int64)
		}

		productCode := ""
		if row.ProductCode.Valid {
			productCode = row.ProductCode.String
		}

		running := ""
		if row.Running.Valid {
			running = row.Running.String
		}

		installed := ""
		if row.Installed.Valid {
			installed = row.Installed.String
		}

		record := []string{
			row.HostFQDN,
			row.Date.Format("2006-01-02"),
			row.Virtual,
			productCode,
			running,
			installed,
			fmt.Sprintf("%d", row.VirtualCPUs),
			physHostID,
			physCPUs,
			row.OperatingSystem,
			row.EligibleOS,
			row.EligibleVirtualization,
		}
		if err := writer.Write(record); err != nil {
			return fmt.Errorf("failed to write CSV record: %w", err)
		}
	}

	return nil
}

// WriteJSON writes the report in JSON format
func (r *HostDetailReport) WriteJSON(w io.Writer, rows []HostDetailRow) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(rows)
}
