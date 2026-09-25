package native

import (
	"bytes"
	"errors"
	"strings"
	"unsafe"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
	"kcl-lang.io/lib/go/api"
)

type validator interface {
	Validate() error
}

func cApiCall[I interface {
	*TI
	proto.Message
}, O interface {
	*TO
	protoreflect.ProtoMessage
}, TI any, TO any](c *NativeServiceClient, callName string, in I) (O, error) {
	if callName == "" {
		return nil, errors.New("kcl service c api call: empty method name")
	}

	if in == nil {
		in = new(TI)
	}

	if x, ok := proto.Message(in).(validator); ok {
		if err := x.Validate(); err != nil {
			return nil, err
		}
	}
	inBytes, err := proto.Marshal(in)
	if err != nil {
		return nil, err
	}
	var cOutSize uint
	cOut := serviceCall(c.svc, callName, string(inBytes), uint(len(inBytes)), &cOutSize)

	msg := GoBytes(cOut, cOutSize)

	// The bytes is allocated from the C API, thus we free it when copied it to Go bytes.
	defer free(cOut, cOutSize)

	if bytes.HasPrefix(msg, []byte("ERROR:")) {
		return nil, errors.New(strings.TrimPrefix(string(msg), "ERROR:"))
	}

	var out O = new(TO)
	err = proto.Unmarshal(msg, out)
	if err != nil {
		return nil, errors.New(string(msg))
	}

	return out, nil
}

// GoBytes copies a uintptr with length to go []byte
func GoBytes(c uintptr, length uint) []byte {
	// We take the address and then dereference it to trick go vet from creating a possible misuse of unsafe.Pointer
	ptr := *(*unsafe.Pointer)(unsafe.Pointer(&c))
	if ptr == nil {
		return []byte{}
	}
	return unsafe.Slice((*byte)(ptr), length)
}

func (c *NativeServiceClient) Ping(in *api.PingArgs) (*api.PingResult, error) {
	return cApiCall[*api.PingArgs, *api.PingResult](c, "KclService.Ping", in)
}

func (c *NativeServiceClient) ExecProgram(in *api.ExecProgramArgs) (*api.ExecProgramResult, error) {
	return cApiCall[*api.ExecProgramArgs, *api.ExecProgramResult](c, "KclService.ExecProgram", in)
}

func (c *NativeServiceClient) ParseFile(in *api.ParseFileArgs) (*api.ParseFileResult, error) {
	return cApiCall[*api.ParseFileArgs, *api.ParseFileResult](c, "KclService.ParseFile", in)
}

func (c *NativeServiceClient) ParseProgram(in *api.ParseProgramArgs) (*api.ParseProgramResult, error) {
	return cApiCall[*api.ParseProgramArgs, *api.ParseProgramResult](c, "KclService.ParseProgram", in)
}

func (c *NativeServiceClient) ListOptions(in *api.ParseProgramArgs) (*api.ListOptionsResult, error) {
	return cApiCall[*api.ParseProgramArgs, *api.ListOptionsResult](c, "KclService.ListOptions", in)
}

func (c *NativeServiceClient) ListVariables(in *api.ListVariablesArgs) (*api.ListVariablesResult, error) {
	return cApiCall[*api.ListVariablesArgs, *api.ListVariablesResult](c, "KclService.ListVariables", in)
}

func (c *NativeServiceClient) LoadPackage(in *api.LoadPackageArgs) (*api.LoadPackageResult, error) {
	return cApiCall[*api.LoadPackageArgs, *api.LoadPackageResult](c, "KclService.LoadPackage", in)
}

func (c *NativeServiceClient) FormatCode(in *api.FormatCodeArgs) (*api.FormatCodeResult, error) {
	return cApiCall[*api.FormatCodeArgs, *api.FormatCodeResult](c, "KclService.FormatCode", in)
}

func (c *NativeServiceClient) FormatPath(in *api.FormatPathArgs) (*api.FormatPathResult, error) {
	return cApiCall[*api.FormatPathArgs, *api.FormatPathResult](c, "KclService.FormatPath", in)
}

func (c *NativeServiceClient) LintPath(in *api.LintPathArgs) (*api.LintPathResult, error) {
	return cApiCall[*api.LintPathArgs, *api.LintPathResult](c, "KclService.LintPath", in)
}

func (c *NativeServiceClient) OverrideFile(in *api.OverrideFileArgs) (*api.OverrideFileResult, error) {
	return cApiCall[*api.OverrideFileArgs, *api.OverrideFileResult](c, "KclService.OverrideFile", in)
}

func (c *NativeServiceClient) GetSchemaTypeMapping(in *api.GetSchemaTypeMappingArgs) (*api.GetSchemaTypeMappingResult, error) {
	return cApiCall[*api.GetSchemaTypeMappingArgs, *api.GetSchemaTypeMappingResult](c, "KclService.GetSchemaTypeMapping", in)
}

// GetSchemaTypeMappingUnderPath returns the schema type mapping defined in the
// program rooted at the input paths and all of their external dependency
// packages. The returned map is keyed by package name (e.g. "__main__",
// "bbb"), each value holding the schema list for that package with correct
// pkgpath / base fields — fixes https://github.com/kcl-lang/kcl/issues/1546.
func (c *NativeServiceClient) GetSchemaTypeMappingUnderPath(in *api.GetSchemaTypeMappingArgs) (*api.GetSchemaTypeMappingUnderPathResult, error) {
	return cApiCall[*api.GetSchemaTypeMappingArgs, *api.GetSchemaTypeMappingUnderPathResult](c, "KclService.GetSchemaTypeMappingUnderPath", in)
}

func (c *NativeServiceClient) ValidateCode(in *api.ValidateCodeArgs) (*api.ValidateCodeResult, error) {
	return cApiCall[*api.ValidateCodeArgs, *api.ValidateCodeResult](c, "KclService.ValidateCode", in)
}

func (c *NativeServiceClient) LoadSettingsFiles(in *api.LoadSettingsFilesArgs) (*api.LoadSettingsFilesResult, error) {
	return cApiCall[*api.LoadSettingsFilesArgs, *api.LoadSettingsFilesResult](c, "KclService.LoadSettingsFiles", in)
}

func (c *NativeServiceClient) Rename(in *api.RenameArgs) (*api.RenameResult, error) {
	return cApiCall[*api.RenameArgs, *api.RenameResult](c, "KclService.Rename", in)
}

func (c *NativeServiceClient) RenameCode(in *api.RenameCodeArgs) (*api.RenameCodeResult, error) {
	return cApiCall[*api.RenameCodeArgs, *api.RenameCodeResult](c, "KclService.RenameCode", in)
}

func (c *NativeServiceClient) Test(in *api.TestArgs) (*api.TestResult, error) {
	return cApiCall[*api.TestArgs, *api.TestResult](c, "KclService.Test", in)
}

func (c *NativeServiceClient) UpdateDependencies(in *api.UpdateDependenciesArgs) (*api.UpdateDependenciesResult, error) {
	return cApiCall[*api.UpdateDependenciesArgs, *api.UpdateDependenciesResult](c, "KclService.UpdateDependencies", in)
}

func (c *NativeServiceClient) GetVersion(in *api.GetVersionArgs) (*api.GetVersionResult, error) {
	return cApiCall[*api.GetVersionArgs, *api.GetVersionResult](c, "KclService.GetVersion", in)
}

// ListMethod returns the list of KCL service method names available in the
// underlying native runtime. It is dispatched against the BuiltinService so
// callers can enumerate the supported RPC surface (e.g. for tooling and
// documentation generators) without hard-coding names client-side.
func (c *NativeServiceClient) ListMethod(in *api.ListMethodArgs) (*api.ListMethodResult, error) {
	return cApiCall[*api.ListMethodArgs, *api.ListMethodResult](c, "BuiltinService.ListMethod", in)
}
