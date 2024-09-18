package lib

import (
	_ "embed"
)

//go:embed linux-amd64/libkclvm_cli_cdylib.so
var CliLib []byte
