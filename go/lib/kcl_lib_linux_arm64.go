package lib

import (
	_ "embed"
)

//go:embed linux-arm64/libkcl.so
var CliLib []byte
