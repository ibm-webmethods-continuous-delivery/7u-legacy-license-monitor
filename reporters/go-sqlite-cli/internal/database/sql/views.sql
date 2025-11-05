-- Reporting Views for IBM webMethods License Monitor
-- Version: 1.2.0
-- Last Updated: 2025-10-31
--
-- These views provide various aggregations and reports for license monitoring

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
        -- For physical hosts (non-virtualized), use cpu_count as physical cores
        WHEN m.is_virtualized = 'no' THEN m.cpu_count
        -- For VMs, use host_physical_cpus if available
        WHEN m.host_physical_cpus = 'unknown' OR m.host_physical_cpus = '' THEN NULL
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

-- View 2: Daily Product Summary (CORRECTED)
-- Daily rollup per product across all nodes
-- Requirements:
--   a) Running products: count virtual and physical cores once per host per day
--   b) Installed products: count cores based on install_count
--   c) Multiple datapoints same day: count cores once (use MAX timestamp)
--   d) Physical host deduplication: count physical cores once per physical host
CREATE VIEW IF NOT EXISTS v_daily_product_summary AS
WITH latest_daily_measurements AS (
    -- Get latest measurement per host per day (requirement c)
    SELECT 
        DATE(m.detection_timestamp) as measurement_date,
        m.main_fqdn,
        MAX(m.detection_timestamp) as latest_timestamp
    FROM measurements m
    GROUP BY DATE(m.detection_timestamp), m.main_fqdn
),
running_cores AS (
    -- For RUNNING products (status='present')
    SELECT 
        ldm.measurement_date,
        p.product_mnemo_code,
        p.product_name,
        p.mode,
        l.term_id,
        l.program_number,
        l.program_name,
        -- Virtual cores for running products
        SUM(CASE 
            WHEN m.is_virtualized = 'yes' THEN m.cpu_count
            ELSE 0
        END) as running_vcores,
        -- Physical cores for running products (with deduplication)
        -- For virtualized hosts with same physical_host_id, count once
        COUNT(DISTINCT CASE 
            WHEN m.is_virtualized = 'yes' AND m.physical_host_id != '' AND m.physical_host_id != 'unknown'
            THEN m.physical_host_id
        END) as running_unique_phys_hosts,
        -- Physical cores for non-virtualized running products
        SUM(CASE 
            WHEN m.is_virtualized = 'no' THEN m.cpu_count
            ELSE 0
        END) as running_physical_cores,
        COUNT(DISTINCT d.main_fqdn) as running_node_count
    FROM latest_daily_measurements ldm
    JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
        AND ldm.latest_timestamp = m.detection_timestamp
    JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
        AND m.detection_timestamp = d.detection_timestamp
    JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
    JOIN license_terms l ON p.term_id = l.term_id
    WHERE d.status = 'present'
    GROUP BY ldm.measurement_date, p.product_mnemo_code, p.product_name, p.mode,
             l.term_id, l.program_number, l.program_name
),
installed_cores AS (
    -- For INSTALLED products (install_count > 0)
    SELECT 
        ldm.measurement_date,
        p.product_mnemo_code,
        p.product_name,
        p.mode,
        l.term_id,
        l.program_number,
        l.program_name,
        SUM(d.install_count) as total_installs,
        -- Virtual cores for installed products
        SUM(CASE 
            WHEN m.is_virtualized = 'yes' AND d.install_count > 0 THEN m.cpu_count
            ELSE 0
        END) as installed_vcores,
        -- Physical cores for installed products (with deduplication)
        COUNT(DISTINCT CASE 
            WHEN m.is_virtualized = 'yes' AND d.install_count > 0 
                AND m.physical_host_id != '' AND m.physical_host_id != 'unknown'
            THEN m.physical_host_id
        END) as installed_unique_phys_hosts,
        -- Physical cores for non-virtualized installed products
        SUM(CASE 
            WHEN m.is_virtualized = 'no' AND d.install_count > 0 THEN m.cpu_count
            ELSE 0
        END) as installed_physical_cores,
        COUNT(DISTINCT CASE WHEN d.install_count > 0 THEN d.main_fqdn END) as installed_node_count
    FROM latest_daily_measurements ldm
    JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
        AND ldm.latest_timestamp = m.detection_timestamp
    JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
        AND m.detection_timestamp = d.detection_timestamp
    JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
    JOIN license_terms l ON p.term_id = l.term_id
    WHERE d.install_count > 0
    GROUP BY ldm.measurement_date, p.product_mnemo_code, p.product_name, p.mode,
             l.term_id, l.program_number, l.program_name
),
physical_host_cores AS (
    -- Get actual physical cores per physical host (for requirement d)
    SELECT 
        DATE(m.detection_timestamp) as measurement_date,
        m.physical_host_id,
        MAX(CASE 
            WHEN m.host_physical_cpus != 'unknown' AND m.host_physical_cpus != ''
            THEN CAST(m.host_physical_cpus AS INTEGER)
            ELSE NULL
        END) as max_physical_cores
    FROM measurements m
    WHERE m.physical_host_id != '' AND m.physical_host_id != 'unknown'
    GROUP BY DATE(m.detection_timestamp), m.physical_host_id
),
running_phys_hosts_detail AS (
    -- Get physical hosts for running products with their actual cores
    SELECT 
        ldm.measurement_date,
        p.product_mnemo_code,
        m.physical_host_id,
        phc.max_physical_cores
    FROM latest_daily_measurements ldm
    JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
        AND ldm.latest_timestamp = m.detection_timestamp
    JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
        AND m.detection_timestamp = d.detection_timestamp
    JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
    LEFT JOIN physical_host_cores phc ON ldm.measurement_date = phc.measurement_date
        AND m.physical_host_id = phc.physical_host_id
    WHERE d.status = 'present' 
        AND m.is_virtualized = 'yes'
        AND m.physical_host_id != '' AND m.physical_host_id != 'unknown'
    GROUP BY ldm.measurement_date, p.product_mnemo_code, m.physical_host_id, phc.max_physical_cores
),
running_phys_cores_sum AS (
    -- Sum actual physical cores for running products (requirement d: count once)
    SELECT 
        measurement_date,
        product_mnemo_code,
        SUM(COALESCE(max_physical_cores, 0)) as running_physical_cores_from_hosts
    FROM running_phys_hosts_detail
    GROUP BY measurement_date, product_mnemo_code
),
installed_phys_hosts_detail AS (
    -- Get physical hosts for installed products with their actual cores
    SELECT 
        ldm.measurement_date,
        p.product_mnemo_code,
        m.physical_host_id,
        phc.max_physical_cores
    FROM latest_daily_measurements ldm
    JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
        AND ldm.latest_timestamp = m.detection_timestamp
    JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
        AND m.detection_timestamp = d.detection_timestamp
    JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
    LEFT JOIN physical_host_cores phc ON ldm.measurement_date = phc.measurement_date
        AND m.physical_host_id = phc.physical_host_id
    WHERE d.install_count > 0
        AND m.is_virtualized = 'yes'
        AND m.physical_host_id != '' AND m.physical_host_id != 'unknown'
    GROUP BY ldm.measurement_date, p.product_mnemo_code, m.physical_host_id, phc.max_physical_cores
),
installed_phys_cores_sum AS (
    -- Sum actual physical cores for installed products (requirement d: count once)
    SELECT 
        measurement_date,
        product_mnemo_code,
        SUM(COALESCE(max_physical_cores, 0)) as installed_physical_cores_from_hosts
    FROM installed_phys_hosts_detail
    GROUP BY measurement_date, product_mnemo_code
)
SELECT 
    COALESCE(rc.measurement_date, ic.measurement_date) as measurement_date,
    COALESCE(rc.product_mnemo_code, ic.product_mnemo_code) as product_mnemo_code,
    pc.ibm_product_code,
    COALESCE(rc.product_name, ic.product_name) as product_name,
    COALESCE(rc.mode, ic.mode) as mode,
    COALESCE(rc.term_id, ic.term_id) as term_id,
    COALESCE(rc.program_number, ic.program_number) as program_number,
    COALESCE(rc.program_name, ic.program_name) as program_name,
    -- Running products
    COALESCE(rc.running_node_count, 0) as running_node_count,
    COALESCE(rc.running_vcores, 0) as running_vcores,
    COALESCE(rc.running_physical_cores, 0) as running_physical_cores_direct,
    COALESCE(rc.running_unique_phys_hosts, 0) as running_unique_phys_hosts,
    COALESCE(rpcs.running_physical_cores_from_hosts, 0) as running_physical_cores_from_hosts,
    -- Installed products
    COALESCE(ic.total_installs, 0) as total_installs,
    COALESCE(ic.installed_node_count, 0) as installed_node_count,
    COALESCE(ic.installed_vcores, 0) as installed_vcores,
    COALESCE(ic.installed_physical_cores, 0) as installed_physical_cores_direct,
    COALESCE(ic.installed_unique_phys_hosts, 0) as installed_unique_phys_hosts,
    COALESCE(ipcs.installed_physical_cores_from_hosts, 0) as installed_physical_cores_from_hosts
FROM running_cores rc
FULL OUTER JOIN installed_cores ic 
    ON rc.measurement_date = ic.measurement_date
    AND rc.product_mnemo_code = ic.product_mnemo_code
LEFT JOIN product_codes pc
    ON COALESCE(rc.product_mnemo_code, ic.product_mnemo_code) = pc.product_mnemo_code
LEFT JOIN running_phys_cores_sum rpcs
    ON COALESCE(rc.measurement_date, ic.measurement_date) = rpcs.measurement_date
    AND COALESCE(rc.product_mnemo_code, ic.product_mnemo_code) = rpcs.product_mnemo_code
LEFT JOIN installed_phys_cores_sum ipcs
    ON COALESCE(rc.measurement_date, ic.measurement_date) = ipcs.measurement_date
    AND COALESCE(rc.product_mnemo_code, ic.product_mnemo_code) = ipcs.product_mnemo_code
ORDER BY measurement_date DESC, product_name;

-- View 3: Physical Host Cores Aggregated
-- Proper physical host aggregation (prevents double-counting)
-- Shows one row per physical host per day with actual physical cores
CREATE VIEW IF NOT EXISTS v_physical_host_cores_aggregated AS
WITH latest_daily_measurements AS (
    SELECT 
        DATE(m.detection_timestamp) as measurement_date,
        m.main_fqdn,
        MAX(m.detection_timestamp) as latest_timestamp
    FROM measurements m
    GROUP BY DATE(m.detection_timestamp), m.main_fqdn
)
SELECT 
    ldm.measurement_date,
    ph.physical_host_id,
    ph.host_id_method,
    ph.host_id_confidence,
    ph.max_physical_cpus as physical_cores,
    COUNT(DISTINCT m.main_fqdn) as vm_count,
    GROUP_CONCAT(DISTINCT m.main_fqdn) as vm_list,
    -- Aggregate VM cores
    SUM(m.cpu_count) as total_vm_cores,
    -- Latest timestamp for this physical host
    MAX(m.detection_timestamp) as latest_measurement
FROM latest_daily_measurements ldm
JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
    AND ldm.latest_timestamp = m.detection_timestamp
JOIN physical_hosts ph ON m.physical_host_id = ph.physical_host_id
WHERE m.physical_host_id != '' AND m.physical_host_id != 'unknown'
GROUP BY ldm.measurement_date, ph.physical_host_id, ph.host_id_method, 
         ph.host_id_confidence, ph.max_physical_cpus
ORDER BY ldm.measurement_date DESC, ph.physical_host_id;

-- View 3b: Physical Host Cores for Product Summary (Helper)
-- Maps physical hosts to products with actual physical cores
CREATE VIEW IF NOT EXISTS v_product_physical_cores AS
WITH latest_daily_measurements AS (
    SELECT 
        DATE(m.detection_timestamp) as measurement_date,
        m.main_fqdn,
        MAX(m.detection_timestamp) as latest_timestamp
    FROM measurements m
    GROUP BY DATE(m.detection_timestamp), m.main_fqdn
)
SELECT 
    ldm.measurement_date,
    p.product_mnemo_code,
    m.physical_host_id,
    ph.max_physical_cpus,
    d.status,
    d.install_count
FROM latest_daily_measurements ldm
JOIN measurements m ON ldm.main_fqdn = m.main_fqdn 
    AND ldm.latest_timestamp = m.detection_timestamp
JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
    AND m.detection_timestamp = d.detection_timestamp
JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
LEFT JOIN physical_hosts ph ON m.physical_host_id = ph.physical_host_id
WHERE m.physical_host_id != '' AND m.physical_host_id != 'unknown'
ORDER BY ldm.measurement_date DESC, p.product_mnemo_code;

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

-- View 5: Host Detail Report
-- Detailed host-level view showing product detection and system information
CREATE VIEW IF NOT EXISTS v_host_detail AS
SELECT 
    m.main_fqdn as host_fqdn,
    DATE(m.detection_timestamp) as date,
    CASE WHEN m.is_virtualized = 'yes' THEN 'true' ELSE 'false' END as virtual,
    d.product_mnemo_code as product_code,
    CASE WHEN d.status = 'present' THEN 'true' ELSE 'false' END as running,
    CASE WHEN d.install_count > 0 THEN 'true' ELSE 'false' END as installed,
    m.cpu_count as virtual_cpus,
    CASE 
        WHEN m.physical_host_id = '' OR m.physical_host_id = 'unknown' THEN NULL
        ELSE m.physical_host_id
    END as physical_host_id,
    CASE 
        WHEN m.host_physical_cpus = '' OR m.host_physical_cpus = 'unknown' THEN NULL
        ELSE CAST(m.host_physical_cpus AS INTEGER)
    END as physical_cpus,
    m.os_name || ' ' || m.os_version as operating_system,
    m.os_eligible as eligible_os,
    m.virt_eligible as eligible_virtualization
FROM measurements m
JOIN detected_products d ON m.main_fqdn = d.main_fqdn 
    AND m.detection_timestamp = d.detection_timestamp
ORDER BY date DESC, host_fqdn, product_code;

-- View 6: Peak Usage Summary
-- Shows maximum usage per product over last 31 days
-- Properly calculates: MAX per host per day, then SUM with physical host deduplication
CREATE VIEW IF NOT EXISTS v_peak_usage AS
WITH daily_host_peaks AS (
    -- Step 1: For each host/day/product, take the MAX of all measurements
    SELECT 
        DATE(m.detection_timestamp) as measurement_date,
        p.product_mnemo_code,
        p.ibm_product_code,
        p.product_name,
        p.mode,
        l.term_id,
        l.program_number,
        l.program_name,
        d.main_fqdn,
        d.status,
        d.install_count,
        m.physical_host_id,
        m.host_physical_cpus,
        MAX(m.considered_cpus) as max_considered_cpus,
        MAX(CASE WHEN m.is_virtualized = 'yes' THEN m.cpu_count ELSE 0 END) as max_vcores,
        MAX(CASE WHEN m.is_virtualized = 'no' THEN m.cpu_count ELSE 0 END) as max_physical_cores,
        MAX(CASE 
            WHEN m.os_eligible = 'true' AND m.virt_eligible = 'true' 
            THEN m.considered_cpus 
            ELSE 0 
        END) as max_eligible_cores,
        MAX(CASE 
            WHEN m.os_eligible = 'false' OR m.virt_eligible = 'false' 
            THEN m.considered_cpus 
            ELSE 0 
        END) as max_ineligible_cores,
        -- Track actual VM cores for comparison (regardless of eligibility)
        MAX(m.cpu_count) as max_actual_cores
    FROM detected_products d
    JOIN product_codes p ON d.product_mnemo_code = p.product_mnemo_code
    JOIN license_terms l ON p.term_id = l.term_id
    JOIN measurements m ON d.main_fqdn = m.main_fqdn 
        AND d.detection_timestamp = m.detection_timestamp
    WHERE DATE(m.detection_timestamp) >= DATE('now', '-31 days')
    GROUP BY DATE(m.detection_timestamp), p.product_mnemo_code, p.ibm_product_code, 
             p.product_name, p.mode, l.term_id, l.program_number, l.program_name,
             d.main_fqdn, d.status, d.install_count, m.physical_host_id, m.host_physical_cpus
),
daily_product_totals AS (
    -- Step 2: Sum host peaks per day per product WITH physical host deduplication
    SELECT 
        measurement_date,
        product_mnemo_code,
        ibm_product_code,
        product_name,
        mode,
        term_id,
        program_number,
        program_name,
        -- For eligible cores: direct sum (no physical host deduplication needed)
        SUM(CASE WHEN status = 'present' AND max_eligible_cores > 0 THEN max_eligible_cores ELSE 0 END) as running_eligible,
        -- For ineligible cores on running VMs: use physical host cores, deduplicated
        -- We group by physical_host_id and take MAX to avoid double-counting
        (SELECT SUM(phys_cores)
         FROM (
             SELECT DISTINCT 
                 physical_host_id,
                 CASE 
                     WHEN host_physical_cpus != 'unknown' THEN CAST(host_physical_cpus AS INTEGER)
                     ELSE MAX(max_ineligible_cores)
                 END as phys_cores
             FROM daily_host_peaks dhp_inner
             WHERE dhp_inner.measurement_date = daily_host_peaks.measurement_date
               AND dhp_inner.product_mnemo_code = daily_host_peaks.product_mnemo_code
               AND dhp_inner.status = 'present'
               AND dhp_inner.max_ineligible_cores > 0
             GROUP BY physical_host_id, host_physical_cpus
         )
        ) as running_ineligible,
        -- Node counts
        COUNT(DISTINCT CASE WHEN status = 'present' THEN main_fqdn END) as running_nodes,
        COUNT(DISTINCT CASE WHEN install_count > 0 THEN main_fqdn END) as installed_nodes,
        -- Actual virtual cores (regardless of eligibility) - direct sum
        SUM(CASE WHEN status = 'present' THEN max_actual_cores ELSE 0 END) as running_actual_cores
    FROM daily_host_peaks
    GROUP BY measurement_date, product_mnemo_code, ibm_product_code, product_name, 
             mode, term_id, program_number, program_name
)
SELECT 
    product_mnemo_code,
    ibm_product_code,
    product_name,
    mode,
    term_id,
    program_number,
    program_name,
    -- Peak running cores (MAX across all days) - sum of eligible + ineligible with deduplication
    MAX(running_eligible + COALESCE(running_ineligible, 0)) as peak_running_vcores,
    0 as peak_running_physical_cores,
    MAX(running_eligible + COALESCE(running_ineligible, 0)) as peak_running_total_cores,
    -- Peak installed - simplified for now
    0 as peak_installed_vcores,
    0 as peak_installed_physical_cores,
    0 as peak_installed_total_cores,
    -- Peak nodes
    MAX(running_nodes) as peak_running_nodes,
    MAX(installed_nodes) as peak_installed_nodes,
    -- Peak eligible/ineligible
    MAX(running_eligible) as peak_eligible_cores,
    MAX(COALESCE(running_ineligible, 0)) as peak_ineligible_cores,
    -- Peak actual virtual cores (regardless of eligibility) for comparison
    MAX(running_actual_cores) as peak_actual_vcores,
    -- Date when peak occurred (for running total cores)
    (SELECT measurement_date 
     FROM daily_product_totals dpt2 
     WHERE dpt2.product_mnemo_code = daily_product_totals.product_mnemo_code 
     ORDER BY (running_eligible + COALESCE(running_ineligible, 0)) DESC 
     LIMIT 1) as peak_date
FROM daily_product_totals
GROUP BY product_mnemo_code, ibm_product_code, product_name, mode,
         term_id, program_number, program_name
ORDER BY MAX(running_eligible + COALESCE(running_ineligible, 0)) DESC, product_mnemo_code;

-- View 7: Peak Usage Breakdown
-- Shows daily breakdown for a product with host-level details
-- Properly calculates: MAX per host per day (one row per host showing peak)
-- Applies physical host deduplication when calculating daily totals
CREATE VIEW IF NOT EXISTS v_peak_usage_breakdown AS
WITH daily_host_peaks AS (
    -- Step 1: For each host/day/product, take the MAX of all measurements
    -- This collapses multiple measurements per host down to one peak value
    SELECT 
        measurement_date,
        product_mnemo_code,
        main_fqdn,
        -- Take first hostname (they should all be same for a main_fqdn)
        MIN(hostname) as hostname,
        MAX(vm_cores) as max_vm_cores,
        MAX(license_cores) as max_license_cores,
        MAX(eligible_cores) as max_eligible_cores,
        MAX(ineligible_cores) as max_ineligible_cores,
        MIN(physical_host_id) as physical_host_id,
        MIN(physical_host_cores) as physical_host_cores,
        -- Keep first values for descriptive fields
        MIN(processor_eligible) as processor_eligible,
        MIN(os_eligible) as os_eligible,
        MIN(virt_eligible) as virt_eligible,
        MIN(product_status) as product_status,
        MAX(install_count) as install_count,
        MIN(os_name) as os_name,
        MIN(os_version) as os_version,
        MIN(is_virtualized) as is_virtualized,
        COUNT(*) as instance_count
    FROM v_core_aggregation_by_product
    WHERE measurement_date >= DATE('now', '-31 days')
      AND product_status = 'present'
    GROUP BY measurement_date, product_mnemo_code, main_fqdn
),
daily_product_totals_dedup AS (
    -- Step 2: Calculate daily totals WITH physical host deduplication
    SELECT DISTINCT
        measurement_date,
        product_mnemo_code,
        -- For eligible cores: direct sum (no physical host deduplication needed)
        (SELECT SUM(max_eligible_cores)
         FROM daily_host_peaks dhp_inner
         WHERE dhp_inner.measurement_date = daily_host_peaks.measurement_date
           AND dhp_inner.product_mnemo_code = daily_host_peaks.product_mnemo_code
        ) as total_eligible,
        -- For ineligible cores: use physical host cores, deduplicated
        (SELECT SUM(phys_cores)
         FROM (
             SELECT DISTINCT 
                 physical_host_id,
                 CASE 
                     WHEN physical_host_cores != 'unknown' THEN CAST(physical_host_cores AS INTEGER)
                     ELSE MAX(max_ineligible_cores)
                 END as phys_cores
             FROM daily_host_peaks dhp_inner
             WHERE dhp_inner.measurement_date = daily_host_peaks.measurement_date
               AND dhp_inner.product_mnemo_code = daily_host_peaks.product_mnemo_code
               AND dhp_inner.max_ineligible_cores > 0
             GROUP BY physical_host_id, physical_host_cores
         )
        ) as total_ineligible,
        -- Node count
        COUNT(DISTINCT main_fqdn) as total_nodes
    FROM daily_host_peaks
    GROUP BY measurement_date, product_mnemo_code
)
SELECT 
    hp.measurement_date,
    hp.product_mnemo_code,
    p.ibm_product_code,
    p.product_name,
    p.mode,
    hp.main_fqdn,
    hp.hostname,
    hp.max_vm_cores as vm_cores,
    hp.max_license_cores as license_cores,
    hp.physical_host_id,
    hp.physical_host_cores,
    hp.max_eligible_cores as eligible_cores,
    hp.max_ineligible_cores as ineligible_cores,
    hp.processor_eligible,
    hp.os_eligible,
    hp.virt_eligible,
    hp.product_status,
    hp.install_count,
    hp.instance_count,
    hp.os_name,
    hp.os_version,
    hp.is_virtualized,
    -- Daily total for this product (sum with physical host deduplication)
    dt.total_eligible + COALESCE(dt.total_ineligible, 0) as daily_running_total,
    dt.total_nodes as daily_running_nodes,
    -- Flag indicating if this host's ineligible cores are deduplicated (not counted)
    -- A host is deduplicated if it has ineligible cores AND it's not the first occurrence of its physical_host_id
    CASE 
        WHEN hp.max_ineligible_cores > 0 
         AND hp.physical_host_id != ''
         AND hp.main_fqdn != (
             SELECT MIN(main_fqdn) 
             FROM daily_host_peaks dhp2
             WHERE dhp2.measurement_date = hp.measurement_date
               AND dhp2.product_mnemo_code = hp.product_mnemo_code
               AND dhp2.physical_host_id = hp.physical_host_id
               AND dhp2.max_ineligible_cores > 0
         )
        THEN hp.max_ineligible_cores
        ELSE 0
    END as deduplicated_cores
FROM daily_host_peaks hp
JOIN product_codes p ON hp.product_mnemo_code = p.product_mnemo_code
JOIN daily_product_totals_dedup dt 
    ON hp.product_mnemo_code = dt.product_mnemo_code 
    AND hp.measurement_date = dt.measurement_date
ORDER BY hp.measurement_date DESC, hp.product_mnemo_code, hp.max_license_cores DESC;
