package kclvm_artifact

import (
	_ "embed"
)

//go:embed lib/windows-arm64/kclvm_cli_cdylib.dll
var kclvmCliLib []byte
