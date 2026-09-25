package lib

import (
	_ "embed"
)

//go:embed windows-amd64/kcl.dll
var CliLib []byte
