package lib

import (
	_ "embed"
)

//go:embed lib/linux-arm64/libkclvm_cli_cdylib.so
var kclvmCliLib []byte

//go:embed lib/linux-arm64/kclvm_cli
var kclvmCliBin []byte
