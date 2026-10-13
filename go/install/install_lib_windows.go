//go:build windows
// +build windows

package install

import (
	"errors"

	lib "kcl-lang.io/lib/go/lib"
)

func installLib(libDir, libName string, versionMatched bool) error {
	if len(lib.CliLib) == 0 {
		return errors.New("the prebuilt libkcl binary is not vendored in this build; " +
			"run hack/download-libs.sh, or build from a release branch or tag " +
			"(see docs/lib-vendoring.md)")
	}
	libFullName := libName + ".dll"
	return writeLib(libDir, libFullName, lib.CliLib, versionMatched)
}
