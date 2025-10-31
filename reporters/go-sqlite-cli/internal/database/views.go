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

import (
	_ "embed"
)

//go:embed sql/views.sql
var ViewsSQL string

// CreateViews creates all reporting views
func CreateViews(db interface{ Exec(query string, args ...interface{}) (interface{}, error) }) error {
	_, err := db.Exec(ViewsSQL)
	return err
}
