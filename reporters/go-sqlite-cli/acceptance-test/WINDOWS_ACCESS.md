# Accessing SQLite Database from Windows

## The Problem

**SQLiteman on Windows cannot open SQLite databases over network shares** (like DevContainer mounts) due to:
- File locking issues (SQLite requires proper fcntl() locks)
- Network file systems don't support SQLite's locking mechanism
- Concurrent access issues

## Solutions

### Solution 1: Export Database to Windows (RECOMMENDED)

Copy the database to a Windows-accessible location:

**Method A: Using VSCode Terminal**
```bash
# Copy to workspace root (accessible from Windows)
cp test-data/test-workflow.db ../../../test-workflow-export.db
```

Then open in SQLiteman:
```
\\wsl$\docker-desktop\mnt\docker-desktop-disk\data\workspace\7u-legacy-license-monitor\test-workflow-export.db
```

Or simpler - just drag & drop from VSCode Explorer to Windows desktop!

**Method B: Export via Script**
```bash
# Create export directory in workspace root
mkdir -p /workspaces/7u-legacy-license-monitor/db-exports
cp test-data/test-workflow.db /workspaces/7u-legacy-license-monitor/db-exports/
```

Browse to the file in VSCode Explorer, right-click → "Reveal in File Explorer"

### Solution 2: Use Read-Only Mode in SQLiteman

Some SQLite clients work better with read-only access over network:

1. In SQLiteman, open with **Read-Only** flag
2. Or open the database copy (see Solution 1)

### Solution 3: Use SQLite Browser (Better Alternative)

**DB Browser for SQLite** handles network files better than SQLiteman:
- Download: https://sqlitebrowser.org/
- More modern, actively maintained
- Better handling of locked files

### Solution 4: Use VSCode SQLite Extension

Install SQLite extension in VSCode:
1. Press `Ctrl+Shift+X`
2. Search for "SQLite" (by alexcvzz)
3. Install the extension
4. Right-click database file → "Open Database"

This works directly in DevContainer without file transfer!

### Solution 5: Export to CSV/JSON for Inspection

Use our CLI tool to export data:

```bash
cd reporters/go-sqlite-cli/acceptance-test

# Export to CSV
../target/bin/iwldr-static report daily-summary \
    --db-path test-data/test-workflow.db \
    --format csv \
    --output /workspaces/7u-legacy-license-monitor/daily-summary.csv

# Export to JSON
../target/bin/iwldr-static report daily-summary \
    --db-path test-data/test-workflow.db \
    --format json \
    --output /workspaces/7u-legacy-license-monitor/daily-summary.json
```

Then open CSV in Excel or JSON in any text editor.

## Quick Export Command

Add this to your workflow:

```bash
# Run test with preserve mode
./test_folder_workflow.sh --preserve

# Copy database to workspace root for Windows access
cp test-data/test-workflow.db /workspaces/7u-legacy-license-monitor/test-workflow.db

# Now open from Windows:
# Navigate to your workspace folder
# File will be: 7u-legacy-license-monitor\test-workflow.db
```

## Why This Happens

SQLite databases require:
- **Local filesystem** (not network shares)
- **Proper file locking** (fcntl on Linux, LockFileEx on Windows)
- **No concurrent access** over network

DevContainer files are accessed via:
- Docker volume mounts
- Network file sharing protocols
- Windows → WSL → Docker layers

This creates locking conflicts for SQLite!

## Recommended Workflow

1. **Run tests in DevContainer:**
   ```bash
   ./test_folder_workflow.sh --preserve
   ```

2. **Export for Windows inspection:**
   ```bash
   cp test-data/test-workflow.db /workspaces/7u-legacy-license-monitor/exported.db
   ```

3. **Open in SQLiteman/DB Browser:**
   - Use VSCode Explorer to find `exported.db`
   - Right-click → "Reveal in File Explorer"
   - Open with your SQLite tool

4. **Or use VSCode Extension:**
   - Install SQLite extension in VSCode
   - Works directly on test-data/test-workflow.db
   - No export needed!

## Testing the Fix

Try these in order:

```bash
# 1. Create export
cd /workspaces/7u-legacy-license-monitor/reporters/go-sqlite-cli/acceptance-test
cp test-data/test-workflow.db ../../../exported-for-windows.db

# 2. Verify it's readable
sqlite3 ../../../exported-for-windows.db "PRAGMA integrity_check;"

# 3. Check it's in workspace root
ls -lh ../../../exported-for-windows.db
```

Now navigate to your workspace in Windows Explorer and open `exported-for-windows.db`

## Alternative: Use Our CLI Reports

Instead of opening in SQLiteman, use our built-in reports:

```bash
# Beautiful table output
../target/bin/iwldr-static report daily-summary \
    --db-path test-data/test-workflow.db

# Export everything to CSV for Excel
../target/bin/iwldr-static report daily-summary \
    --db-path test-data/test-workflow.db \
    --format csv \
    --output /workspaces/7u-legacy-license-monitor/report.csv
```

Then open `report.csv` in Excel!
