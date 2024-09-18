package lib

import (
	_ "embed"
)

//go:embed darwin-arm64/libkclvm_cli_cdylib.dylib
var CliLib []byte
