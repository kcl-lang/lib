package native

import (
	"bytes"
	"errors"
	"runtime"
	"strings"
	"sync"
	"unsafe"

	"github.com/ebitengine/purego"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
	"kcl-lang.io/lib/go/api"
	"kcl-lang.io/lib/go/plugin"
)

var libInit sync.Once

var (
	client        *NativeServiceClient
	lib           uintptr
	serviceNew    func(uint64) uintptr
	serviceDelete func(uintptr)
	serviceCall   func(uintptr, string, string, uint, *uint) uintptr
	free          func(uintptr, uint)
)

type validator interface {
	Validate() error
}

type NativeServiceClient struct {
	svc uintptr
}

func initClient(pluginAgent uint64) {
	libInit.Do(func() {
		lib, _ = loadServiceNativeLib()
		purego.RegisterLibFunc(&serviceNew, lib, "kclvm_service_new")
		purego.RegisterLibFunc(&serviceDelete, lib, "kclvm_service_delete")
		purego.RegisterLibFunc(&serviceCall, lib, "kclvm_service_call_with_length")
		purego.RegisterLibFunc(&free, lib, "kcl_free")
		client = new(NativeServiceClient)
		client.svc = serviceNew(pluginAgent)
		runtime.SetFinalizer(client, func(x *NativeServiceClient) {
			if x != nil {
				x.Close()
			}
		})
	})
}

func NewNativeServiceClient() api.ServiceClient {
	return NewNativeServiceClientWithPluginAgent(plugin.GetInvokeJsonProxyPtr())
}

func NewNativeServiceClientWithPluginAgent(pluginAgent uint64) *NativeServiceClient {
	initClient(pluginAgent)
	return client
}

func (x *NativeServiceClient) Close() {
	serviceDelete(x.svc)
	closeLibrary(lib)
}

func cApiCall[I interface {
	*TI
	proto.Message
}, O interface {
	*TO
	protoreflect.ProtoMessage
}, TI any, TO any](c *NativeServiceClient, callName string, in I) (O, error) {
	if callName == "" {
		return nil, errors.New("kclvm service c api call: empty method name")
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

func (c *NativeServiceClient) Ping(in *api.Ping_Args) (*api.Ping_Result, error) {
	return cApiCall[*api.Ping_Args, *api.Ping_Result](c, "KclvmService.Ping", in)
}

func (c *NativeServiceClient) ExecProgram(in *api.ExecProgram_Args) (*api.ExecProgram_Result, error) {
	return cApiCall[*api.ExecProgram_Args, *api.ExecProgram_Result](c, "KclvmService.ExecProgram", in)
}

// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.11.0.
func (c *NativeServiceClient) BuildProgram(in *api.BuildProgram_Args) (*api.BuildProgram_Result, error) {
	return cApiCall[*api.BuildProgram_Args, *api.BuildProgram_Result](c, "KclvmService.BuildProgram", in)
}

// Depreciated: Please use the env.EnableFastEvalMode() and c.ExecutProgram method and will be removed in v0.11.0.
func (c *NativeServiceClient) ExecArtifact(in *api.ExecArtifact_Args) (*api.ExecProgram_Result, error) {
	return cApiCall[*api.ExecArtifact_Args, *api.ExecProgram_Result](c, "KclvmService.ExecArtifact", in)
}

func (c *NativeServiceClient) ParseFile(in *api.ParseFile_Args) (*api.ParseFile_Result, error) {
	return cApiCall[*api.ParseFile_Args, *api.ParseFile_Result](c, "KclvmService.ParseFile", in)
}

func (c *NativeServiceClient) ParseProgram(in *api.ParseProgram_Args) (*api.ParseProgram_Result, error) {
	return cApiCall[*api.ParseProgram_Args, *api.ParseProgram_Result](c, "KclvmService.ParseProgram", in)
}

func (c *NativeServiceClient) ListOptions(in *api.ParseProgram_Args) (*api.ListOptions_Result, error) {
	return cApiCall[*api.ParseProgram_Args, *api.ListOptions_Result](c, "KclvmService.ListOptions", in)
}

func (c *NativeServiceClient) ListVariables(in *api.ListVariables_Args) (*api.ListVariables_Result, error) {
	return cApiCall[*api.ListVariables_Args, *api.ListVariables_Result](c, "KclvmService.ListVariables", in)
}

func (c *NativeServiceClient) LoadPackage(in *api.LoadPackage_Args) (*api.LoadPackage_Result, error) {
	return cApiCall[*api.LoadPackage_Args, *api.LoadPackage_Result](c, "KclvmService.LoadPackage", in)
}

func (c *NativeServiceClient) FormatCode(in *api.FormatCode_Args) (*api.FormatCode_Result, error) {
	return cApiCall[*api.FormatCode_Args, *api.FormatCode_Result](c, "KclvmService.FormatCode", in)
}

func (c *NativeServiceClient) FormatPath(in *api.FormatPath_Args) (*api.FormatPath_Result, error) {
	return cApiCall[*api.FormatPath_Args, *api.FormatPath_Result](c, "KclvmService.FormatPath", in)
}

func (c *NativeServiceClient) LintPath(in *api.LintPath_Args) (*api.LintPath_Result, error) {
	return cApiCall[*api.LintPath_Args, *api.LintPath_Result](c, "KclvmService.LintPath", in)
}

func (c *NativeServiceClient) OverrideFile(in *api.OverrideFile_Args) (*api.OverrideFile_Result, error) {
	return cApiCall[*api.OverrideFile_Args, *api.OverrideFile_Result](c, "KclvmService.OverrideFile", in)
}

func (c *NativeServiceClient) GetSchemaTypeMapping(in *api.GetSchemaTypeMapping_Args) (*api.GetSchemaTypeMapping_Result, error) {
	return cApiCall[*api.GetSchemaTypeMapping_Args, *api.GetSchemaTypeMapping_Result](c, "KclvmService.GetSchemaTypeMapping", in)
}

func (c *NativeServiceClient) ValidateCode(in *api.ValidateCode_Args) (*api.ValidateCode_Result, error) {
	return cApiCall[*api.ValidateCode_Args, *api.ValidateCode_Result](c, "KclvmService.ValidateCode", in)
}

func (c *NativeServiceClient) ListDepFiles(in *api.ListDepFiles_Args) (*api.ListDepFiles_Result, error) {
	return cApiCall[*api.ListDepFiles_Args, *api.ListDepFiles_Result](c, "KclvmService.ListDepFiles", in)
}

func (c *NativeServiceClient) LoadSettingsFiles(in *api.LoadSettingsFiles_Args) (*api.LoadSettingsFiles_Result, error) {
	return cApiCall[*api.LoadSettingsFiles_Args, *api.LoadSettingsFiles_Result](c, "KclvmService.LoadSettingsFiles", in)
}

func (c *NativeServiceClient) Rename(in *api.Rename_Args) (*api.Rename_Result, error) {
	return cApiCall[*api.Rename_Args, *api.Rename_Result](c, "KclvmService.Rename", in)
}

func (c *NativeServiceClient) RenameCode(in *api.RenameCode_Args) (*api.RenameCode_Result, error) {
	return cApiCall[*api.RenameCode_Args, *api.RenameCode_Result](c, "KclvmService.RenameCode", in)
}

func (c *NativeServiceClient) Test(in *api.Test_Args) (*api.Test_Result, error) {
	return cApiCall[*api.Test_Args, *api.Test_Result](c, "KclvmService.Test", in)
}

func (c *NativeServiceClient) UpdateDependencies(in *api.UpdateDependencies_Args) (*api.UpdateDependencies_Result, error) {
	return cApiCall[*api.UpdateDependencies_Args, *api.UpdateDependencies_Result](c, "KclvmService.UpdateDependencies", in)
}

func (c *NativeServiceClient) GetVersion(in *api.GetVersion_Args) (*api.GetVersion_Result, error) {
	return cApiCall[*api.GetVersion_Args, *api.GetVersion_Result](c, "KclvmService.GetVersion", in)
}
