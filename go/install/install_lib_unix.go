//go:build linux || darwin
// +build linux darwin

package install

import (
	"errors"
	"runtime"

	lib "kcl-lang.io/lib/go/lib"
)

func installLib(libDir, libName string, versionMatched bool) error {
	if len(lib.CliLib) == 0 {
		return errors.New("the prebuilt libkcl binary is not vendored in this build; " +
			"run hack/download-libs.sh, or build from a release branch or tag " +
			"(see docs/lib-vendoring.md)")
	}
	libFullName := "lib" + libName
	switch runtime.GOOS {
	case "darwin":
		libFullName = libFullName + ".dylib"
	case "linux":
		libFullName = libFullName + ".so"
	}
	return writeLib(libDir, libFullName, lib.CliLib, versionMatched)
}
