//go:build !no_libembed
// +build !no_libembed

package lib

import (
	_ "embed"
)

//go:embed darwin-arm64/libkcl.dylib
var CliLib []byte
