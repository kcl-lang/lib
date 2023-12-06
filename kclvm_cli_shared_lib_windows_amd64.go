package lib

import (
	_ "embed"
)

//go:embed lib/windows-amd64/kclvm_cli_cdylib.dll
var kclvmCliLib []byte

//go:embed lib/windows-amd64/kclvm_cli_cdylib.lib
var kclvmExportLib []byte

//go:embed lib/windows-amd64/kclvm_cli.exe
var kclvmCliBin []byte
