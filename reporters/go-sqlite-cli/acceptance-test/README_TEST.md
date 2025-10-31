# Folder Workflow Test - Important Notes

## Running the Test

### Default Mode (Full Test Suite)
```bash
./test_folder_workflow.sh
```
Runs all 10 tests including Test 9 which **removes folders** to test auto-creation.

**Result**: Only 1 file in processed folder at the end.

### Preserve Mode (Keep All Processed Files)
```bash
./test_folder_workflow.sh --preserve
```
Runs tests 1-8 and 10, **skipping Test 9** to preserve all imported files.

**Result**: All 92 files remain in processed folder.

## Why Files Disappear in Default Mode

Test 9 (`test_folder_auto_creation`) intentionally:
1. **Deletes** all folders: `input/`, `processed/`, `discards/`
2. Recreates only `input/` with 1 test file
3. Runs import to verify folders are **auto-created**
4. This leaves only 1 file in processed folder

This is **correct behavior** to test the auto-creation feature!

## Database File Location

The database is created at:
```
reporters/go-sqlite-cli/acceptance-test/test-data/test-workflow.db
```

## Verifying the Database

The database is **NOT corrupted**. Here's how to verify:

### Check Integrity
```bash
cd reporters/go-sqlite-cli/acceptance-test
sqlite3 test-data/test-workflow.db "PRAGMA integrity_check;"
```
Should output: `ok`

### View Tables
```bash
sqlite3 test-data/test-workflow.db ".tables"
```

### Count Records
```bash
sqlite3 test-data/test-workflow.db "
SELECT 'Measurements:', COUNT(*) FROM measurements
UNION ALL
SELECT 'Products:', COUNT(*) FROM detected_products
UNION ALL
SELECT 'Physical Hosts:', COUNT(*) FROM physical_hosts;
"
```

Expected output (in preserve mode):
```
Measurements:|92
Products:|161
Physical Hosts:|5
```

### View Data with CLI
```bash
cd reporters/go-sqlite-cli/acceptance-test
../target/bin/seed-go-sqlite-api-static report daily-summary \
    --db-path test-data/test-workflow.db
```

## Common Issues

### Issue: "Database appears corrupted"
**Cause**: Your SQLite client might be trying to open the database while the test is running.

**Solution**: 
1. Wait for test to complete
2. Close and reopen your SQLite client
3. Verify with command line: `sqlite3 test-data/test-workflow.db ".tables"`

### Issue: "No files in processed folder"
**Cause**: Ran test in default mode which includes Test 9.

**Solution**: Run with `--preserve` flag:
```bash
./test_folder_workflow.sh --preserve
```

### Issue: "Database is locked"
**Cause**: Another process has the database open.

**Solution**:
1. Close any SQLite clients/tools
2. Run: `lsof test-data/test-workflow.db` to find processes
3. Kill those processes or close the tools

## File Counts by Test Mode

| Mode | Test 9 | Processed Files | Discard Files |
|------|--------|----------------|---------------|
| Default | Runs | 1 | 1 |
| Preserve (`--preserve`) | Skipped | 92 | 3 |

## Folder Structure After Test

```
acceptance-test/
└── test-data/
    ├── input/          (empty after import)
    ├── processed/      (92 files in preserve mode, 1 in default)
    ├── discards/       (3 files in preserve mode, 1 in default)
    └── test-workflow.db (208KB database)
```

## Inspecting Processed Files

```bash
# List all processed files
ls -1 test-data/processed/

# Count processed files
ls -1 test-data/processed/*.csv | wc -l

# View first few
ls -1 test-data/processed/*.csv | head -10

# Check a specific file
cat test-data/processed/iwdli_output_i4_20251021_090906.csv
```

## Database Size

Normal database size after full import:
- **92 measurements**: ~200-210 KB
- **161 detected products**
- **5 physical hosts**

If your database is significantly smaller, you may have run default mode (Test 9 clears data).

## Recommendation

**For development/inspection**: Always use `--preserve` mode
```bash
./test_folder_workflow.sh --preserve
```

**For CI/automated testing**: Use default mode (full test suite)
```bash
./test_folder_workflow.sh
```

## Viewing Reports

After running test with `--preserve`:

```bash
# Table format
../target/bin/seed-go-sqlite-api-static report daily-summary \
    --db-path test-data/test-workflow.db

# CSV export
../target/bin/seed-go-sqlite-api-static report daily-summary \
    --db-path test-data/test-workflow.db \
    --format csv \
    --output /tmp/report.csv

# Specific product
../target/bin/seed-go-sqlite-api-static report daily-summary \
    --db-path test-data/test-workflow.db \
    --product BRK_ONP_PRD
```

## Summary

✅ Database is **NOT corrupted** - it's working perfectly  
✅ Files "disappearing" is **intentional** (Test 9 behavior)  
✅ Use `--preserve` flag to keep all processed files  
✅ Database contains correct data (verified by tests)  
