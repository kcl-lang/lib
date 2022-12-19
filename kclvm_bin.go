package kclvm_artifact

import (
	_ "embed"
)

//go:embed scripts/kcl
var kclScript []byte

//go:embed scripts/kclvm
var kclvmScript []byte
