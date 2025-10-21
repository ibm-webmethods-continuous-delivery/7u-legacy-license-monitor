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

// ComplianceRow represents a row from v_license_compliance_report
type ComplianceRow struct {
	ProductCode            string    `json:"product_code"`
	ProductName            string    `json:"product_name"`
	MeasurementDate        time.Time `json:"measurement_date"`
	TotalCores             int       `json:"total_cores"`
	LicensedCores          int       `json:"licensed_cores"`
	UnlicensedCores        int       `json:"unlicensed_cores"`
	LicenseTermID          string    `json:"license_term_id"`
	LicensedCoreCount      int       `json:"licensed_core_count"`
	ComplianceGap          int       `json:"compliance_gap"`
	ComplianceStatus       string    `json:"compliance_status"`
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
			product_code,
			product_name,
			measurement_date,
			total_cores,
			licensed_cores,
			unlicensed_cores,
			COALESCE(license_term_id, 'N/A') as license_term_id,
			COALESCE(licensed_core_count, 0) as licensed_core_count,
			COALESCE(compliance_gap, 0) as compliance_gap,
			COALESCE(compliance_status, 'NO_LICENSE_DATA') as compliance_status
		FROM v_license_compliance_report
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
	
	if nonCompliantOnly {
		query += " AND compliance_status != 'COMPLIANT'"
	}
	
	query += " ORDER BY compliance_status DESC, product_code, measurement_date DESC"
	
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
			&row.ProductCode,
			&row.ProductName,
			&dateStr,
			&row.TotalCores,
			&row.LicensedCores,
			&row.UnlicensedCores,
			&row.LicenseTermID,
			&row.LicensedCoreCount,
			&row.ComplianceGap,
			&row.ComplianceStatus,
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
	fmt.Fprintln(tw, "PRODUCT CODE\tPRODUCT NAME\tDATE\tLICENSED\tUNLICENSED\tLICENSE LIMIT\tGAP\tSTATUS")
	fmt.Fprintln(tw, strings.Repeat("-", 120))
	
	// Data rows - group by status
	var compliant, nonCompliant, noLicense []ComplianceRow
	for _, row := range rows {
		switch row.ComplianceStatus {
		case "COMPLIANT":
			compliant = append(compliant, row)
		case "NON_COMPLIANT":
			nonCompliant = append(nonCompliant, row)
		default:
			noLicense = append(noLicense, row)
		}
	}
	
	// Show non-compliant first (most important)
	if len(nonCompliant) > 0 {
		fmt.Fprintln(tw, "⚠️  NON-COMPLIANT:")
		for _, row := range nonCompliant {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\t❌ %s\n",
				row.ProductCode,
				row.ProductName,
				row.MeasurementDate.Format("2006-01-02"),
				row.LicensedCores,
				row.UnlicensedCores,
				row.LicensedCoreCount,
				row.ComplianceGap,
				row.ComplianceStatus,
			)
		}
		fmt.Fprintln(tw, "")
	}
	
	// Show no license data next
	if len(noLicense) > 0 {
		fmt.Fprintln(tw, "ℹ️  NO LICENSE DATA:")
		for _, row := range noLicense {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\t⚠️  %s\n",
				row.ProductCode,
				row.ProductName,
				row.MeasurementDate.Format("2006-01-02"),
				row.LicensedCores,
				row.UnlicensedCores,
				row.LicensedCoreCount,
				row.ComplianceGap,
				row.ComplianceStatus,
			)
		}
		fmt.Fprintln(tw, "")
	}
	
	// Show compliant last
	if len(compliant) > 0 {
		fmt.Fprintln(tw, "✅ COMPLIANT:")
		for _, row := range compliant {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%d\t%d\t%d\t%d\t✓ %s\n",
				row.ProductCode,
				row.ProductName,
				row.MeasurementDate.Format("2006-01-02"),
				row.LicensedCores,
				row.UnlicensedCores,
				row.LicensedCoreCount,
				row.ComplianceGap,
				row.ComplianceStatus,
			)
		}
	}
	
	// Summary
	if len(rows) > 0 {
		fmt.Fprintln(tw, strings.Repeat("-", 120))
		fmt.Fprintf(tw, "SUMMARY: %d compliant, %d non-compliant, %d no license data\n", 
			len(compliant), len(nonCompliant), len(noLicense))
	}
	
	return nil
}

// WriteCSV writes data in CSV format
func (r *ComplianceReport) WriteCSV(w io.Writer, rows []ComplianceRow) error {
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
		"license_term_id",
		"licensed_core_count",
		"compliance_gap",
		"compliance_status",
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
			row.LicenseTermID,
			fmt.Sprintf("%d", row.LicensedCoreCount),
			fmt.Sprintf("%d", row.ComplianceGap),
			row.ComplianceStatus,
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
