package lib

import (
	_ "embed"
)

//go:embed darwin-arm64/libkcl.dylib
var CliLib []byte
