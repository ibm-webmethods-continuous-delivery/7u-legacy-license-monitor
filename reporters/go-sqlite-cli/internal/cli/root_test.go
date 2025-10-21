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

package cli

import (
	"testing"
)

func TestGetDBFile(t *testing.T) {
	tests := []struct {
		name     string
		dbFile   string
		expected string
	}{
		{
			name:     "default database file when dbFile is empty",
			dbFile:   "",
			expected: "data/default.db",
		},
		{
			name:     "custom database file",
			dbFile:   "custom.db",
			expected: "custom.db",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set the global dbFile variable
			originalDBFile := dbFile
			defer func() { dbFile = originalDBFile }()
			
			dbFile = tt.dbFile
			result := GetDBFile()
			
			if result != tt.expected {
				t.Errorf("GetDBFile() = %v, want %v", result, tt.expected)
			}
		})
	}
}
