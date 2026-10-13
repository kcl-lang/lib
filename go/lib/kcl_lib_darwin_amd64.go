//go:build !no_libembed
// +build !no_libembed

package lib

import (
	_ "embed"
)

//go:embed darwin-amd64/libkcl.dylib
var CliLib []byte
