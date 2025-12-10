// Copyright The KCL Authors. All rights reserved.
//
// This file contains the Go test cases corresponding to the Python KCL API tests.

package native

import (
	"os"
	"strings"
	"testing"

	"kcl-lang.io/lib/go/api"
)

const (
	testFileSchema        = "./../test_data/schema.k"
	testFileOptionMain    = "./../test_data/option/main.k"
	testFileOverrideBak   = "./../test_data/override_file/main.bak"
	testFileOverrideMain  = "./../test_data/override_file/main.k"
	testFileFormatPath    = "./../test_data/format_path/test.k"
	testFileLintPath      = "./../test_data/lint_path/test-lint.k"
	testFileRenameMain    = "./../test_data/rename/main.k"
	testFileRenameBak     = "./../test_data/rename/main.bak"
	testFileTestingPkg    = "./../test_data/testing/..."
	testFileSettingsYaml  = "./../test_data/settings/kcl.yaml"
	testFileUpdateDep     = "./../test_data/update_dependencies"
	testFileUpdateDepMain = "./../test_data/update_dependencies/main.k"
	testWorkDir           = "./../test_data"
)

func TestExecAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ExecProgramArgs{
		KFilenameList: []string{testFileSchema},
	}

	result, err := client.ExecProgram(args)
	if err != nil {
		t.Fatalf("ExecProgram failed: %v", err)
	}

	expectedYaml := "app:\n  replicas: 2"
	if result.YamlResult != expectedYaml {
		t.Errorf("Expected YAML:\n%s\nGot:\n%s", expectedYaml, result.YamlResult)
	}
}

func TestExecAPIFailed(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ExecProgramArgs{
		KFilenameList: []string{"file_not_found"},
	}

	_, err := client.ExecProgram(args)
	if err == nil {
		t.Fatal("Expected error for non-existent file, but got nil")
	}

	if !strings.Contains(err.Error(), "Cannot find the kcl file") {
		t.Errorf("Expected error to contain 'Cannot find the kcl file', got: %v", err)
	}
}

func TestParseProgramAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ParseProgramArgs{
		Paths: []string{testFileSchema},
	}

	result, err := client.ParseProgram(args)
	if err != nil {
		t.Fatalf("ParseProgram failed: %v", err)
	}

	if len(result.Paths) != 1 {
		t.Errorf("Expected 1 path, got %d", len(result.Paths))
	}
	if len(result.Errors) != 0 {
		t.Errorf("Expected 0 parse errors, got %d", len(result.Errors))
	}
}

func TestParseFileAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ParseFileArgs{
		Path: testFileSchema,
	}

	result, err := client.ParseFile(args)
	if err != nil {
		t.Fatalf("ParseFile failed: %v", err)
	}

	if len(result.Deps) != 0 {
		t.Errorf("Expected 0 dependencies, got %d", len(result.Deps))
	}
	if len(result.Errors) != 0 {
		t.Errorf("Expected 0 parse errors, got %d", len(result.Errors))
	}
}

func TestLoadPackageAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.LoadPackageArgs{
		ParseArgs: &api.ParseProgramArgs{
			Paths: []string{testFileSchema},
		},
		ResolveAst: true,
	}

	result, err := client.LoadPackage(args)
	if err != nil {
		t.Fatalf("LoadPackage failed: %v", err)
	}

	found := false
	for _, sym := range result.Symbols {
		if sym.Ty != nil && sym.Ty.SchemaName == "AppConfig" {
			found = true
			break
		}
	}

	if !found {
		t.Error("Expected to find symbol with schema name 'AppConfig'")
	}
}

func TestListVariablesAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ListVariablesArgs{
		Files: []string{testFileSchema},
	}

	result, err := client.ListVariables(args)
	if err != nil {
		t.Fatalf("ListVariables failed: %v", err)
	}

	appVar, ok := result.Variables["app"]
	if !ok {
		t.Fatal("Expected variable 'app' not found")
	}

	if len(appVar.Variables) == 0 {
		t.Fatal("Expected at least one variable under 'app'")
	}

	expectedValue := "AppConfig {\n    replicas: 2\n}"
	if appVar.Variables[0].Value != expectedValue {
		t.Errorf("Expected value:\n%s\nGot:\n%s", expectedValue, appVar.Variables[0].Value)
	}
}

func TestListOptionsAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ParseProgramArgs{
		Paths: []string{testFileOptionMain},
	}

	result, err := client.ListOptions(args)
	if err != nil {
		t.Fatalf("ListOptions failed: %v", err)
	}

	if len(result.Options) != 3 {
		t.Errorf("Expected 3 options, got %d", len(result.Options))
	}

	expectedNames := []string{"key1", "key2", "metadata-key"}
	for i, name := range expectedNames {
		if result.Options[i].Name != name {
			t.Errorf("Option %d: expected '%s', got '%s'", i, name, result.Options[i].Name)
		}
	}
}

func TestGetSchemaTypeAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GetSchemaTypeMappingArgs{
		ExecArgs: &api.ExecProgramArgs{
			KFilenameList: []string{testFileSchema},
		},
	}

	result, err := client.GetSchemaTypeMapping(args)
	if err != nil {
		t.Fatalf("GetSchemaTypeMapping failed: %v", err)
	}

	appSchema, ok := result.SchemaTypeMapping["app"]
	if !ok {
		t.Fatal("Expected schema 'app' not found")
	}

	checkPropType := func(propName, expectedType string) {
		prop, ok := appSchema.Properties[propName]
		if !ok {
			t.Fatalf("Property '%s' not found in app schema", propName)
		}
		if prop.Type != expectedType {
			t.Errorf("Property '%s': expected type '%s', got '%s'", propName, expectedType, prop.Type)
		}
	}

	checkPropType("replicas", "int")
	checkPropType("my_func", "function")
	checkPropType("maps", "schema")

	mapsProp := appSchema.Properties["maps"]
	if mapsProp.IndexSignature == nil {
		t.Fatal("Expected index signature for 'maps'")
	}

	if *mapsProp.IndexSignature.KeyName != "name" {
		t.Errorf("Expected key name 'name', got '%s'", *mapsProp.IndexSignature.KeyName)
	}
	if mapsProp.IndexSignature.Key.Type != "str" {
		t.Errorf("Expected key type 'str', got '%s'", mapsProp.IndexSignature.Key.Type)
	}
	if mapsProp.IndexSignature.Val.Type != "schema" {
		t.Errorf("Expected value type 'schema', got '%s'", mapsProp.IndexSignature.Val.Type)
	}

	nameProp := mapsProp.IndexSignature.Val.Properties["name"]
	if nameProp.Type != "str" {
		t.Errorf("Expected 'name' type 'str', got '%s'", nameProp.Type)
	}
}

func TestOverrideFileAPI(t *testing.T) {
	client := NewNativeServiceClient()

	bakContent, err := os.ReadFile(testFileOverrideBak)
	if err != nil {
		t.Fatalf("Failed to read bak file: %v", err)
	}
	if err := os.WriteFile(testFileOverrideMain, bakContent, 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	args := &api.OverrideFileArgs{
		File:  testFileOverrideMain,
		Specs: []string{"b.a=2"},
	}

	result, err := client.OverrideFile(args)
	if err != nil {
		t.Fatalf("OverrideFile failed: %v", err)
	}

	if len(result.ParseErrors) != 0 {
		t.Errorf("Expected 0 parse errors, got %d", len(result.ParseErrors))
	}
	if !result.Result {
		t.Error("Expected override result to be true")
	}

	expectedContent := `a = 1
b = {
    "a": 2
    "b": 2
}
`
	content, err := os.ReadFile(testFileOverrideMain)
	if err != nil {
		t.Fatalf("Failed to read overridden file: %v", err)
	}

	if string(content) != expectedContent {
		t.Errorf("Expected content:\n%s\nGot:\n%s", expectedContent, string(content))
	}
}

func TestFormatCodeAPI(t *testing.T) {
	client := NewNativeServiceClient()

	sourceCode := `schema Person:
    name:   str
    age:    int

    check:
        0 <   age <   120
`
	args := &api.FormatCodeArgs{
		Source: sourceCode,
	}

	result, err := client.FormatCode(args)
	if err != nil {
		t.Fatalf("FormatCode failed: %v", err)
	}

	expectedFormatted := `schema Person:
    name: str
    age: int

    check:
        0 < age < 120

`
	if string(result.Formatted) != expectedFormatted {
		t.Errorf("Expected formatted code:\n%s\nGot:\n%s", expectedFormatted, string(result.Formatted))
	}
}

func TestLintPathAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.LintPathArgs{
		Paths: []string{testFileLintPath},
	}

	result, err := client.LintPath(args)
	if err != nil {
		t.Fatalf("LintPath failed: %v", err)
	}

	if !strings.Contains(result.Results[0], "Module 'math' imported but unused") {
		t.Errorf("Expected lint result to contain 'Module 'math' imported but unused', got: %s", result.Results)
	}
}

func TestValidateCodeAPI(t *testing.T) {
	client := NewNativeServiceClient()

	code := `schema Person:
    name: str
    age: int

    check:
        0 < age < 120
`
	data := `{"name": "Alice", "age": 10}`

	args := &api.ValidateCodeArgs{
		Code:   code,
		Data:   data,
		Format: "json",
	}

	result, err := client.ValidateCode(args)
	if err != nil {
		t.Fatalf("ValidateCode failed: %v", err)
	}

	if !result.Success {
		t.Error("Expected validation to succeed")
	}
	if result.ErrMessage != "" {
		t.Errorf("Expected empty error message, got: %s", result.ErrMessage)
	}
}

func TestRenameAPI(t *testing.T) {
	client := NewNativeServiceClient()

	bakContent, err := os.ReadFile(testFileRenameBak)
	if err != nil {
		t.Fatalf("Failed to read rename bak file: %v", err)
	}
	if err := os.WriteFile(testFileRenameMain, bakContent, 0644); err != nil {
		t.Fatalf("Failed to write rename test file: %v", err)
	}

	args := &api.RenameArgs{
		PackageRoot: "./../test_data/rename",
		SymbolPath:  "a",
		FilePaths:   []string{testFileRenameMain},
		NewName:     "a2",
	}

	_, err = client.Rename(args)
	if err != nil {
		t.Fatalf("Rename failed: %v", err)
	}
}

func TestRenameCodeAPI(t *testing.T) {
	client := NewNativeServiceClient()

	args := &api.RenameCodeArgs{
		PackageRoot: "/mock/path",
		SymbolPath:  "a",
		SourceCodes: map[string]string{
			"/mock/path/main.k": "a = 1\nb = a",
		},
		NewName: "a2",
	}

	result, err := client.RenameCode(args)
	if err != nil {
		t.Fatalf("RenameCode failed: %v", err)
	}

	expectedCode := "a2 = 1\nb = a2"
	actualCode, ok := result.ChangedCodes["/mock/path/main.k"]
	if !ok {
		t.Fatal("Expected changed code for '/mock/path/main.k'")
	}

	if actualCode != expectedCode {
		t.Errorf("Expected code:\n%s\nGot:\n%s", expectedCode, actualCode)
	}
}

func TestTestingAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.TestArgs{
		PkgList: []string{testFileTestingPkg},
	}

	result, err := client.Test(args)
	if err != nil {
		t.Fatalf("Test failed: %v", err)
	}

	if len(result.Info) != 2 {
		t.Errorf("Expected 2 info entries, got %d", len(result.Info))
	}
}

func TestLoadSettingsFilesAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.LoadSettingsFilesArgs{
		WorkDir: testWorkDir,
		Files:   []string{testFileSettingsYaml},
	}

	result, err := client.LoadSettingsFiles(args)
	if err != nil {
		t.Fatalf("LoadSettingsFiles failed: %v", err)
	}

	// 验证配置
	if len(result.KclCliConfigs.Files) != 0 {
		t.Errorf("Expected 0 files in KclCliConfigs, got %d", len(result.KclCliConfigs.Files))
	}
	if !result.KclCliConfigs.StrictRangeCheck {
		t.Error("Expected StrictRangeCheck to be true")
	}

	if len(result.KclOptions) != 1 {
		t.Errorf("Expected 1 KclOption, got %d", len(result.KclOptions))
	}
	opt := result.KclOptions[0]
	if opt.Key != "key" || opt.Value != `"value"` {
		t.Errorf("Expected option key 'key' and value '\"value\"', got key '%s' and value '%s'", opt.Key, opt.Value)
	}
}

func TestUpdateDependenciesAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.UpdateDependenciesArgs{
		ManifestPath: testFileUpdateDep,
	}

	result, err := client.UpdateDependencies(args)
	if err != nil {
		t.Fatalf("UpdateDependencies failed: %v", err)
	}

	pkgNames := make([]string, 0, len(result.ExternalPkgs))
	for _, pkg := range result.ExternalPkgs {
		pkgNames = append(pkgNames, pkg.PkgName)
	}

	if len(pkgNames) != 2 {
		t.Errorf("Expected 2 external packages, got %d", len(pkgNames))
	}
	if !strings.Contains(strings.Join(pkgNames, ","), "helloworld") {
		t.Error("Expected package 'helloworld' in external packages")
	}
	if !strings.Contains(strings.Join(pkgNames, ","), "flask") {
		t.Error("Expected package 'flask' in external packages")
	}
}

func TestExecAPIWithExternalDependencies(t *testing.T) {
	client := NewNativeServiceClient()

	updateArgs := &api.UpdateDependenciesArgs{
		ManifestPath: testFileUpdateDep,
	}
	updateResult, err := client.UpdateDependencies(updateArgs)
	if err != nil {
		t.Fatalf("UpdateDependencies failed: %v", err)
	}

	execArgs := &api.ExecProgramArgs{
		KFilenameList: []string{testFileUpdateDepMain},
		ExternalPkgs:  updateResult.ExternalPkgs,
	}
	execResult, err := client.ExecProgram(execArgs)
	if err != nil {
		t.Fatalf("ExecProgram failed: %v", err)
	}

	expectedYaml := "a: Hello World!"
	if execResult.YamlResult != expectedYaml {
		t.Errorf("Expected YAML:\n%s\nGot:\n%s", expectedYaml, execResult.YamlResult)
	}
}

func TestGetVersionAPI(t *testing.T) {
	client := NewNativeServiceClient()

	result, err := client.GetVersion(&api.GetVersionArgs{})
	if err != nil {
		t.Fatalf("GetVersion failed: %v", err)
	}

	resultStr := result.String()
	if !strings.Contains(resultStr, "Version") {
		t.Error("Expected version info to contain 'Version'")
	}
	if !strings.Contains(resultStr, "GitCommit") {
		t.Error("Expected version info to contain 'GitCommit'")
	}
}
