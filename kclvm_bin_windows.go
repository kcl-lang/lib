package kclvm_artifact

import (
	_ "embed"
)

//go:embed scripts/kcl.exe
var kclScript []byte

//go:embed scripts/kclvm.exe
var kclvmScript []byte

//go:embed scripts/kcl-doc.exe
var kclDocScript []byte

//go:embed scripts/kcl-fmt.exe
var kclFmtScript []byte

//go:embed scripts/kcl-lint.exe
var kclLintScript []byte

//go:embed scripts/kcl-plugin.exe
var kclPluginScript []byte

//go:embed scripts/kcl-test.exe
var kclTestScript []byte

//go:embed scripts/kcl-vet.exe
var kclVetScript []byte
