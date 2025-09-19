# Legacy License Monitoring

This repository offers a way for webMethods users to continuously monitor their installation landscape with the purpose of checking the correct licenses utilization.
These tools are intended to be executed with versions prior to webMethods 11, that are not covered already by other means.

## Repository Structure

This is a multi-inspector, multi-reporter repository organized as follows:

- **`inspectors/`**: Contains different inspector implementations for various use cases
  - **`inspectors/default/`**: Primary webMethods license monitoring inspector
- **`reporters/`**: Contains reporting applications that aggregate inspector outputs  
  - **`reporters/go-sqlite-cli/`**: SQLite-based data aggregation and reporting (planned)

## Components

**Inspectors** are CLI applications that inspect the relevant parameters on every node hosting webMethods processes. **Reporters** are CLI applications that gather the information from the inspectors, centralize, interpret and produce aggregated reports.

### Default Inspector

The primary inspector (`inspectors/default/`) provides comprehensive system detection and license compliance checking for webMethods installations. See `REQUIREMENTS.md` for detailed documentation.

**Quick Start:**
```bash
cd inspectors/default
./common/detect_system_info.sh
```
