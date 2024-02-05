package lib

func installLib(libDir, libName string, versionMatched bool) error {
	libFullName := libName + ".dll"
	exportLibFullName := libName + ".lib"
	err := writeLib(libDir, libFullName, kclvmCliLib, versionMatched)
	if err != nil {
		return err
	}
	return writeLib(libDir, exportLibFullName, kclvmExportLib, versionMatched)
}
