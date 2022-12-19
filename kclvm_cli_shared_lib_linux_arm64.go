package kclvm_artifact

import (
	_ "embed"
)

//go:embed lib/linux-arm64/libkclvm_cli_cdylib.so
var kclvmCliLib []byte
