package lib

import (
	_ "embed"
)

//go:embed linux-amd64/libkcl.so
var CliLib []byte
