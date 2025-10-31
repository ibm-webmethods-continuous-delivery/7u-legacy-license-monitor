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

package importer

import (
	"database/sql"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"strings"
)

// ReferenceDataLoader loads reference data (product codes, license terms) into database
type ReferenceDataLoader struct {
	db *sql.DB
}

// NewReferenceDataLoader creates a new reference data loader
func NewReferenceDataLoader(db *sql.DB) *ReferenceDataLoader {
	return &ReferenceDataLoader{db: db}
}

// LoadLicenseTermsCSV loads license terms from CSV file
// CSV format: license-terms-id,program-number,program-name
func (l *ReferenceDataLoader) LoadLicenseTermsCSV(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.FieldsPerRecord = -1 // Allow variable number of fields
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %w", err)
	}

	// Validate header
	expectedHeader := []string{"license-terms-id", "program-number", "program-name"}
	if !equalHeaders(header, expectedHeader) {
		return fmt.Errorf("invalid CSV header, expected: %v", expectedHeader)
	}

	tx, err := l.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	insertedCount := 0
	updatedCount := 0

	// Read records
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read row: %w", err)
		}

		if len(row) < 3 {
			continue // Skip incomplete rows
		}

		termID := strings.TrimSpace(row[0])
		programNumber := strings.TrimSpace(row[1])
		programName := strings.TrimSpace(row[2])

		if termID == "" || programNumber == "" {
			continue // Skip rows with missing required fields
		}

		// Check if license term already exists
		var count int
		err = tx.QueryRow("SELECT COUNT(*) FROM license_terms WHERE term_id = ?", termID).Scan(&count)
		if err != nil {
			return fmt.Errorf("failed to check license term existence: %w", err)
		}

		if count == 0 {
			// Insert new license term
			_, err = tx.Exec(`
				INSERT INTO license_terms (term_id, program_number, program_name)
				VALUES (?, ?, ?)
			`, termID, programNumber, programName)
			if err != nil {
				return fmt.Errorf("failed to insert license term %s: %w", termID, err)
			}
			insertedCount++
		} else {
			// Update existing license term
			_, err = tx.Exec(`
				UPDATE license_terms 
				SET program_number = ?, program_name = ?, updated_at = CURRENT_TIMESTAMP
				WHERE term_id = ?
			`, programNumber, programName, termID)
			if err != nil {
				return fmt.Errorf("failed to update license term %s: %w", termID, err)
			}
			updatedCount++
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	fmt.Printf("License terms loaded: %d inserted, %d updated\n", insertedCount, updatedCount)
	return nil
}

// LoadProductCodesCSV loads product codes from CSV file
// CSV format: product-mnemo-id,product-code,product-name,mode,license-terms-id,notes
func (l *ReferenceDataLoader) LoadProductCodesCSV(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.FieldsPerRecord = -1 // Allow variable number of fields
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %w", err)
	}

	// Validate header
	expectedHeader := []string{"product-mnemo-id", "product-code", "product-name", "mode", "license-terms-id", "notes"}
	if !equalHeaders(header, expectedHeader) {
		return fmt.Errorf("invalid CSV header, expected: %v", expectedHeader)
	}

	tx, err := l.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	insertedCount := 0
	updatedCount := 0

	// Read records
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read row: %w", err)
		}

		if len(row) < 5 {
			continue // Skip incomplete rows
		}

		productMnemoID := strings.TrimSpace(row[0])
		productCode := strings.TrimSpace(row[1])
		productName := strings.TrimSpace(row[2])
		mode := strings.TrimSpace(row[3])
		licenseTermsID := strings.TrimSpace(row[4])
		notes := ""
		if len(row) > 5 {
			notes = strings.TrimSpace(row[5])
		}

		if productMnemoID == "" {
			continue // Skip empty rows
		}

		// First ensure license term exists
		if licenseTermsID != "" {
			err = l.ensureLicenseTerm(tx, licenseTermsID)
			if err != nil {
				return fmt.Errorf("failed to ensure license term %s: %w", licenseTermsID, err)
			}
		}

		// Check if product code already exists
		var count int
		err = tx.QueryRow("SELECT COUNT(*) FROM product_codes WHERE product_mnemo_code = ?", productMnemoID).Scan(&count)
		if err != nil {
			return fmt.Errorf("failed to check product code existence: %w", err)
		}

		if count == 0 {
			// Insert new product code
			_, err = tx.Exec(`
				INSERT INTO product_codes 
				(product_mnemo_code, ibm_product_code, product_name, mode, term_id, notes)
				VALUES (?, ?, ?, ?, ?, ?)
			`, productMnemoID, productCode, productName, mode, licenseTermsID, notes)
			if err != nil {
				return fmt.Errorf("failed to insert product code %s: %w", productMnemoID, err)
			}
			insertedCount++
		} else {
			// Update existing product code
			_, err = tx.Exec(`
				UPDATE product_codes 
				SET ibm_product_code = ?, product_name = ?, mode = ?, term_id = ?, notes = ?,
				    updated_at = CURRENT_TIMESTAMP
				WHERE product_mnemo_code = ?
			`, productCode, productName, mode, licenseTermsID, notes, productMnemoID)
			if err != nil {
				return fmt.Errorf("failed to update product code %s: %w", productMnemoID, err)
			}
			updatedCount++
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	fmt.Printf("Product codes loaded: %d inserted, %d updated\n", insertedCount, updatedCount)
	return nil
}

// ensureLicenseTerm creates license term if it doesn't exist
func (l *ReferenceDataLoader) ensureLicenseTerm(tx *sql.Tx, termID string) error {
	var count int
	err := tx.QueryRow("SELECT COUNT(*) FROM license_terms WHERE term_id = ?", termID).Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {
		// Insert placeholder license term (will be updated later if needed)
		_, err = tx.Exec(`
			INSERT INTO license_terms (term_id, program_number, program_name)
			VALUES (?, ?, ?)
		`, termID, "Unknown", "License term "+termID)
		if err != nil {
			return fmt.Errorf("failed to insert license term: %w", err)
		}
	}

	return nil
}

// equalHeaders compares two header slices
func equalHeaders(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if strings.TrimSpace(a[i]) != strings.TrimSpace(b[i]) {
			return false
		}
	}
	return true
}
