-- Database Schema for IBM webMethods License Monitor
-- Version: 1.3.0
-- Last Updated: 2025-10-31
--
-- Based on REQUIREMENTS.md data model for license monitoring

-- Schema metadata table
CREATE TABLE IF NOT EXISTS schema_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- License terms table
CREATE TABLE IF NOT EXISTS license_terms (
    term_id TEXT PRIMARY KEY,
    program_number TEXT NOT NULL,
    program_name TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Product codes table
CREATE TABLE IF NOT EXISTS product_codes (
    product_mnemo_code TEXT PRIMARY KEY,
    ibm_product_code TEXT NOT NULL,
    product_name TEXT NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('PROD', 'NON PROD')),
    term_id TEXT NOT NULL,
    notes TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (term_id) REFERENCES license_terms(term_id)
);

-- Landscape nodes table
CREATE TABLE IF NOT EXISTS landscape_nodes (
    main_fqdn TEXT PRIMARY KEY,
    hostname TEXT NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('PROD', 'NON PROD')),
    expected_product_codes_list TEXT DEFAULT '',
    expected_cpu_no INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Physical hosts table
CREATE TABLE IF NOT EXISTS physical_hosts (
    physical_host_id TEXT PRIMARY KEY,
    host_id_method TEXT NOT NULL,
    host_id_confidence TEXT NOT NULL CHECK (host_id_confidence IN ('high', 'medium', 'low')),
    first_seen DATETIME NOT NULL,
    last_seen DATETIME NOT NULL,
    max_physical_cpus INTEGER,
    notes TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Measurements table (system inspection results)
CREATE TABLE IF NOT EXISTS measurements (
    main_fqdn TEXT NOT NULL,
    detection_timestamp DATETIME NOT NULL,
    session_directory TEXT DEFAULT '',
    node_type TEXT DEFAULT 'PROD' CHECK (node_type IN ('PROD', 'NON_PROD')),
    environment TEXT DEFAULT 'Production',
    inspection_level TEXT DEFAULT 'full',
    node_fqdn TEXT DEFAULT '',
    os_name TEXT NOT NULL,
    os_version TEXT NOT NULL,
    cpu_count INTEGER NOT NULL,
    is_virtualized TEXT NOT NULL CHECK (is_virtualized IN ('yes', 'no', 'unknown')),
    virt_type TEXT DEFAULT '',
    processor_vendor TEXT DEFAULT '',
    processor_brand TEXT DEFAULT '',
    host_physical_cpus TEXT DEFAULT 'unknown',
    partition_cpus TEXT DEFAULT '',
    processor_eligible TEXT NOT NULL CHECK (processor_eligible IN ('true', 'false', 'unknown')),
    os_eligible TEXT NOT NULL CHECK (os_eligible IN ('true', 'false', 'unknown')),
    virt_eligible TEXT NOT NULL CHECK (virt_eligible IN ('true', 'false', 'unknown')),
    considered_cpus INTEGER NOT NULL,
    physical_host_id TEXT DEFAULT '',
    host_id_method TEXT DEFAULT '',
    host_id_confidence TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (main_fqdn, detection_timestamp),
    FOREIGN KEY (main_fqdn) REFERENCES landscape_nodes(main_fqdn)
);

-- Detected products table
CREATE TABLE IF NOT EXISTS detected_products (
    main_fqdn TEXT NOT NULL,
    product_mnemo_code TEXT NOT NULL,
    detection_timestamp DATETIME NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent')),
    running_status TEXT DEFAULT 'unknown' CHECK (running_status IN ('running', 'not-running', 'unknown')),
    running_count INTEGER DEFAULT 0,
    install_status TEXT DEFAULT 'unknown' CHECK (install_status IN ('installed', 'not-installed', 'unknown')),
    install_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (main_fqdn, product_mnemo_code, detection_timestamp),
    FOREIGN KEY (main_fqdn) REFERENCES landscape_nodes(main_fqdn),
    FOREIGN KEY (product_mnemo_code) REFERENCES product_codes(product_mnemo_code)
);

-- Import sessions table (audit trail)
CREATE TABLE IF NOT EXISTS import_sessions (
    session_id TEXT PRIMARY KEY,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    source_file TEXT NOT NULL,
    hostname TEXT NOT NULL,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_skipped INTEGER DEFAULT 0,
    status TEXT NOT NULL CHECK (status IN ('success', 'partial', 'failed')),
    error_message TEXT DEFAULT ''
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_measurements_timestamp ON measurements(detection_timestamp);
CREATE INDEX IF NOT EXISTS idx_measurements_fqdn ON measurements(main_fqdn);
CREATE INDEX IF NOT EXISTS idx_measurements_physical_host ON measurements(physical_host_id);
CREATE INDEX IF NOT EXISTS idx_detected_products_timestamp ON detected_products(detection_timestamp);
CREATE INDEX IF NOT EXISTS idx_detected_products_status ON detected_products(status);
CREATE INDEX IF NOT EXISTS idx_product_codes_term ON product_codes(term_id);
CREATE INDEX IF NOT EXISTS idx_import_sessions_hostname ON import_sessions(hostname);
CREATE INDEX IF NOT EXISTS idx_import_sessions_timestamp ON import_sessions(imported_at);

-- View: Latest measurements for each node (helper view)
CREATE VIEW IF NOT EXISTS v_latest_measurements AS
SELECT m.*
FROM measurements m
INNER JOIN (
    SELECT main_fqdn, MAX(detection_timestamp) as max_timestamp
    FROM measurements
    GROUP BY main_fqdn
) latest ON m.main_fqdn = latest.main_fqdn 
    AND m.detection_timestamp = latest.max_timestamp;
