# SQL Files Directory

This directory contains the SQL DDL statements for the license monitor database.

## Files

### schema.sql
Complete database schema including:
- Tables (license_terms, product_codes, landscape_nodes, physical_hosts, measurements, detected_products, import_sessions)
- Indexes for performance
- Basic helper view (v_latest_measurements)

**Version:** 1.2.0

### views.sql
Reporting views for license monitoring analysis:
- `v_core_aggregation_by_product` - Daily core counts per product with eligibility breakdown
- `v_daily_product_summary` - Daily rollup per product across all nodes (with physical host deduplication)
- `v_physical_host_cores_aggregated` - Physical host aggregation (prevents double-counting)
- `v_product_physical_cores` - Maps physical hosts to products with actual physical cores
- `v_license_compliance_report` - Complete compliance report with proper core counting
- `v_host_detail` - Detailed host-level view showing product detection and system information

**Version:** 1.2.0

## Usage in Code

These SQL files are embedded into the Go binary using `//go:embed` directives:

```go
//go:embed sql/schema.sql
var SchemaSQL string

//go:embed sql/views.sql
var ViewsSQL string
```

## Benefits

1. **IDE Support**: SQL files get syntax highlighting and linting in the IDE
2. **Version Control**: Easier to review SQL changes in diffs
3. **Maintainability**: Separate SQL from Go code makes both easier to read
4. **Tooling**: Can use SQL formatters, linters, and other tools directly on these files
5. **Documentation**: SQL comments are more visible and maintainable

## Schema Version

Current schema version: **1.2.0**

### Version History
- **1.2.0** (2025-10-31): Added ibm_product_code to v_daily_product_summary view; moved SQL to separate files
- **1.1.0** (2025-10-31): Added running_status, running_count, install_status fields to detected_products
- **1.0.0** (2025-10-21): Initial schema

## Notes

- Always drop and reload database from scratch when schema changes (see RULES.md)
- No migration tools needed during active development
- Schema version is informational only
