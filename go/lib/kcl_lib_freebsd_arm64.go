//go:build !no_libembed
// +build !no_libembed

package lib

import (
	_ "embed"
)

//go:embed freebsd-arm64/libkcl.so
var CliLib []byte
