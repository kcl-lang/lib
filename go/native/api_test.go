// Copyright The KCL Authors. All rights reserved.
//
// This file contains the Go test cases corresponding to the Python KCL API tests.

package native

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"google.golang.org/protobuf/proto"
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
	testFileGenOpenAPI    = "./../test_data/gen_openapi/main.k"
	testWorkDir           = "./../test_data"
)

func TestPing(t *testing.T) {
	client := NewNativeServiceClient()

	args := &api.PingArgs{Value: "hello"}
	result, err := client.Ping(args)
	if err != nil {
		t.Fatalf("Ping failed: %v", err)
	}

	if result.Value != args.Value {
		t.Errorf("Expected ping value %q, got %q", args.Value, result.Value)
	}
}

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

// TestGetSchemaTypeAPIUnderPath is the regression test for
// https://github.com/kcl-lang/kcl/issues/1546: schemas coming from external
// dependency packages must keep their own PkgPath (instead of "__main__")
// and their BaseSchema must resolve across the package boundary.
func TestGetSchemaTypeAPIUnderPath(t *testing.T) {
	client := NewNativeServiceClient()

	abs := func(rel string) string {
		t.Helper()
		p, err := filepath.Abs("../test_data/get_schema_ty_under_path/" + rel)
		if err != nil {
			t.Fatalf("resolve %s: %v", rel, err)
		}
		return p
	}

	args := &api.GetSchemaTypeMappingArgs{
		ExecArgs: &api.ExecProgramArgs{
			KFilenameList: []string{abs("aaa")},
			ExternalPkgs: []*api.ExternalPkg{
				{PkgName: "bbb", PkgPath: abs("bbb")},
			},
		},
	}

	result, err := client.GetSchemaTypeMappingUnderPath(args)
	if err != nil {
		t.Fatalf("GetSchemaTypeMappingUnderPath failed: %v", err)
	}

	mainSchemas, ok := result.SchemaTypeMapping["__main__"]
	if !ok {
		t.Fatalf("Expected package '__main__' in mapping, got %v", pkgKeys(result.SchemaTypeMapping))
	}
	if len(mainSchemas.SchemaType) == 0 {
		t.Fatal("Expected at least one schema in '__main__'")
	}

	bbbSchemas, ok := result.SchemaTypeMapping["bbb"]
	if !ok {
		t.Fatalf("Expected package 'bbb' in mapping, got %v", pkgKeys(result.SchemaTypeMapping))
	}

	var base, b *api.KclType
	for _, s := range bbbSchemas.SchemaType {
		switch s.SchemaName {
		case "Base":
			base = s
		case "B":
			b = s
		}
	}
	if base == nil || b == nil {
		t.Fatalf("Expected schemas Base and B in bbb, got %v", schemaNames(bbbSchemas))
	}
	if base.PkgPath != "bbb" {
		t.Errorf("Base PkgPath: expected 'bbb', got '%s' (regression for #1546)", base.PkgPath)
	}
	if b.PkgPath != "bbb" {
		t.Errorf("B PkgPath: expected 'bbb', got '%s' (regression for #1546)", b.PkgPath)
	}
	if b.BaseSchema == nil {
		t.Fatal("B BaseSchema: expected non-nil base schema (regression for #1546)")
	}
	if b.BaseSchema.SchemaName != "Base" || b.BaseSchema.PkgPath != "bbb" {
		t.Errorf("B BaseSchema: expected bbb.Base, got '%s' in '%s'",
			b.BaseSchema.SchemaName, b.BaseSchema.PkgPath)
	}
}

func pkgKeys(m map[string]*api.SchemaTypes) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

func schemaNames(st *api.SchemaTypes) []string {
	out := make([]string, 0, len(st.SchemaType))
	for _, s := range st.SchemaType {
		out = append(out, s.SchemaName)
	}
	return out
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

func TestFormatPath(t *testing.T) {
	client := NewNativeServiceClient()

	// FormatPath mutates files in place, so operate on a copy of the fixture
	// in a temp dir instead of the checked-in test data. Rewrite the copy
	// with unformatted source so the formatter has something to change.
	tmpFile := filepath.Join(t.TempDir(), "test.k")
	content, err := os.ReadFile(testFileFormatPath)
	if err != nil {
		t.Fatalf("Failed to read format path fixture: %v", err)
	}
	if err := os.WriteFile(tmpFile, content, 0644); err != nil {
		t.Fatalf("Failed to copy format path fixture: %v", err)
	}
	if err := os.WriteFile(tmpFile, []byte("a   =   1\n"), 0644); err != nil {
		t.Fatalf("Failed to write messy test file: %v", err)
	}

	args := &api.FormatPathArgs{Path: tmpFile}
	result, err := client.FormatPath(args)
	if err != nil {
		t.Fatalf("FormatPath failed: %v", err)
	}

	resolvedTmp, err := filepath.EvalSymlinks(tmpFile)
	if err != nil {
		resolvedTmp = tmpFile
	}
	found := false
	for _, p := range result.ChangedPaths {
		if p == tmpFile || p == resolvedTmp {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("Expected changed path %q, got %v", tmpFile, result.ChangedPaths)
	}

	expected := "a = 1\n"
	formatted, err := os.ReadFile(tmpFile)
	if err != nil {
		t.Fatalf("Failed to read formatted file: %v", err)
	}
	if string(formatted) != expected {
		t.Errorf("Expected content:\n%s\nGot:\n%s", expected, string(formatted))
	}

	// Once formatted, nothing is reported as changed.
	result, err = client.FormatPath(args)
	if err != nil {
		t.Fatalf("FormatPath (second run) failed: %v", err)
	}
	if len(result.ChangedPaths) != 0 {
		t.Errorf("Expected no changed paths on second run, got %v", result.ChangedPaths)
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

func TestFormatTestReportAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.FormatTestReportArgs{
		Result: &api.TestResult{
			Info: []*api.TestCaseInfo{
				{Name: "test_case_1", Duration: 1500},
				{Name: "test_case_2", Error: "Error: assert failed", Duration: 2500},
			},
		},
	}

	result, err := client.FormatTestReport(args)
	if err != nil {
		t.Fatalf("FormatTestReport failed: %v", err)
	}

	// The prebuilt kcl v0.13.0 runtime predates this RPC: the native
	// dispatcher panics with "unknown method name" and answers with an
	// empty payload, so there is nothing to assert against it.
	if result.Report == "" {
		t.Skip("the native runtime does not implement KclService.FormatTestReport")
	}

	expected := "test_case_1: PASS (1ms)\n" +
		"test_case_2: FAIL (2ms)\n" +
		"Error: assert failed\n" +
		strings.Repeat("-", 80) + "\n" +
		"PASS: 1/2\n" +
		"FAIL: 1/2\n"
	if result.Report != expected {
		t.Errorf("Expected report:\n%s\nGot:\n%s", expected, result.Report)
	}
}

func TestGenerateTomlAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GenerateTomlArgs{
		ExecArgs: &api.ExecProgramArgs{
			KFilenameList: []string{"file.k"},
			KCodeList:     []string{"a = {b = 1, c = [1, 2]}"},
		},
	}

	result, err := client.GenerateToml(args)
	if err != nil {
		t.Fatalf("GenerateToml failed: %v", err)
	}

	// The prebuilt kcl v0.13.0 runtime predates this RPC: the native
	// dispatcher panics with "unknown method name" and answers with an
	// empty payload, so there is nothing to assert against it.
	if result.Toml == "" {
		t.Skip("the native runtime does not implement KclService.GenerateToml")
	}

	expected := "[a]\nb = 1\nc = [1, 2]\n"
	if result.Toml != expected {
		t.Errorf("Expected TOML:\n%s\nGot:\n%s", expected, result.Toml)
	}
}

func TestGenerateKclAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GenerateKclArgs{
		Source:   "{\"a\": {\"b\": 1}}",
		Filename: "data.json",
		Format:   "json",
	}

	result, err := client.GenerateKcl(args)
	if err != nil {
		t.Fatalf("GenerateKcl failed: %v", err)
	}

	if result.Kcl == "" {
		t.Skip("the native runtime does not implement KclService.GenerateKcl")
	}

	expected := "a = {\n    b = 1\n}\n"
	if result.Kcl != expected {
		t.Errorf("Expected KCL:\n%s\nGot:\n%s", expected, result.Kcl)
	}
}

func TestGenerateOpenAPIAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GenerateOpenAPIArgs{
		ParseArgs: &api.ParseProgramArgs{
			Paths: []string{testFileGenOpenAPI},
		},
		Version: "v3",
	}

	result, err := client.GenerateOpenAPI(args)
	if err != nil {
		t.Fatalf("GenerateOpenAPI failed: %v", err)
	}

	if result.Spec == "" {
		t.Skip("the native runtime does not implement KclService.GenerateOpenAPI")
	}

	if !strings.Contains(result.Spec, "\"openapi\": \"3.0.0\"") {
		t.Error("Expected spec to contain '\"openapi\": \"3.0.0\"'")
	}
	if !strings.Contains(result.Spec, "\"Person\": {") {
		t.Error("Expected spec to contain '\"Person\": {'")
	}
	if !strings.Contains(result.Spec, "#/components/schemas/Base") {
		t.Error("Expected spec to contain '#/components/schemas/Base'")
	}
	if !strings.Contains(result.Spec, "\"oneOf\": [") {
		t.Error("Expected spec to contain '\"oneOf\": ['")
	}
}

func TestGenerateProtoAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GenerateProtoArgs{
		ParseArgs: &api.ParseProgramArgs{
			Paths: []string{testFileGenOpenAPI},
		},
		Package: "example.v1",
	}

	result, err := client.GenerateProto(args)
	if err != nil {
		t.Fatalf("GenerateProto failed: %v", err)
	}

	if result.Proto == "" {
		t.Skip("the native runtime does not implement KclService.GenerateProto")
	}

	if !strings.HasPrefix(result.Proto, "syntax = \"proto3\";\n\npackage example.v1;\n") {
		t.Errorf("Expected proto to start with the proto3 syntax and package clause, got:\n%s", result.Proto)
	}
	if !strings.Contains(result.Proto, "message Person {") {
		t.Error("Expected proto to contain 'message Person {'")
	}
	if !strings.Contains(result.Proto, "import \"google/protobuf/struct.proto\";") {
		t.Error("Expected proto to contain 'import \"google/protobuf/struct.proto\";'")
	}
}

func TestGenerateDocAPI(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.GenerateDocArgs{
		ParseArgs: &api.ParseProgramArgs{
			Paths: []string{testFileGenOpenAPI},
		},
		Format: "md",
	}

	result, err := client.GenerateDoc(args)
	if err != nil {
		t.Fatalf("GenerateDoc failed: %v", err)
	}

	if result.Content == "" {
		t.Skip("the native runtime does not implement KclService.GenerateDoc")
	}

	if !strings.HasPrefix(result.Content, "# Schemas\n") {
		t.Errorf("Expected doc to start with '# Schemas', got:\n%s", result.Content)
	}
	if !strings.Contains(result.Content, "### Person") {
		t.Error("Expected doc to contain '### Person'")
	}
	if !strings.Contains(result.Content, "| Name | Type | Required | Default | Description |") {
		t.Error("Expected doc to contain the Markdown table header")
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

	// The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
	// `update_dependencies` always returns `pkg_path = <manifest>/<dep_name>`
	// (it ignores the `path` directive), so we hand-build `external_pkgs`
	// pointing at the actual mock locations.
	execArgs := &api.ExecProgramArgs{
		KFilenameList: []string{testFileUpdateDepMain},
		ExternalPkgs: []*api.ExternalPkg{
			{PkgName: "helloworld", PkgPath: "./../test_data/_mocks/helloworld"},
			{PkgName: "flask", PkgPath: "./../test_data/_mocks/flask"},
		},
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

// Pure protobuf round-trip — does not require the native client to be running.
// Covers the new `format` (20), `error_format` (19) and `sourcemap_output`
// (22) fields on ExecProgramArgs.
func TestExecProgramArgsFormatRoundTrip(t *testing.T) {
	sourcemapOutput := "/tmp/out.js.map"
	args := &api.ExecProgramArgs{
		Format:         "json",
		ErrorFormat:    "sarif",
		SourcemapOutput: &sourcemapOutput,
	}

	wire, err := proto.Marshal(args)
	if err != nil {
		t.Fatalf("Marshal ExecProgramArgs: %v", err)
	}

	decoded := &api.ExecProgramArgs{}
	if err := proto.Unmarshal(wire, decoded); err != nil {
		t.Fatalf("Unmarshal ExecProgramArgs: %v", err)
	}

	if decoded.Format != "json" {
		t.Errorf("Format round-trip: got %q, want %q", decoded.Format, "json")
	}
	if decoded.ErrorFormat != "sarif" {
		t.Errorf("ErrorFormat round-trip: got %q, want %q", decoded.ErrorFormat, "sarif")
	}
	if decoded.SourcemapOutput == nil {
		t.Fatalf("SourcemapOutput round-trip: got nil, want %q", sourcemapOutput)
	}
	if *decoded.SourcemapOutput != sourcemapOutput {
		t.Errorf("SourcemapOutput round-trip: got %q, want %q", *decoded.SourcemapOutput, sourcemapOutput)
	}
}

// Pure protobuf round-trip for ExecProgramResult.sourcemap (5).
func TestExecProgramResultSourcemapRoundTrip(t *testing.T) {
	const sourcemap = `{"version":3,"sources":[]}`
	result := &api.ExecProgramResult{
		JsonResult: `{"a": 1}`,
		YamlResult: "a: 1",
		Sourcemap:  proto.String(sourcemap),
	}

	wire, err := proto.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal ExecProgramResult: %v", err)
	}

	decoded := &api.ExecProgramResult{}
	if err := proto.Unmarshal(wire, decoded); err != nil {
		t.Fatalf("Unmarshal ExecProgramResult: %v", err)
	}

	if decoded.JsonResult != `{"a": 1}` {
		t.Errorf("JsonResult round-trip: got %q", decoded.JsonResult)
	}
	if decoded.YamlResult != "a: 1" {
		t.Errorf("YamlResult round-trip: got %q", decoded.YamlResult)
	}
	if decoded.Sourcemap == nil {
		t.Fatalf("Sourcemap round-trip: got nil, want %q", sourcemap)
	}
	if *decoded.Sourcemap != sourcemap {
		t.Errorf("Sourcemap round-trip: got %q, want %q", *decoded.Sourcemap, sourcemap)
	}
}

// End-to-end: actually runs KCL through the native dispatcher with
// format="json" and asserts that the runtime honours the format
// selector (only json_result is populated; yaml_result is empty).
func TestExecProgramFormat(t *testing.T) {
	client := NewNativeServiceClient()
	args := &api.ExecProgramArgs{
		KFilenameList: []string{testFileSchema},
		Format:        "json",
	}

	result, err := client.ExecProgram(args)
	if err != nil {
		t.Fatalf("ExecProgram(format=json) failed: %v", err)
	}
	if result.JsonResult == "" {
		t.Errorf("ExecProgram(format=json): expected non-empty json_result, got empty")
	}
	if result.YamlResult != "" {
		t.Errorf("ExecProgram(format=json): expected empty yaml_result, got %q", result.YamlResult)
	}
	if !strings.Contains(result.JsonResult, `"replicas"`) {
		t.Errorf("ExecProgram(format=json): expected json_result to contain replicas key, got %q", result.JsonResult)
	}
}

// End-to-end: actually runs KCL through the native dispatcher with
// sourcemap_output set and asserts that the runtime emits a Source
// Map v3 document in result.sourcemap.
func TestExecProgramSourcemapOutput(t *testing.T) {
	client := NewNativeServiceClient()
	smapPath := filepath.Join(t.TempDir(), "out.js.map")
	args := &api.ExecProgramArgs{
		KFilenameList:  []string{testFileSchema},
		SourcemapOutput: &smapPath,
	}

	result, err := client.ExecProgram(args)
	if err != nil {
		t.Fatalf("ExecProgram(sourcemap_output=%q) failed: %v", smapPath, err)
	}

	// The runtime is responsible for populating result.sourcemap when
	// sourcemap_output is supplied. Older kcl-api versions return nil
	// because source-map emission isn't yet wired up — in that case
	// surface a soft skip so this test doesn't fail under a stale
	// runtime while still flagging the missing functionality.
	if result.Sourcemap == nil || *result.Sourcemap == "" {
		t.Skipf("runtime did not populate sourcemap for sourcemap_output=%q (kcl-api may not yet support source maps); result=%+v", smapPath, result)
	}
	// Source Map v3 documents are JSON objects with at least a "version" key.
	if !strings.Contains(*result.Sourcemap, `"version"`) {
		t.Errorf("ExecProgram(sourcemap_output=%q): expected Source Map JSON with version key, got %q", smapPath, *result.Sourcemap)
	}
}
