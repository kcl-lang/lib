package native

import (
	"os"
	"path/filepath"
	"runtime"

	"kcl-lang.io/lib/go/install"
	lazypath "kcl-lang.io/lib/go/path"
)

const libName = "kcl"

func libPath() (path string, err error) {
	return lazypath.CacheHomeWithError()
}

func fullLibName() string {
	return libObjectName(runtime.GOOS)
}

// libObjectName is the filename dlopen/LoadLibrary expects. FreeBSD shares
// the ELF name with Linux: libkcl.so. The Go loader resolves kcl_service_new
// from that file (see native_nonmusl.go); it does not look up the retired
// kclvm_service_new symbol.
func libObjectName(goos string) string {
	switch goos {
	case "darwin":
		return "lib" + libName + ".dylib"
	case "windows":
		return libName + ".dll"
	default:
		return "lib" + libName + ".so"
	}
}

func loadServiceNativeLib() (uintptr, error) {
	libPath, err := libPath()
	libPath = filepath.Join(libPath, "kcl")
	envLibHome := os.Getenv("KCL_LIB_HOME")
	if envLibHome != "" {
		libPath = envLibHome
	}
	if err != nil {
		return 0, err
	}
	err = install.InstallKcl(libPath)
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
