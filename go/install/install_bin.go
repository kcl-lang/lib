package install

import (
	"os"
	"path/filepath"
	"runtime"
)

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
