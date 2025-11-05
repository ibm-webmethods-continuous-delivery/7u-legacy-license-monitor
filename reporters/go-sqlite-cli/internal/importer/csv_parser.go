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
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// CSVRecord represents a parsed inspector CSV file
type CSVRecord struct {
	Hostname           string
	Timestamp          time.Time
	SourceFile         string
	DetectionResult    string // SUCCESS, ERROR, or empty
	ErrorMessage       string // Error message if detection failed
	SystemFields       map[string]string
	ProductDetections  map[string]*ProductDetection
}

// ProductDetection represents detection data for a product
type ProductDetection struct {
	ProductCode           string
	Status                string // present or absent
	IBMProductCode        string
	RunningStatus         string
	RunningCount          int
	RunningCommandlines   string
	InstallStatus         string
	InstallCount          int
	InstallPaths          []string
}

// ParseCSVFile parses an inspector CSV file in Parameter,Value format
func ParseCSVFile(filePath string) (*CSVRecord, error) {
	// Extract hostname from filename pattern: iwdli_output_<hostname>_<timestamp>.csv
	hostname, err := extractHostnameFromFilename(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to extract hostname from filename: %w", err)
	}

	// Open file
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	// Parse CSV
	reader := csv.NewReader(file)
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV header: %w", err)
	}
	if len(header) < 2 || header[0] != "Parameter" || header[1] != "Value" {
		return nil, fmt.Errorf("invalid CSV format: expected 'Parameter,Value' header")
	}

	record := &CSVRecord{
		Hostname:          hostname,
		SourceFile:        filePath,
		SystemFields:      make(map[string]string),
		ProductDetections: make(map[string]*ProductDetection),
	}

	// Read all records
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to read CSV row: %w", err)
		}

		if len(row) < 2 {
			continue // Skip empty rows
		}

		parameter := strings.TrimSpace(row[0])
		value := strings.TrimSpace(row[1])

		// Normalize parameter name to uppercase for consistent handling
		parameterUpper := strings.ToUpper(parameter)

		// Check if this is a product field
		if isProductField(parameterUpper) {
			if err := parseProductField(record, parameterUpper, value); err != nil {
				return nil, fmt.Errorf("failed to parse product field %s: %w", parameter, err)
			}
		} else {
			// Store both original and uppercase versions for compatibility
			record.SystemFields[parameter] = value
			if parameterUpper != parameter {
				record.SystemFields[parameterUpper] = value
			}

			// Parse timestamp if this is the detection_timestamp field (case-insensitive)
			if parameterUpper == "DETECTION_TIMESTAMP" {
				ts, err := time.Parse(time.RFC3339, value)
				if err != nil {
					return nil, fmt.Errorf("failed to parse detection_timestamp: %w", err)
				}
				record.Timestamp = ts
			}

			// Override hostname from CSV if provided
			if parameterUpper == "HOSTNAME" && value != "" {
				record.Hostname = value
			}

			// Capture detection result status
			if parameterUpper == "DETECTION_RESULT" {
				record.DetectionResult = value
			}

			// Capture error message if present
			if parameterUpper == "ERROR_MESSAGE" {
				record.ErrorMessage = value
			}
		}
	}

	// Validate required fields
	if record.Timestamp.IsZero() {
		return nil, fmt.Errorf("missing required field: DETECTION_TIMESTAMP")
	}

	// Check for failed detection
	if record.DetectionResult == "ERROR" {
		// Return record with error information for logging
		// The importer can decide whether to skip or log these
		return record, nil
	}

	return record, nil
}

// extractHostnameFromFilename extracts hostname from filename pattern
// Expected pattern: iwdli_output_<hostname>_<timestamp>.csv
// Timestamp format: YYYY-MM-DD_HHMMSS (e.g., 2025-10-31_161910) or YYYYMMDD_HHMMSS (e.g., 20251021_090906)
func extractHostnameFromFilename(filePath string) (string, error) {
	filename := filepath.Base(filePath)
	
	// Pattern: iwdli_output_<hostname>_<timestamp>.csv
	// Support both date formats: YYYY-MM-DD_HHMMSS and YYYYMMDD_HHMMSS
	re := regexp.MustCompile(`^iwdli_output_([^_]+)_\d{4}-?\d{2}-?\d{2}_\d{6}\.csv$`)
	matches := re.FindStringSubmatch(filename)
	
	if len(matches) < 2 {
		return "", fmt.Errorf("filename does not match expected pattern 'iwdli_output_<hostname>_<timestamp>.csv': %s", filename)
	}
	
	return matches[1], nil
}

// isProductField checks if a parameter name is a product-related field
// Note: This function expects uppercase parameter names
func isProductField(parameter string) bool {
	// Product fields follow patterns like:
	// IS_ONP_PRD, IS_ONP_PRD_IBM_PRODUCT_CODE, IS_ONP_PRD_INSTALL_STATUS, etc.
	// IS_ONP_NPR, IS_ONP_NPR_IBM_PRODUCT_CODE, IS_ONP_NPR_RUNNING_STATUS, etc.
	// BRK_ONP_PRD, BRK_ONP_NPR, UM_ONP_PRD, etc.
	// Also supports numbered fields: IS_ONP_PRD_INSTALL_PATH_01, IS_ONP_NPR_RUNNING_COMMANDLINES_02, etc.
	
	// Check if it contains product code pattern (ends with _PRD, _NPR, or _NONPROD)
	return strings.Contains(parameter, "_PRD") || 
	       strings.Contains(parameter, "_NPR") || 
	       strings.Contains(parameter, "_NONPROD")
}

// parseProductField parses a product-related field and updates the record
// Note: This function expects uppercase parameter names
func parseProductField(record *CSVRecord, parameter, value string) error {
	// Split parameter to extract product code and field type
	// Examples:
	// IS_ONP_PRD -> product code: IS_ONP_PRD, field: (status)
	// IS_ONP_NPR -> product code: IS_ONP_NPR, field: (status)
	// IS_ONP_PRD_IBM_PRODUCT_CODE -> product code: IS_ONP_PRD, field: IBM_PRODUCT_CODE
	// IS_ONP_NPR_RUNNING_STATUS -> product code: IS_ONP_NPR, field: RUNNING_STATUS
	// IS_ONP_NPR_INSTALL_PATH_01 -> product code: IS_ONP_NPR, field: INSTALL_PATH (numbered)
	// IS_ONP_NPR_RUNNING_COMMANDLINES_02 -> product code: IS_ONP_NPR, field: RUNNING_COMMANDLINES (numbered)
	
	parts := strings.Split(parameter, "_")
	if len(parts) < 3 {
		return fmt.Errorf("invalid product parameter format: %s", parameter)
	}

	// Find the product code (everything up to and including _PRD, _NPR, or _NONPROD)
	var productCode string
	var fieldType string
	var fieldNumber string
	
	for i, part := range parts {
		if part == "PRD" || part == "NPR" || part == "NONPROD" {
			productCode = strings.Join(parts[:i+1], "_")
			if i+1 < len(parts) {
				remainingParts := parts[i+1:]
				
				// Check if the last part is a number (e.g., _01, _02)
				lastPart := remainingParts[len(remainingParts)-1]
				if matched, _ := regexp.MatchString(`^\d+$`, lastPart); matched {
					fieldNumber = lastPart
					if len(remainingParts) > 1 {
						fieldType = strings.Join(remainingParts[:len(remainingParts)-1], "_")
					}
				} else {
					fieldType = strings.Join(remainingParts, "_")
				}
			}
			break
		}
	}

	if productCode == "" {
		return fmt.Errorf("could not extract product code from: %s", parameter)
	}

	// Get or create product detection entry
	detection, exists := record.ProductDetections[productCode]
	if !exists {
		detection = &ProductDetection{
			ProductCode: productCode,
		}
		record.ProductDetections[productCode] = detection
	}

	// Parse field based on type
	switch fieldType {
	case "":
		// This is the main status field (present/absent)
		detection.Status = value
	case "IBM_PRODUCT_CODE":
		detection.IBMProductCode = value
	case "RUNNING_STATUS":
		detection.RunningStatus = value
	case "RUNNING_COUNT":
		// Parse running count (may have leading spaces)
		var count int
		fmt.Sscanf(value, "%d", &count)
		detection.RunningCount = count
	case "RUNNING_COMMANDLINES", "RUNNING_COMMANDLINE":
		// Handle both old format (single field) and new format (numbered fields)
		if fieldNumber != "" {
			// New numbered format: append with newline separator
			if detection.RunningCommandlines != "" {
				detection.RunningCommandlines += "\n"
			}
			detection.RunningCommandlines += value
		} else {
			// Old format: single field with all commandlines
			detection.RunningCommandlines = value
		}
	case "INSTALL_STATUS":
		detection.InstallStatus = value
	case "INSTALL_COUNT":
		// Parse install count (may have leading spaces)
		var count int
		fmt.Sscanf(value, "%d", &count)
		detection.InstallCount = count
	case "INSTALL_PATHS":
		// Old format: semicolon-separated paths in single field
		if value != "" {
			detection.InstallPaths = strings.Split(value, ";")
		}
	case "INSTALL_PATH":
		// New numbered format: individual path fields
		if value != "" {
			detection.InstallPaths = append(detection.InstallPaths, value)
		}
	}

	return nil
}

// GetSystemField retrieves a system field value (case-insensitive)
func (r *CSVRecord) GetSystemField(name string) string {
	// Try exact match first
	if val, exists := r.SystemFields[name]; exists {
		return val
	}
	// Try uppercase match
	if val, exists := r.SystemFields[strings.ToUpper(name)]; exists {
		return val
	}
	return ""
}

// GetSystemFieldWithDefault retrieves a system field with a default value (case-insensitive)
func (r *CSVRecord) GetSystemFieldWithDefault(name, defaultValue string) string {
	if val := r.GetSystemField(name); val != "" {
		return val
	}
	return defaultValue
}

// IsDetectionSuccess returns true if the detection was successful
func (r *CSVRecord) IsDetectionSuccess() bool {
	// If DETECTION_RESULT is not present, assume success (backward compatibility)
	if r.DetectionResult == "" {
		return true
	}
	return r.DetectionResult == "SUCCESS"
}

// IsDetectionError returns true if the detection failed
func (r *CSVRecord) IsDetectionError() bool {
	return r.DetectionResult == "ERROR"
}

// GetDetectionError returns the error message if detection failed
func (r *CSVRecord) GetDetectionError() string {
	if r.IsDetectionError() {
		if r.ErrorMessage != "" {
			return r.ErrorMessage
		}
		return "Detection failed (no error message provided)"
	}
	return ""
}
