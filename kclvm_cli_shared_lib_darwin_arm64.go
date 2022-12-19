package kclvm_artifact

import (
	_ "embed"
)

//go:embed lib/darwin-arm64/libkclvm_cli_cdylib.dylib
var kclvmCliLib []byte
