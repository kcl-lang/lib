package kclvm_artifact

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

const KCLVM_VERSION = "v0.7.0"

func findPath(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	return ""
}

func getVersion() string {
	return fmt.Sprintf("%s-%s-%s", KCLVM_VERSION, runtime.GOOS, runtime.GOARCH)
}

func checkVersion(kclvmVersionDir string) (bool, error) {
	kclvmVersionPath := filepath.Join(kclvmVersionDir, "kclvm.version")
	_, err := os.Stat(kclvmVersionPath)

	if os.IsNotExist(err) {
		err := os.MkdirAll(kclvmVersionDir, 0777)
		if err != nil {
			return false, err
		}
		versionFile, err := os.Create(kclvmVersionPath)
		defer func() {
			versionFile.Close()
		}()
		return false, err
	}
	version, err := os.ReadFile(kclvmVersionPath)

	if err != nil {
		return false, err
	}

	return getVersion() == string(version), nil

}

func InstallKclvm(installRoot string) error {
	installRoot, err := filepath.Abs(installRoot)
	if err != nil {
		return err
	}
	binPath := filepath.Join(installRoot, "bin")

	versionMatched, err := checkVersion(binPath)

	if err != nil {
		return err
	}

	// Install kclvm binary.
	err = installBin(binPath, "kclvm_cli", kclvmCliBin, versionMatched)
	if err != nil {
		return err
	}
	// Install kclvm libs.
	err = installLib(binPath, "kclvm_cli_cdylib", versionMatched)
	if err != nil {
		return err
	}

	if !versionMatched {
		kclvmVersionPath := filepath.Join(binPath, "kclvm.version")
		err = os.WriteFile(kclvmVersionPath, []byte(getVersion()), os.FileMode(os.O_WRONLY|os.O_TRUNC))
		if err != nil {
			return err
		}
	}

	os.Setenv("PATH", os.Getenv("PATH")+string(os.PathListSeparator)+binPath)

	return nil
}

func InstallKclvmPy(installRoot string) error {
	installRoot, err := filepath.Abs(installRoot)
	if err != nil {
		return err
	}
	binPath := filepath.Join(installRoot, "bin")

	kclvmVersionPath := filepath.Join(binPath, "kclvm.version")

	versionMatched, err := checkVersion(kclvmVersionPath)

	if err != nil {
		return err
	}

	os.Setenv("PATH", os.Getenv("PATH")+string(os.PathListSeparator)+binPath)

	scripts := map[string][]byte{
		"kcl":        kclScript,
		"kclvm":      kclvmScript,
		"kcl-doc":    kclDocScript,
		"kcl-fmt":    kclFmtScript,
		"kcl-lint":   kclLintScript,
		"kcl-plugin": kclPluginScript,
		"kcl-test":   kclTestScript,
		"kcl-vet":    kclVetScript,
	}
	// Install binaries.
	for n, script := range scripts {
		err := installBin(binPath, n, script, versionMatched)
		if err != nil {
			return err
		}
	}
	// Install kclvm libs.
	err = installLib(binPath, "kclvm_cli_cdylib", versionMatched)
	if err != nil {
		return err
	}

	if !versionMatched {
		err = os.WriteFile(kclvmVersionPath, []byte(getVersion()), os.FileMode(os.O_WRONLY|os.O_TRUNC))
		if err != nil {
			return err
		}

	}

	os.Setenv("PATH", os.Getenv("PATH")+string(os.PathListSeparator)+binPath)
	return nil
}

func CleanInstall() {
	kclScript = nil
	kclvmScript = nil
	kclDocScript = nil
	kclFmtScript = nil
	kclLintScript = nil
	kclPluginScript = nil
	kclTestScript = nil
	kclVetScript = nil
	kclvmCliLib = nil
}

func installBin(binDir, binName string, content []byte, versionMatched bool) error {
	binPath := findPath(binName)
	if binPath == "" || !versionMatched {
		if runtime.GOOS == "windows" {
			binName += ".exe"
		}
		binPath = filepath.Join(binDir, binName)
		err := os.MkdirAll(binDir, 0777)
		if err != nil {
			return err
		}
		binFile, err := os.Create(binPath)
		defer func() {
			binFile.Close()
		}()
		if err != nil {
			return err
		}
		_, err = binFile.Write(content)
		if err != nil {
			return err
		}
		fileMode := os.FileMode(0777)
		os.Chmod(binPath, fileMode)
	}
	return nil
}
