//go:build linux || darwin
// +build linux darwin

package kclvm_artifact

import (
	"runtime"
)

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName := "lib" + libName
	switch runtime.GOOS {
	case "darwin":
		libFullName = libFullName + ".dylib"
	case "linux":
		libFullName = libFullName + ".so"
	}
	return writeLib(libDir, libFullName, kclvmCliLib, versionMatched)
}
