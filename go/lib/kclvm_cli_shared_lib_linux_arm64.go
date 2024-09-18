package lib

import (
	_ "embed"
)

//go:embed linux-arm64/libkclvm_cli_cdylib.so
var CliLib []byte
