//go:build linux || darwin
// +build linux darwin

package lib

import (
	"fmt"
	"os"
	"path/filepath"
)

func writeLib(libDir, libFullName string, content []byte, versionMatched bool) error {
	libFullPath := filepath.Join(libDir, libFullName)
	_, err := os.Stat(libFullPath)
	if !os.IsNotExist(err) && versionMatched {
		return err
	}
	if err := os.MkdirAll(libDir, 0777); err != nil {
		return err
	}
	for pass := 0; ; pass++ {
		tmpFullPath := fmt.Sprintf("%s~%d", libFullPath, pass)
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
		if err := os.Rename(tmpFullPath, libFullPath); err != nil {
			return err
		}
		break
	}
	return nil
}
