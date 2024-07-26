//go:build windows
// +build windows

package install

import lib "kcl-lang.io/lib/go/lib"

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName := libName + ".dll"
	exportLibFullName := libName + ".lib"
	err := writeLib(libDir, libFullName, lib.CliLib, versionMatched)
	if err != nil {
		return err
	}
	return writeLib(libDir, exportLibFullName, lib.ExportLib, versionMatched)
}
