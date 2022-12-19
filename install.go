package kclvm_artifact

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

func findPath(name string) string {

	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	return ""
}

func InstallKclvm(installRoot string) error {
	installRoot, err := filepath.Abs(installRoot)
	if err != nil {
		return err
	}
	binPath := filepath.Join(installRoot, "bin")
	os.Setenv("PATH", os.Getenv("PATH")+":"+binPath)

	// Run KCL CLI to install dependencies.
	err = installBin(binPath, "kcl", kclScript, true)
	if err != nil {
		return err
	}
	err = installBin(binPath, "kclvm", kclvmScript, false)
	if err != nil {
		return err
	}

	err = installLib(binPath, "kclvm_cli_cdylib", kclvmCliLib)

	return err
}

func CleanInstall() {
	kclScript = nil
	kclvmScript = nil
	kclvmCliLib = nil
}

func installLib(libDir, libName string, content []byte) error {
	libFullName := ""
	switch runtime.GOOS {
	case "darwin":
		libFullName = "lib" + libName + ".dylib"
	case "linux":
		libFullName = "lib" + libName + ".so"
	case "windows":
		libFullName = libName + ".dll"
	}
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
func installBin(binDir, binName string, content []byte, dryRun bool) error {
	binPath := findPath(binName)
	if binPath == "" {
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

		if dryRun {
			binFile.Close()
			cmd := exec.Command(binPath)
			var errBuf bytes.Buffer
			cmd.Stderr = &errBuf
			err = cmd.Run()
			if errBuf.Len() != 0 {
				return fmt.Errorf("%s", errBuf.String())
			}
			if err != nil {
				return err
			}
		}
	}
	return nil
}
