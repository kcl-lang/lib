//go:build darwin || freebsd || linux
// +build darwin freebsd linux

package install

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	lib "kcl-lang.io/lib/go/lib"
)

// libFileName is the filename InstallKcl writes and the native loader
// dlopens. FreeBSD uses the same ELF name as Linux. The bytes come from
// the //go:embed in go/lib/kcl_lib_<os>_<arch>.go.
func libFileName(goos, libName string) (string, error) {
	switch goos {
	case "darwin":
		return "lib" + libName + ".dylib", nil
	case "freebsd", "linux":
		return "lib" + libName + ".so", nil
	default:
		return "", fmt.Errorf("install: no libkcl filename for GOOS %q", goos)
	}
}

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName, err := libFileName(runtime.GOOS, libName)
	if err != nil {
		return err
	}
	if len(lib.CliLib) == 0 {
		// A checkout built with -tags no_libembed, or a FreeBSD tree whose
		// libkcl.so is not vendored yet, has nothing to write. Keep a
		// library the caller already placed in the install dir (typically
		// via KCL_LIB_HOME after hack/build-freebsd-lib.sh).
		dest := filepath.Join(libDir, libFullName)
		if st, statErr := os.Stat(dest); statErr == nil && st.Size() > 0 && !st.IsDir() {
			return nil
		}
		return missingPrebuiltLib(runtime.GOOS)
	}
	return writeLib(libDir, libFullName, lib.CliLib, versionMatched)
}

func missingPrebuiltLib(goos string) error {
	if goos == "freebsd" {
		return errors.New("the prebuilt libkcl binary is not vendored in this build; " +
			"kcl-lang/kcl does not publish a FreeBSD archive yet " +
			"(https://github.com/kcl-lang/kcl/issues/1029). " +
			"Build one with hack/build-freebsd-lib.sh, or point KCL_LIB_HOME at a " +
			"directory that already contains libkcl.so (see docs/lib-vendoring.md)")
	}
	return errors.New("the prebuilt libkcl binary is not vendored in this build; " +
		"run hack/download-libs.sh, or build from a release branch or tag " +
		"(see docs/lib-vendoring.md)")
}
