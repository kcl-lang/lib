package install

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"github.com/gofrs/flock"
)

const KCL_VERSION = "v0.12.1"

func getVersion() string {
	return fmt.Sprintf("%s-%s-%s", KCL_VERSION, runtime.GOOS, runtime.GOARCH)
}

func checkVersion(kclVersionDir string) (bool, error) {
	kclVersionPath := filepath.Join(kclVersionDir, "kcl.version")
	_, err := os.Stat(kclVersionPath)

	if os.IsNotExist(err) {
		err := os.MkdirAll(kclVersionDir, 0777)
		if err != nil {
			return false, err
		}
		versionFile, err := os.Create(kclVersionPath)
		defer func() {
			versionFile.Close()
		}()
		return false, err
	}
	version, err := os.ReadFile(kclVersionPath)

	if err != nil {
		return false, err
	}

	return getVersion() == string(version), nil

}

func InstallKcl(installRoot string) error {
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

	// Install kcl libs.
	err = installLib(installRoot, "kcl", versionMatched)
	if err != nil {
		return err
	}

	if !versionMatched {
		kclVersionPath := filepath.Join(installRoot, "kcl.version")
		err = os.WriteFile(kclVersionPath, []byte(getVersion()), os.FileMode(os.O_WRONLY|os.O_TRUNC))
		if err != nil {
			return err
		}
	}

	os.Setenv("PATH", os.Getenv("PATH")+string(os.PathListSeparator)+installRoot)

	return nil
}
