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
	ProductCode       string    `json:"product_code"`
	ProductName       string    `json:"product_name"`
	MeasurementDate   time.Time `json:"measurement_date"`
	TotalCores        int       `json:"total_cores"`
	LicensedCores     int       `json:"licensed_cores"`
	UnlicensedCores   int       `json:"unlicensed_cores"`
	NonProdCores      int       `json:"non_prod_cores"`
	ThirdPartyCores   int       `json:"third_party_cores"`
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
			product_code,
			product_name,
			measurement_date,
			total_cores,
			licensed_cores,
			unlicensed_cores,
			non_prod_cores,
			third_party_cores
		FROM v_core_aggregation_by_product
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
	
	query += " ORDER BY product_code, measurement_date DESC"
	
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query core aggregation: %w", err)
	}
	defer rows.Close()
	
	var results []CoreAggregationRow
	for rows.Next() {
		var row CoreAggregationRow
		var dateStr string
		
		err := rows.Scan(
			&row.ProductCode,
			&row.ProductName,
			&dateStr,
			&row.TotalCores,
			&row.LicensedCores,
			&row.UnlicensedCores,
			&row.NonProdCores,
			&row.ThirdPartyCores,
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
func (r *CoreAggregationReport) WriteTable(w io.Writer, rows []CoreAggregationRow) error {
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	defer tw.Flush()
	
	// Header
	fmt.Fprintln(tw, "PRODUCT CODE\tPRODUCT NAME\tDATE\tTOTAL\tLICENSED\tUNLICENSED\tNON-PROD\t3RD-PARTY")
	fmt.Fprintln(tw, strings.Repeat("-", 120))
	
	// Data rows
	for _, row := range rows {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n",
			row.ProductCode,
			row.ProductName,
			row.MeasurementDate.Format("2006-01-02"),
			row.TotalCores,
			row.LicensedCores,
			row.UnlicensedCores,
			row.NonProdCores,
			row.ThirdPartyCores,
		)
	}
	
	// Summary
	if len(rows) > 0 {
		totalCores := 0
		licensedCores := 0
		unlicensedCores := 0
		for _, row := range rows {
			totalCores += row.TotalCores
			licensedCores += row.LicensedCores
			unlicensedCores += row.UnlicensedCores
		}
		
		fmt.Fprintln(tw, strings.Repeat("-", 120))
		fmt.Fprintf(tw, "TOTAL\t\t\t%d\t%d\t%d\t\t\n", totalCores, licensedCores, unlicensedCores)
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *CoreAggregationReport) WriteCSV(w io.Writer, rows []CoreAggregationRow) error {
	writer := csv.NewWriter(w)
	defer writer.Flush()
	
	// Header
	err := writer.Write([]string{
		"product_code",
		"product_name",
		"measurement_date",
		"total_cores",
		"licensed_cores",
		"unlicensed_cores",
		"non_prod_cores",
		"third_party_cores",
	})
	if err != nil {
		return err
	}
	
	// Data rows
	for _, row := range rows {
		err := writer.Write([]string{
			row.ProductCode,
			row.ProductName,
			row.MeasurementDate.Format("2006-01-02"),
			fmt.Sprintf("%d", row.TotalCores),
			fmt.Sprintf("%d", row.LicensedCores),
			fmt.Sprintf("%d", row.UnlicensedCores),
			fmt.Sprintf("%d", row.NonProdCores),
			fmt.Sprintf("%d", row.ThirdPartyCores),
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
