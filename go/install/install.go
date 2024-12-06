package install

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/gofrs/flock"
)

const KCLVM_VERSION = "v0.11.0-alpha.1"

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
	err = os.MkdirAll(installRoot, 0777)
	if err != nil {
		return err
	}
	// Create a lock file for installing.
	lockFilePath := filepath.Join(installRoot, "install.lock")
	fileLock := flock.New(lockFilePath)

	// Try to obtain a lock with a timeout.
	err = fileLock.Lock()
	if err != nil {
		return err
	}
	// Ensure the lock is released when done.
	defer fileLock.Unlock()

	// Check the lib is installed.
	versionMatched, err := checkVersion(installRoot)
	if err != nil {
		return err
	}

	// Install kclvm libs.
	err = installLib(installRoot, "kclvm_cli_cdylib", versionMatched)
	if err != nil {
		return err
	}

	if !versionMatched {
		kclvmVersionPath := filepath.Join(installRoot, "kclvm.version")
		err = os.WriteFile(kclvmVersionPath, []byte(getVersion()), os.FileMode(os.O_WRONLY|os.O_TRUNC))
		if err != nil {
			return err
		}
	}

	os.Setenv("PATH", os.Getenv("PATH")+string(os.PathListSeparator)+installRoot)

	return nil
}
