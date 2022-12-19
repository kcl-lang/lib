package kclvm_artifact

import (
	_ "embed"
)

//go:embed lib/linux-amd64/libkclvm_cli_cdylib.so
var kclvmCliLib []byte
