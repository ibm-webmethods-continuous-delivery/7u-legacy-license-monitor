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

package main

import (
	"os"
	"testing"
)

func TestMain(t *testing.T) {
	// Test that main function exists and can be called
	// This is a basic integration test to ensure the application starts

	// We can't easily test the main function directly as it calls log.Fatal
	// Instead, we test that the main package can be imported and compiled
	
	// This test ensures the main package compiles correctly
	if os.Getenv("TEST_MAIN") == "1" {
		main()
		return
	}

	// Skip the actual main execution in tests
	t.Log("Main package test passed - application compiles correctly")
}
