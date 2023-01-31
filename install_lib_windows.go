package kclvm_artifact

func installLib(libDir, libName string) error {
	libFullName := libName + ".dll"
	exportLibFullName := libName + ".lib"
	libFullPath := filepath.Join(libDir, libFullName)
	exportLibFullPath := filepath.Join(libDir, libFullName)
	err := writeLib(libDir, libFullName, kclvmCliLib)
	if err != nil {
		return err
	}
	return writeLib(libDir, exportLibFullName, kclvmExportLib)
}
