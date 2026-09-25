//go:build windows
// +build windows

package install

import lib "kcl-lang.io/lib/go/lib"

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName := libName + ".dll"
	return writeLib(libDir, libFullName, lib.CliLib, versionMatched)
}
