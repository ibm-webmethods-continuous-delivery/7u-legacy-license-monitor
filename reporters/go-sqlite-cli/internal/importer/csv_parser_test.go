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

package importer_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/importer"
)

func TestParseCSVFile(t *testing.T) {
	// Create test CSV file
	tmpDir := t.TempDir()
	csvPath := filepath.Join(tmpDir, "iwdli_output_testhost_20251021_090906.csv")

	csvContent := `Parameter,Value
detection_timestamp,2025-10-21T09:09:06Z
session_directory,/tmp/iwdlm/20251021_090906
OS_NAME,Solaris
OS_VERSION,8
CPU_COUNT,      16
IS_VIRTUALIZED,no
VIRT_TYPE,none
PROCESSOR_VENDOR,Oracle
PROCESSOR_BRAND,SPARC M7
HOST_PHYSICAL_CPUS,unknown
PARTITION_CPUS,unknown
PHYSICAL_HOST_ID,testhost
HOST_ID_METHOD,physical-hostname
HOST_ID_CONFIDENCE,high
PROCESSOR_ELIGIBLE,true
OS_ELIGIBLE,true
VIRT_ELIGIBLE,false
CONSIDERED_CPUS,      16
IS_ONP_PRD,absent
IS_ONP_PRD_IBM_PRODUCT_CODE,N/A
IS_ONP_PRD_INSTALL_STATUS,installed
IS_ONP_PRD_INSTALL_COUNT,      21
IS_ONP_PRD_INSTALL_PATHS,/app/webmethods/IS01/IntegrationServer;/app/webmethods/IS02/IntegrationServer
BRK_ONP_PRD,present
BRK_ONP_PRD_IBM_PRODUCT_CODE,D0YXVZX
BRK_ONP_PRD_INSTALL_STATUS,installed
BRK_ONP_PRD_INSTALL_COUNT,       1
BRK_ONP_PRD_INSTALL_PATHS,/app/webmethods/Broker
`

	err := os.WriteFile(csvPath, []byte(csvContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test CSV: %v", err)
	}

	// Parse CSV
	record, err := importer.ParseCSVFile(csvPath)
	if err != nil {
		t.Fatalf("ParseCSVFile failed: %v", err)
	}

	// Verify hostname extraction
	if record.Hostname != "testhost" {
		t.Errorf("Expected hostname 'testhost', got '%s'", record.Hostname)
	}

	// Verify timestamp parsing
	expectedTime := time.Date(2025, 10, 21, 9, 9, 6, 0, time.UTC)
	if !record.Timestamp.Equal(expectedTime) {
		t.Errorf("Expected timestamp %v, got %v", expectedTime, record.Timestamp)
	}

	// Verify system fields
	if record.GetSystemField("OS_NAME") != "Solaris" {
		t.Errorf("Expected OS_NAME 'Solaris', got '%s'", record.GetSystemField("OS_NAME"))
	}

	if record.GetSystemField("CPU_COUNT") != "16" {
		t.Errorf("Expected CPU_COUNT '16', got '%s'", record.GetSystemField("CPU_COUNT"))
	}

	// Verify product detections
	if len(record.ProductDetections) != 2 {
		t.Errorf("Expected 2 product detections, got %d", len(record.ProductDetections))
	}

	// Check IS_ONP_PRD
	isPrd, exists := record.ProductDetections["IS_ONP_PRD"]
	if !exists {
		t.Fatal("IS_ONP_PRD detection not found")
	}
	if isPrd.Status != "absent" {
		t.Errorf("Expected IS_ONP_PRD status 'absent', got '%s'", isPrd.Status)
	}
	if isPrd.InstallCount != 21 {
		t.Errorf("Expected IS_ONP_PRD install count 21, got %d", isPrd.InstallCount)
	}
	if len(isPrd.InstallPaths) != 2 {
		t.Errorf("Expected 2 install paths for IS_ONP_PRD, got %d", len(isPrd.InstallPaths))
	}

	// Check BRK_ONP_PRD
	brkPrd, exists := record.ProductDetections["BRK_ONP_PRD"]
	if !exists {
		t.Fatal("BRK_ONP_PRD detection not found")
	}
	if brkPrd.Status != "present" {
		t.Errorf("Expected BRK_ONP_PRD status 'present', got '%s'", brkPrd.Status)
	}
	if brkPrd.IBMProductCode != "D0YXVZX" {
		t.Errorf("Expected IBM product code 'D0YXVZX', got '%s'", brkPrd.IBMProductCode)
	}
	if brkPrd.InstallCount != 1 {
		t.Errorf("Expected BRK_ONP_PRD install count 1, got %d", brkPrd.InstallCount)
	}
}

func TestExtractHostnameFromFilename(t *testing.T) {
	tests := []struct {
		name         string
		filename     string
		wantHostname string
		wantError    bool
	}{
		{
			name:         "Valid filename",
			filename:     "iwdli_output_omis446_20251021_090906.csv",
			wantHostname: "omis446",
			wantError:    false,
		},
		{
			name:         "Valid filename with path",
			filename:     "/path/to/iwdli_output_it188aia_20251020_120000.csv",
			wantHostname: "it188aia",
			wantError:    false,
		},
		{
			name:         "Invalid filename format",
			filename:     "output_omis446_20251021.csv",
			wantHostname: "",
			wantError:    true,
		},
		{
			name:         "Missing timestamp",
			filename:     "iwdli_output_omis446.csv",
			wantHostname: "",
			wantError:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a dummy file if valid format expected
			if !tt.wantError {
				tmpDir := t.TempDir()
				testPath := filepath.Join(tmpDir, filepath.Base(tt.filename))
				os.WriteFile(testPath, []byte("Parameter,Value\ndetection_timestamp,2025-10-21T09:09:06Z"), 0644)
				tt.filename = testPath
			}

			record, err := importer.ParseCSVFile(tt.filename)
			
			if tt.wantError {
				if err == nil {
					t.Errorf("Expected error for filename '%s', got nil", tt.filename)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for filename '%s': %v", tt.filename, err)
				}
				if record.Hostname != tt.wantHostname {
					t.Errorf("Expected hostname '%s', got '%s'", tt.wantHostname, record.Hostname)
				}
			}
		})
	}
}

func TestParseProductField(t *testing.T) {
	tests := []struct {
		name          string
		parameter     string
		value         string
		productCode   string
		expectedField string
		expectedValue interface{}
	}{
		{
			name:          "Product status field",
			parameter:     "IS_ONP_PRD",
			value:         "present",
			productCode:   "IS_ONP_PRD",
			expectedField: "Status",
			expectedValue: "present",
		},
		{
			name:          "IBM product code",
			parameter:     "BRK_ONP_PRD_IBM_PRODUCT_CODE",
			value:         "D0YXVZX",
			productCode:   "BRK_ONP_PRD",
			expectedField: "IBMProductCode",
			expectedValue: "D0YXVZX",
		},
		{
			name:          "Install count",
			parameter:     "IS_ONP_PRD_INSTALL_COUNT",
			value:         "      21",
			productCode:   "IS_ONP_PRD",
			expectedField: "InstallCount",
			expectedValue: 21,
		},
		{
			name:          "Install paths",
			parameter:     "IS_ONP_PRD_INSTALL_PATHS",
			value:         "/path1;/path2;/path3",
			productCode:   "IS_ONP_PRD",
			expectedField: "InstallPaths",
			expectedValue: 3, // number of paths
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create CSV with single product field
			tmpDir := t.TempDir()
			csvPath := filepath.Join(tmpDir, "iwdli_output_test_20251021_090906.csv")

			csvContent := "Parameter,Value\ndetection_timestamp,2025-10-21T09:09:06Z\n" + tt.parameter + "," + tt.value

			err := os.WriteFile(csvPath, []byte(csvContent), 0644)
			if err != nil {
				t.Fatalf("Failed to create test CSV: %v", err)
			}

			record, err := importer.ParseCSVFile(csvPath)
			if err != nil {
				t.Fatalf("ParseCSVFile failed: %v", err)
			}

			detection, exists := record.ProductDetections[tt.productCode]
			if !exists {
				t.Fatalf("Product detection for '%s' not found", tt.productCode)
			}

			// Verify field value
			switch tt.expectedField {
			case "Status":
				if detection.Status != tt.expectedValue.(string) {
					t.Errorf("Expected Status '%s', got '%s'", tt.expectedValue, detection.Status)
				}
			case "IBMProductCode":
				if detection.IBMProductCode != tt.expectedValue.(string) {
					t.Errorf("Expected IBMProductCode '%s', got '%s'", tt.expectedValue, detection.IBMProductCode)
				}
			case "InstallCount":
				if detection.InstallCount != tt.expectedValue.(int) {
					t.Errorf("Expected InstallCount %d, got %d", tt.expectedValue, detection.InstallCount)
				}
			case "InstallPaths":
				if len(detection.InstallPaths) != tt.expectedValue.(int) {
					t.Errorf("Expected %d install paths, got %d", tt.expectedValue, len(detection.InstallPaths))
				}
			}
		})
	}
}

func TestGetSystemFieldWithDefault(t *testing.T) {
	tmpDir := t.TempDir()
	csvPath := filepath.Join(tmpDir, "iwdli_output_test_20251021_090906.csv")

	csvContent := `Parameter,Value
detection_timestamp,2025-10-21T09:09:06Z
OS_NAME,Linux
CPU_COUNT,8
`

	err := os.WriteFile(csvPath, []byte(csvContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test CSV: %v", err)
	}

	record, err := importer.ParseCSVFile(csvPath)
	if err != nil {
		t.Fatalf("ParseCSVFile failed: %v", err)
	}

	// Test existing field
	if record.GetSystemFieldWithDefault("OS_NAME", "unknown") != "Linux" {
		t.Error("GetSystemFieldWithDefault failed for existing field")
	}

	// Test non-existing field
	if record.GetSystemFieldWithDefault("MISSING_FIELD", "default") != "default" {
		t.Error("GetSystemFieldWithDefault failed for missing field")
	}
}
