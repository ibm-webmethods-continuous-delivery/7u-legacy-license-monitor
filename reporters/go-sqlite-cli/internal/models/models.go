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

package models

import "time"

// LicenseTerm represents IBM license terms and conditions
type LicenseTerm struct {
	TermID        string    `json:"term_id" db:"term_id"`
	ProgramNumber string    `json:"program_number" db:"program_number"`
	ProgramName   string    `json:"program_name" db:"program_name"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}

// ProductCode represents product code mappings to license terms
type ProductCode struct {
	ProductMnemoCode string    `json:"product_mnemo_code" db:"product_mnemo_code"`
	IBMProductCode   string    `json:"ibm_product_code" db:"ibm_product_code"`
	ProductName      string    `json:"product_name" db:"product_name"`
	Mode             string    `json:"mode" db:"mode"` // PROD or NON PROD
	TermID           string    `json:"term_id" db:"term_id"`
	Notes            string    `json:"notes" db:"notes"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// LandscapeNode represents a node in the landscape
type LandscapeNode struct {
	MainFQDN                 string    `json:"main_fqdn" db:"main_fqdn"`
	Hostname                 string    `json:"hostname" db:"hostname"`
	Mode                     string    `json:"mode" db:"mode"` // PROD or NON PROD
	ExpectedProductCodesList string    `json:"expected_product_codes_list" db:"expected_product_codes_list"`
	ExpectedCPUNo            *int      `json:"expected_cpu_no" db:"expected_cpu_no"`
	CreatedAt                time.Time `json:"created_at" db:"created_at"`
	UpdatedAt                time.Time `json:"updated_at" db:"updated_at"`
}

// PhysicalHost represents a physical host that may run multiple VMs
type PhysicalHost struct {
	PhysicalHostID   string    `json:"physical_host_id" db:"physical_host_id"`
	HostIDMethod     string    `json:"host_id_method" db:"host_id_method"`
	HostIDConfidence string    `json:"host_id_confidence" db:"host_id_confidence"`
	FirstSeen        time.Time `json:"first_seen" db:"first_seen"`
	LastSeen         time.Time `json:"last_seen" db:"last_seen"`
	MaxPhysicalCPUs  *int      `json:"max_physical_cpus" db:"max_physical_cpus"`
	Notes            string    `json:"notes" db:"notes"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// Measurement represents system measurements from an inspector run
type Measurement struct {
	MainFQDN           string    `json:"main_fqdn" db:"main_fqdn"`
	DetectionTimestamp time.Time `json:"detection_timestamp" db:"detection_timestamp"`
	SessionDirectory   string    `json:"session_directory" db:"session_directory"`
	NodeType           string    `json:"node_type" db:"node_type"`
	Environment        string    `json:"environment" db:"environment"`
	InspectionLevel    string    `json:"inspection_level" db:"inspection_level"`
	NodeFQDN           string    `json:"node_fqdn" db:"node_fqdn"`
	OSName             string    `json:"os_name" db:"os_name"`
	OSVersion          string    `json:"os_version" db:"os_version"`
	CPUCount           int       `json:"cpu_count" db:"cpu_count"`
	IsVirtualized      string    `json:"is_virtualized" db:"is_virtualized"`
	VirtType           string    `json:"virt_type" db:"virt_type"`
	ProcessorVendor    string    `json:"processor_vendor" db:"processor_vendor"`
	ProcessorBrand     string    `json:"processor_brand" db:"processor_brand"`
	HostPhysicalCPUs   string    `json:"host_physical_cpus" db:"host_physical_cpus"`
	PartitionCPUs      string    `json:"partition_cpus" db:"partition_cpus"`
	ProcessorEligible  string    `json:"processor_eligible" db:"processor_eligible"`
	OSEligible         string    `json:"os_eligible" db:"os_eligible"`
	VirtEligible       string    `json:"virt_eligible" db:"virt_eligible"`
	ConsideredCPUs     int       `json:"considered_cpus" db:"considered_cpus"`
	PhysicalHostID     string    `json:"physical_host_id" db:"physical_host_id"`
	HostIDMethod       string    `json:"host_id_method" db:"host_id_method"`
	HostIDConfidence   string    `json:"host_id_confidence" db:"host_id_confidence"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
}

// DetectedProduct represents a product detection result
type DetectedProduct struct {
	MainFQDN           string    `json:"main_fqdn" db:"main_fqdn"`
	ProductMnemoCode   string    `json:"product_mnemo_code" db:"product_mnemo_code"`
	DetectionTimestamp time.Time `json:"detection_timestamp" db:"detection_timestamp"`
	Status             string    `json:"status" db:"status"` // present or absent
	RunningStatus      string    `json:"running_status" db:"running_status"` // running, not-running, unknown
	RunningCount       int       `json:"running_count" db:"running_count"`
	InstallStatus      string    `json:"install_status" db:"install_status"` // installed, not-installed, unknown
	InstallCount       int       `json:"install_count" db:"install_count"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
}

// ImportSession tracks CSV import operations
type ImportSession struct {
	SessionID      string    `json:"session_id" db:"session_id"`
	ImportedAt     time.Time `json:"imported_at" db:"imported_at"`
	SourceFile     string    `json:"source_file" db:"source_file"`
	Hostname       string    `json:"hostname" db:"hostname"`
	RecordsCreated int       `json:"records_created" db:"records_created"`
	RecordsUpdated int       `json:"records_updated" db:"records_updated"`
	RecordsSkipped int       `json:"records_skipped" db:"records_skipped"`
	Status         string    `json:"status" db:"status"` // success, partial, failed
	ErrorMessage   string    `json:"error_message" db:"error_message"`
}

// SchemaMetadata represents database schema metadata
type SchemaMetadata struct {
	ID        int       `json:"id" db:"id"`
	Key       string    `json:"key" db:"key"`
	Value     string    `json:"value" db:"value"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
