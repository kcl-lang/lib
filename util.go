package kclvm_artifact

import (
	"os"
	"path/filepath"
)

func writeLib(libDir, libFullName string, content []byte) error {
	libFullPath := filepath.Join(libDir, libFullName)
	_, err := os.Stat(libFullPath)
	if err == nil {
		return nil
	}
	if os.IsNotExist(err) {
		err = os.MkdirAll(libDir, 0777)
		if err != nil {
			return err
		}
		libFile, err := os.Create(libFullPath)
		defer func() {
			libFile.Close()
		}()
		if err != nil {
			return err
		}
		_, err = libFile.Write(content)
		if err != nil {
			return err
		}
	}
	return err
}
