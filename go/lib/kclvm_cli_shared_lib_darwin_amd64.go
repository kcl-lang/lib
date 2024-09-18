package lib

import (
	_ "embed"
)

//go:embed darwin-amd64/libkclvm_cli_cdylib.dylib
var CliLib []byte
