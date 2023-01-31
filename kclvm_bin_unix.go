//go:build linux || darwin
// +build linux darwin

package kclvm_artifact

import (
	_ "embed"
)

//go:embed scripts/kcl
var kclScript []byte

//go:embed scripts/kclvm
var kclvmScript []byte

//go:embed scripts/kcl-doc
var kclDocScript []byte

//go:embed scripts/kcl-fmt
var kclFmtScript []byte

//go:embed scripts/kcl-lint
var kclLintScript []byte

//go:embed scripts/kcl-plugin
var kclPluginScript []byte

//go:embed scripts/kcl-test
var kclTestScript []byte

//go:embed scripts/kcl-vet
var kclVetScript []byte
