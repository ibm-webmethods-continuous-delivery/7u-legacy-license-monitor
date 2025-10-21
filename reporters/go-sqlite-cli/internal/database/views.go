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

package database

// ViewsSQL contains all reporting views for license monitoring
const ViewsSQL = `
-- View 1: Core Aggregation by Product
-- Shows daily core counts per product with eligibility breakdown
CREATE VIEW IF NOT EXISTS v_core_aggregation_by_product AS
SELECT 
    DATE(m.detection_timestamp) as measurement_date,
    p.product_mnemo_code,
    p.product_name,
    p.mode,
    d.main_fqdn,
    n.hostname,
    -- VM/Partition cores
    m.cpu_count as vm_cores,
    CAST(m.partition_cpus AS INTEGER) as partition_cores,
    -- Eligibility flags
    m.processor_eligible,
    m.os_eligible,
    m.virt_eligible,
    -- Calculated cores for licensing
    m.considered_cpus as license_cores,
    -- Physical host details
    m.physical_host_id,
    CASE 
        WHEN m.host_physical_cpus = 'unknown' THEN NULL
        ELSE CAST(m.host_physical_cpus AS INTEGER)
    END as physical_host_cores,
    -- Breakdown: eligible vs ineligible
    CASE 
        WHEN m.os_eligible = 'true' AND m.virt_eligible = 'true' 
        THEN m.considered_cpus 
        ELSE 0 
    END as eligible_cores,
    CASE 
        WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false'
        THEN m.considered_cpus
        ELSE 0
    END as ineligible_cores,
    -- Product status
    d.status as product_status,
    d.install_count,
    -- Additional context
    m.is_virtualized,
    m.os_name,
    m.os_version
FROM detected_products d
JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
JOIN measurements m ON d.main_fqdn = m.main_fqdn 
    AND d.detection_timestamp = m.detection_timestamp
JOIN landscape_nodes n ON d.main_fqdn = n.main_fqdn
WHERE d.status = 'present'
ORDER BY measurement_date DESC, p.product_name, n.hostname;

-- View 2: Daily Product Summary
-- Daily rollup per product across all nodes
CREATE VIEW IF NOT EXISTS v_daily_product_summary AS
SELECT 
    DATE(m.detection_timestamp) as measurement_date,
    p.product_mnemo_code,
    p.product_name,
    p.mode,
    l.term_id,
    l.program_number,
    l.program_name,
    -- Counts
    COUNT(DISTINCT d.main_fqdn) as node_count,
    COUNT(DISTINCT CASE WHEN d.status = 'present' THEN d.main_fqdn END) as running_node_count,
    SUM(d.install_count) as total_installations,
    -- Core aggregation (simple sum - may double-count physical hosts)
    SUM(m.considered_cpus) as total_cores_simple,
    SUM(CASE WHEN m.os_eligible = 'true' AND m.virt_eligible = 'true' 
        THEN m.considered_cpus ELSE 0 END) as total_eligible_cores,
    SUM(CASE WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false'
        THEN m.considered_cpus ELSE 0 END) as total_ineligible_cores,
    -- Physical host awareness
    COUNT(DISTINCT m.physical_host_id) as unique_physical_hosts,
    -- Virtualization breakdown
    COUNT(DISTINCT CASE WHEN m.is_virtualized = 'yes' THEN m.main_fqdn END) as virtualized_nodes,
    COUNT(DISTINCT CASE WHEN m.is_virtualized = 'no' THEN m.main_fqdn END) as physical_nodes
FROM detected_products d
JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
JOIN license_terms l ON p.term_id = l.term_id
JOIN measurements m ON d.main_fqdn = m.main_fqdn 
    AND d.detection_timestamp = m.detection_timestamp
WHERE d.status = 'present'
GROUP BY measurement_date, p.product_mnemo_code, p.product_name, p.mode, 
         l.term_id, l.program_number, l.program_name
ORDER BY measurement_date DESC, p.product_name;

-- View 3: Physical Host Cores Aggregated
-- Proper physical host aggregation (prevents double-counting)
CREATE VIEW IF NOT EXISTS v_physical_host_cores_aggregated AS
SELECT 
    DATE(m.detection_timestamp) as measurement_date,
    ph.physical_host_id,
    ph.host_id_method,
    ph.host_id_confidence,
    ph.max_physical_cpus as physical_cores,
    COUNT(DISTINCT m.main_fqdn) as vm_count,
    GROUP_CONCAT(DISTINCT m.main_fqdn) as vm_list,
    -- Aggregate VM cores
    SUM(m.cpu_count) as total_vm_cores,
    -- For ineligible VMs on this host, we count physical cores once
    -- For eligible VMs, we sum their considered cores
    SUM(CASE 
        WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false' THEN 0
        ELSE m.considered_cpus 
    END) as eligible_vm_cores,
    -- Check if any VM is ineligible
    MAX(CASE 
        WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false' THEN 1 
        ELSE 0 
    END) as has_ineligible_vm,
    -- Latest timestamp
    MAX(m.detection_timestamp) as latest_measurement
FROM physical_hosts ph
JOIN measurements m ON ph.physical_host_id = m.physical_host_id
WHERE m.physical_host_id != '' AND m.physical_host_id != 'unknown'
GROUP BY measurement_date, ph.physical_host_id, ph.host_id_method, 
         ph.host_id_confidence, ph.max_physical_cpus
ORDER BY measurement_date DESC, ph.physical_host_id;

-- View 4: License Compliance Report
-- Complete compliance report with proper core counting
CREATE VIEW IF NOT EXISTS v_license_compliance_report AS
SELECT 
    DATE(m.detection_timestamp) as measurement_date,
    p.product_mnemo_code,
    p.product_name,
    p.mode,
    l.term_id,
    l.program_number,
    l.program_name,
    -- Node counts
    COUNT(DISTINCT d.main_fqdn) as total_nodes,
    COUNT(DISTINCT CASE WHEN d.status = 'present' THEN d.main_fqdn END) as running_nodes,
    -- Installation counts
    SUM(d.install_count) as total_installations,
    -- Core breakdown
    SUM(m.cpu_count) as total_vm_cores,
    SUM(m.considered_cpus) as total_license_cores_raw,
    -- Eligible cores (sum of considered_cpus where eligible)
    SUM(CASE 
        WHEN m.os_eligible = 'true' AND m.virt_eligible = 'true' 
        THEN m.considered_cpus 
        ELSE 0 
    END) as eligible_cores_sum,
    -- Ineligible cores (these reference physical host)
    SUM(CASE 
        WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false'
        THEN m.considered_cpus 
        ELSE 0 
    END) as ineligible_cores_sum,
    -- Physical host details
    COUNT(DISTINCT CASE 
        WHEN m.physical_host_id != '' AND m.physical_host_id != 'unknown' 
        THEN m.physical_host_id 
    END) as unique_physical_hosts,
    -- Virtualization breakdown
    COUNT(DISTINCT CASE WHEN m.is_virtualized = 'yes' THEN m.main_fqdn END) as virtualized_nodes,
    COUNT(DISTINCT CASE WHEN m.is_virtualized = 'no' THEN m.main_fqdn END) as physical_nodes
FROM detected_products d
JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
JOIN license_terms l ON p.term_id = l.term_id
JOIN measurements m ON d.main_fqdn = m.main_fqdn 
    AND d.detection_timestamp = m.detection_timestamp
WHERE d.status = 'present'
GROUP BY measurement_date, p.product_mnemo_code, p.product_name, p.mode, 
         l.term_id, l.program_number, l.program_name
ORDER BY measurement_date DESC, p.product_name;
`

// CreateViews creates all reporting views
func CreateViews(db interface{ Exec(query string, args ...interface{}) (interface{}, error) }) error {
	_, err := db.Exec(ViewsSQL)
	return err
}
