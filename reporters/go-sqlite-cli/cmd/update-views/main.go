// Temporary utility to update views in existing database
package main

import (
"database/sql"
"fmt"
"log"
"os"

_ "github.com/mattn/go-sqlite3"
"github.com/miun-personal-shadows/seed-go-sqlite-api/internal/database"
)

func main() {
if len(os.Args) < 2 {
fmt.Println("Usage: update-views <database-path>")
os.Exit(1)
}

dbPath := os.Args[1]

db, err := sql.Open("sqlite3", dbPath)
if err != nil {
log.Fatalf("Failed to open database: %v", err)
}
defer db.Close()

fmt.Println("Updating views...")
err = database.CreateViews(db)
if err != nil {
log.Fatalf("Failed to create views: %v", err)
}

fmt.Println("Views updated successfully!")
}
