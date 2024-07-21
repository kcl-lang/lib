package lib

import (
	_ "embed"
)

//go:embed windows-arm64/kclvm_cli_cdylib.dll
var CliLib []byte

//go:embed windows-amd64/kclvm_cli_cdylib.lib
var ExportLib []byte

//go:embed windows-arm64/kclvm_cli.exe
var CliBin []byte
