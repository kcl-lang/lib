//go:build !no_libembed
// +build !no_libembed

package lib

import (
	_ "embed"
)

//go:embed windows-amd64/kcl.dll
var CliLib []byte
