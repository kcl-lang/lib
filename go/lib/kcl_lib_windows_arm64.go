//go:build !no_libembed
// +build !no_libembed

package lib

import (
	_ "embed"
)

//go:embed windows-arm64/kcl.dll
var CliLib []byte
