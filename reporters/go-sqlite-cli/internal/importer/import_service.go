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
	"fmt"
	"strconv"
	"strings"
	"time"
)

// ImportService handles importing CSV data into the database
type ImportService struct {
	db *sql.DB
}

// NewImportService creates a new import service
func NewImportService(db *sql.DB) *ImportService {
	return &ImportService{db: db}
}

// ImportResult contains the results of an import operation
type ImportResult struct {
	SessionID      string
	RecordsCreated int
	RecordsUpdated int
	RecordsSkipped int
	Errors         []string
}

// ImportCSVFile imports a single CSV file
func (s *ImportService) ImportCSVFile(filePath string) (*ImportResult, error) {
	// Parse CSV
	record, err := ParseCSVFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse CSV: %w", err)
	}

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	result := &ImportResult{
		SessionID: generateSessionID(record.Hostname, record.Timestamp),
		Errors:    []string{},
	}

	// 1. Ensure landscape node exists (auto-create)
	mainFQDN := record.GetSystemFieldWithDefault("main_fqdn", record.Hostname+".local")
	if err := s.ensureLandscapeNode(tx, mainFQDN, record.Hostname); err != nil {
		return nil, fmt.Errorf("failed to ensure landscape node: %w", err)
	}

	// 2. Ensure physical host exists (if provided)
	physicalHostID := record.GetSystemField("PHYSICAL_HOST_ID")
	if physicalHostID != "" && physicalHostID != "unknown" {
		if err := s.ensurePhysicalHost(tx, record); err != nil {
			return nil, fmt.Errorf("failed to ensure physical host: %w", err)
		}
	}

	// 3. Insert measurement
	if err := s.insertMeasurement(tx, mainFQDN, record); err != nil {
		return nil, fmt.Errorf("failed to insert measurement: %w", err)
	}
	result.RecordsCreated++

	// 4. Insert detected products
	for _, detection := range record.ProductDetections {
		if err := s.insertDetectedProduct(tx, mainFQDN, record.Timestamp, detection); err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("failed to insert product %s: %v", detection.ProductCode, err))
			// Continue with other products
		} else {
			result.RecordsCreated++
		}
	}

	// 5. Insert import session record
	if err := s.insertImportSession(tx, record, result); err != nil {
		return nil, fmt.Errorf("failed to insert import session: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return result, nil
}

// ensureLandscapeNode creates landscape node if it doesn't exist
func (s *ImportService) ensureLandscapeNode(tx *sql.Tx, mainFQDN, hostname string) error {
	// Check if exists
	var count int
	err := tx.QueryRow("SELECT COUNT(*) FROM landscape_nodes WHERE main_fqdn = ?", mainFQDN).Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {
		// Insert new node with PROD mode as default
		_, err = tx.Exec(`
			INSERT INTO landscape_nodes (main_fqdn, hostname, mode)
			VALUES (?, ?, 'PROD')
		`, mainFQDN, hostname)
		if err != nil {
			return fmt.Errorf("failed to insert landscape node: %w", err)
		}
	}

	return nil
}

// ensurePhysicalHost creates or updates physical host record
func (s *ImportService) ensurePhysicalHost(tx *sql.Tx, record *CSVRecord) error {
	physicalHostID := record.GetSystemField("PHYSICAL_HOST_ID")
	hostIDMethod := record.GetSystemFieldWithDefault("HOST_ID_METHOD", "unknown")
	hostIDConfidence := record.GetSystemFieldWithDefault("HOST_ID_CONFIDENCE", "low")

	// Parse physical CPU count
	var maxPhysicalCPUs *int
	hostPhysicalCPUsStr := record.GetSystemField("HOST_PHYSICAL_CPUS")
	if hostPhysicalCPUsStr != "" && hostPhysicalCPUsStr != "unknown" {
		if cpus, err := strconv.Atoi(strings.TrimSpace(hostPhysicalCPUsStr)); err == nil {
			maxPhysicalCPUs = &cpus
		}
	}

	// Check if exists
	var count int
	err := tx.QueryRow("SELECT COUNT(*) FROM physical_hosts WHERE physical_host_id = ?", physicalHostID).Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {
		// Insert new physical host
		_, err = tx.Exec(`
			INSERT INTO physical_hosts 
			(physical_host_id, host_id_method, host_id_confidence, first_seen, last_seen, max_physical_cpus)
			VALUES (?, ?, ?, ?, ?, ?)
		`, physicalHostID, hostIDMethod, hostIDConfidence, record.Timestamp, record.Timestamp, maxPhysicalCPUs)
		if err != nil {
			return fmt.Errorf("failed to insert physical host: %w", err)
		}
	} else {
		// Update last_seen and max_physical_cpus if larger
		if maxPhysicalCPUs != nil {
			_, err = tx.Exec(`
				UPDATE physical_hosts 
				SET last_seen = ?,
				    max_physical_cpus = CASE 
				        WHEN max_physical_cpus IS NULL OR max_physical_cpus < ? THEN ?
				        ELSE max_physical_cpus
				    END,
				    updated_at = CURRENT_TIMESTAMP
				WHERE physical_host_id = ?
			`, record.Timestamp, *maxPhysicalCPUs, *maxPhysicalCPUs, physicalHostID)
		} else {
			_, err = tx.Exec(`
				UPDATE physical_hosts 
				SET last_seen = ?,
				    updated_at = CURRENT_TIMESTAMP
				WHERE physical_host_id = ?
			`, record.Timestamp, physicalHostID)
		}
		if err != nil {
			return fmt.Errorf("failed to update physical host: %w", err)
		}
	}

	return nil
}

// insertMeasurement inserts a measurement record
func (s *ImportService) insertMeasurement(tx *sql.Tx, mainFQDN string, record *CSVRecord) error {
	// Parse CPU count
	cpuCountStr := strings.TrimSpace(record.GetSystemField("CPU_COUNT"))
	cpuCount, err := strconv.Atoi(cpuCountStr)
	if err != nil {
		return fmt.Errorf("invalid CPU_COUNT value: %s", cpuCountStr)
	}

	// Parse considered CPUs
	consideredCPUsStr := strings.TrimSpace(record.GetSystemField("CONSIDERED_CPUS"))
	consideredCPUs, err := strconv.Atoi(consideredCPUsStr)
	if err != nil {
		return fmt.Errorf("invalid CONSIDERED_CPUS value: %s", consideredCPUsStr)
	}

	_, err = tx.Exec(`
		INSERT INTO measurements (
			main_fqdn, detection_timestamp, session_directory,
			os_name, os_version, cpu_count,
			is_virtualized, virt_type, processor_vendor, processor_brand,
			host_physical_cpus, partition_cpus,
			processor_eligible, os_eligible, virt_eligible,
			considered_cpus, physical_host_id, host_id_method, host_id_confidence
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		mainFQDN,
		record.Timestamp,
		record.GetSystemField("session_directory"),
		record.GetSystemField("OS_NAME"),
		record.GetSystemField("OS_VERSION"),
		cpuCount,
		record.GetSystemField("IS_VIRTUALIZED"),
		record.GetSystemField("VIRT_TYPE"),
		record.GetSystemField("PROCESSOR_VENDOR"),
		record.GetSystemField("PROCESSOR_BRAND"),
		record.GetSystemFieldWithDefault("HOST_PHYSICAL_CPUS", "unknown"),
		record.GetSystemField("PARTITION_CPUS"),
		record.GetSystemFieldWithDefault("PROCESSOR_ELIGIBLE", "unknown"),
		record.GetSystemFieldWithDefault("OS_ELIGIBLE", "unknown"),
		record.GetSystemFieldWithDefault("VIRT_ELIGIBLE", "unknown"),
		consideredCPUs,
		record.GetSystemField("PHYSICAL_HOST_ID"),
		record.GetSystemField("HOST_ID_METHOD"),
		record.GetSystemField("HOST_ID_CONFIDENCE"),
	)

	if err != nil {
		return fmt.Errorf("failed to insert measurement: %w", err)
	}

	return nil
}

// insertDetectedProduct inserts a detected product record
func (s *ImportService) insertDetectedProduct(tx *sql.Tx, mainFQDN string, timestamp time.Time, detection *ProductDetection) error {
	_, err := tx.Exec(`
		INSERT INTO detected_products (
			main_fqdn, product_mnemo_code, detection_timestamp,
			status, install_count
		) VALUES (?, ?, ?, ?, ?)
	`,
		mainFQDN,
		detection.ProductCode,
		timestamp,
		detection.Status,
		detection.InstallCount,
	)

	if err != nil {
		return fmt.Errorf("failed to insert detected product: %w", err)
	}

	return nil
}

// insertImportSession records the import session
func (s *ImportService) insertImportSession(tx *sql.Tx, record *CSVRecord, result *ImportResult) error {
	status := "success"
	if len(result.Errors) > 0 {
		status = "partial"
	}

	errorMessage := ""
	if len(result.Errors) > 0 {
		errorMessage = strings.Join(result.Errors, "; ")
	}

	_, err := tx.Exec(`
		INSERT INTO import_sessions (
			session_id, source_file, hostname,
			records_created, records_updated, records_skipped,
			status, error_message
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`,
		result.SessionID,
		record.SourceFile,
		record.Hostname,
		result.RecordsCreated,
		result.RecordsUpdated,
		result.RecordsSkipped,
		status,
		errorMessage,
	)

	if err != nil {
		return fmt.Errorf("failed to insert import session: %w", err)
	}

	return nil
}

// generateSessionID creates a unique session ID from hostname and timestamp
func generateSessionID(hostname string, timestamp time.Time) string {
	return hostname + "_" + timestamp.Format("20060102_150405")
}
