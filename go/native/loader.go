package native

import (
	"os"
	"path/filepath"
	"runtime"

	"kcl-lang.io/lib/go/install"
)

const libName = "kclvm_cli_cdylib"

func libPath() (path string, err error) {
	libHome := os.Getenv("KCL_LIB_HOME")
	if libHome == "" {
		return os.MkdirTemp("", "kcl_lib_home")
	}
	return libHome, nil
}

func fullLibName() string {
	fullLibName := "lib" + libName + ".so"
	if runtime.GOOS == "darwin" {
		fullLibName = "lib" + libName + ".dylib"
	} else if runtime.GOOS == "windows" {
		fullLibName = libName + ".dll"
	}
	return fullLibName
}

func loadServiceNativeLib() (uintptr, error) {
	libPath, err := libPath()
	if err != nil {
		return 0, err
	}
	err = install.InstallKclvm(libPath)
	if err != nil {
		return 0, err
	}
	libFullPath := filepath.Join(libPath, fullLibName())
	// open the C library
	libm, err := openLibrary(libFullPath)
	if err != nil {
		return 0, err
	}
	return libm, nil
}
