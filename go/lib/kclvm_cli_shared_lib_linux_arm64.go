package lib

import (
	_ "embed"
)

//go:embed linux-arm64/libkclvm_cli_cdylib.so
var CliLib []byte

//go:embed linux-arm64/kclvm_cli
var CliBin []byte
