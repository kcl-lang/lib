//go:build linux || darwin
// +build linux darwin

package kclvm_artifact

import (
	"runtime"
)

func installLib(libDir, libName string) error {
	libFullName := "lib" + libName
	switch runtime.GOOS {
	case "darwin":
		libFullName = libName + ".dylib"
	case "linux":
		libFullName = libName + ".so"
	}
	return writeLib(libDir, libFullName, kclvmCliLib)
}
