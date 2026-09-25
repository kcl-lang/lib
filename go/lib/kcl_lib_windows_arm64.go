package lib

import (
	_ "embed"
)

//go:embed windows-arm64/kcl.dll
var CliLib []byte
