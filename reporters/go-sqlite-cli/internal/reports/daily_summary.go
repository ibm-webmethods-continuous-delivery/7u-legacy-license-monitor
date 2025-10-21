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
	MeasurementDate   time.Time `json:"measurement_date"`
	ProductCode       string    `json:"product_code"`
	ProductName       string    `json:"product_name"`
	NodeCount         int       `json:"node_count"`
	TotalCores        int       `json:"total_cores"`
	LicensedCores     int       `json:"licensed_cores"`
	UnlicensedCores   int       `json:"unlicensed_cores"`
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
			product_code,
			product_name,
			node_count,
			total_cores,
			licensed_cores,
			unlicensed_cores
		FROM v_daily_product_summary
		WHERE 1=1
	`
	
	args := []interface{}{}
	
	if productCode != "" {
		query += " AND product_code = ?"
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
	
	query += " ORDER BY measurement_date DESC, product_code"
	
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
			&row.NodeCount,
			&row.TotalCores,
			&row.LicensedCores,
			&row.UnlicensedCores,
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
	fmt.Fprintln(tw, "DATE\tPRODUCT CODE\tPRODUCT NAME\tNODES\tTOTAL CORES\tLICENSED\tUNLICENSED")
	fmt.Fprintln(tw, strings.Repeat("-", 100))
	
	// Data rows
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\n",
			row.MeasurementDate.Format("2006-01-02"),
			row.ProductCode,
			row.ProductName,
			row.NodeCount,
			row.TotalCores,
			row.LicensedCores,
			row.UnlicensedCores,
		)
	}
	
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
		"node_count",
		"total_cores",
		"licensed_cores",
		"unlicensed_cores",
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
			fmt.Sprintf("%d", row.NodeCount),
			fmt.Sprintf("%d", row.TotalCores),
			fmt.Sprintf("%d", row.LicensedCores),
			fmt.Sprintf("%d", row.UnlicensedCores),
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
