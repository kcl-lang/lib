//go:build linux || darwin
// +build linux darwin

package install

import (
	"fmt"
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

		for pass := 0; ; pass++ {
			tmpFullPath := fmt.Sprintf("%s~%d", binPath, pass)
			tmpFile, err := os.OpenFile(tmpFullPath, os.O_CREATE|os.O_RDWR|os.O_EXCL, 0755)
			if err != nil {
				if os.IsExist(err) {
					continue
				}
				return err
			}
			defer func() {
				tmpFile.Close()
				_ = os.Remove(tmpFullPath)
			}()

			if _, err = tmpFile.Write(content); err != nil {
				return err
			}
			if err := os.Rename(tmpFullPath, binPath); err != nil {
				return err
			}
			fileMode := os.FileMode(0777)
			os.Chmod(binPath, fileMode)
			break
		}
	}
	return nil
}
