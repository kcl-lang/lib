package lib

import (
	_ "embed"
)

//go:embed darwin-amd64/libkcl.dylib
var CliLib []byte
