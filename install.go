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
	for n, script := range scripts {
		err := installBin(binPath, n, script)
		if err != nil {
			return err
		}
	}

	// Run KCL CLI to install dependencies.
	cmd := exec.Command("kcl")
	var errBuf bytes.Buffer
	cmd.Stderr = &errBuf
	err = cmd.Run()
	if errBuf.Len() != 0 {
		return fmt.Errorf("%s", errBuf.String())
	}
	if err != nil {
		return err
	}

	err = installLib(binPath, "kclvm_cli_cdylib")

	return err
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

func installBin(binDir, binName string, content []byte) error {
	binPath := findPath(binName)
	if binPath == "" {
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
