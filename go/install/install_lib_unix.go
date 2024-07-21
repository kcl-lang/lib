//go:build linux || darwin
// +build linux darwin

package install

import (
	"runtime"

	lib "kcl-lang.io/lib/go/lib"
)

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName := "lib" + libName
	switch runtime.GOOS {
	case "darwin":
		libFullName = libFullName + ".dylib"
	case "linux":
		libFullName = libFullName + ".so"
	}
	return writeLib(libDir, libFullName, lib.CliLib, versionMatched)
}
