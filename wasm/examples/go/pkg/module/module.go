package module

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/bytecodealliance/wasmtime-go/v39"
)

type RunOptions struct {
	Filename string
	Source   string
}

type FmtOptions struct {
	Source string
}

type RunWithLogMessageOptions struct {
	Filename string
	Source   string
}

type CallOptions struct {
	// MethodName is the fully-qualified RPC name, e.g.
	// "KclService.ExecProgram".
	MethodName string
	// Args are the protobuf-encoded argument bytes for the RPC.
	Args []byte
}

type KCLModule struct {
	Instance             *wasmtime.Instance
	Store                *wasmtime.Store
	Memory               *wasmtime.Memory
	KclMalloc            *wasmtime.Func
	KclFree              *wasmtime.Func
	KclRun               *wasmtime.Func
	KclFmt               *wasmtime.Func
	KclRunWithLogMessage *wasmtime.Func
	KclVersion           *wasmtime.Func
	KclCall              *wasmtime.Func
}

func New(path string) (*KCLModule, error) {
	dir, err := os.MkdirTemp("", "out")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(dir)
	stdoutPath := filepath.Join(dir, "stdout")
	config := wasmtime.NewConfig()
	engine := wasmtime.NewEngineWithConfig(config)
	module, err := wasmtime.NewModuleFromFile(engine, path)
	if err != nil {
		return nil, err
	}
	linker := wasmtime.NewLinker(engine)
	err = linker.DefineWasi()
	linker.FuncWrap("env", "kcl_plugin_invoke_json_wasm", func(_name int32, _args int32, _kwargs int32) int32 {
		return 0
	})
	if err != nil {
		return nil, err
	}
	wasiConfig := wasmtime.NewWasiConfig()
	wasiConfig.SetStdoutFile(stdoutPath)
	store := wasmtime.NewStore(engine)
	store.SetWasi(wasiConfig)
	instance, err := linker.Instantiate(store, module)
	if err != nil {
		return nil, err
	}
	memory := instance.Exports(store)[0].Memory()
	malloc := instance.GetFunc(store, "kcl_malloc")
	free := instance.GetFunc(store, "kcl_free")
	run := instance.GetFunc(store, "kcl_run")
	fmtFn := instance.GetFunc(store, "kcl_fmt")
	runWithLogMessage := instance.GetFunc(store, "kcl_run_with_log_message")
	version := instance.GetFunc(store, "kcl_version")
	call := instance.GetFunc(store, "kcl_call")
	return &KCLModule{
		Instance:             instance,
		Store:                store,
		Memory:               memory,
		KclMalloc:            malloc,
		KclFree:              free,
		KclRun:               run,
		KclFmt:               fmtFn,
		KclRunWithLogMessage: runWithLogMessage,
		KclVersion:           version,
		KclCall:              call,
	}, nil
}

func (m *KCLModule) Run(opts *RunOptions) (string, error) {
	filenamePtr, filenameLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Filename)
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, filenamePtr, filenameLen)
		if err != nil {
			fmt.Println("Failed to free filename memory:", err)
		}
	}()

	sourcePtr, sourceLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Source)
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, sourcePtr, sourceLen)
		if err != nil {
			fmt.Println("Failed to free source memory:", err)
		}
	}()

	resultPtr, err := m.KclRun.Call(m.Store, filenamePtr, sourcePtr)
	if err != nil {
		return "", err
	}

	result, _, err := copyCStrFromWasmMemory(m.Store, m.Memory, resultPtr.(int32))
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, resultPtr.(int32), int32(len(result)))
		if err != nil {
			fmt.Println("Failed to free result memory:", err)
		}
	}()

	return result, nil
}

func (m *KCLModule) Fmt(opts *FmtOptions) (string, error) {
	sourcePtr, sourceLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Source)
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, sourcePtr, sourceLen)
		if err != nil {
			fmt.Println("Failed to free source memory:", err)
		}
	}()

	resultPtr, err := m.KclFmt.Call(m.Store, sourcePtr)
	if err != nil {
		return "", err
	}

	result, _, err := copyCStrFromWasmMemory(m.Store, m.Memory, resultPtr.(int32))
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, resultPtr.(int32), int32(len(result)))
		if err != nil {
			fmt.Println("Failed to free result memory:", err)
		}
	}()

	return result, nil
}

// RunWithLogMessage runs the KCL program like Run, but the returned string
// combines the runtime log message (if any) with the YAML result.
func (m *KCLModule) RunWithLogMessage(opts *RunWithLogMessageOptions) (string, error) {
	filenamePtr, filenameLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Filename)
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, filenamePtr, filenameLen)
		if err != nil {
			fmt.Println("Failed to free filename memory:", err)
		}
	}()

	sourcePtr, sourceLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Source)
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, sourcePtr, sourceLen)
		if err != nil {
			fmt.Println("Failed to free source memory:", err)
		}
	}()

	resultPtr, err := m.KclRunWithLogMessage.Call(m.Store, filenamePtr, sourcePtr)
	if err != nil {
		return "", err
	}

	result, _, err := copyCStrFromWasmMemory(m.Store, m.Memory, resultPtr.(int32))
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, resultPtr.(int32), int32(len(result)))
		if err != nil {
			fmt.Println("Failed to free result memory:", err)
		}
	}()

	return result, nil
}

// Version returns the KCL runtime version baked into the WASM artifact.
func (m *KCLModule) Version() (string, error) {
	resultPtr, err := m.KclVersion.Call(m.Store)
	if err != nil {
		return "", err
	}
	if resultPtr.(int32) == 0 {
		return "", nil
	}

	result, resultLen, err := copyCStrFromWasmMemory(m.Store, m.Memory, resultPtr.(int32))
	if err != nil {
		return "", err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, resultPtr.(int32), resultLen)
		if err != nil {
			fmt.Println("Failed to free result memory:", err)
		}
	}()

	return result, nil
}

// Call invokes any KCL service method by name through the universal
// dispatcher and returns the protobuf-encoded result bytes.
func (m *KCLModule) Call(opts *CallOptions) ([]byte, error) {
	namePtr, nameLen, err := copyStringToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.MethodName)
	if err != nil {
		return nil, err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, namePtr, nameLen)
		if err != nil {
			fmt.Println("Failed to free method name memory:", err)
		}
	}()

	argsPtr, argsLen, err := copyBytesToWasmMemory(m.Store, m.KclMalloc, m.Memory, opts.Args)
	if err != nil {
		return nil, err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, argsPtr, argsLen)
		if err != nil {
			fmt.Println("Failed to free args memory:", err)
		}
	}()

	resultPtr, err := m.KclCall.Call(m.Store, namePtr, nameLen, argsPtr, int32(len(opts.Args)))
	if err != nil {
		return nil, err
	}
	if resultPtr.(int32) == 0 {
		return nil, fmt.Errorf("kcl_call returned a null pointer")
	}

	result, resultLen, err := copyBytesFromWasmMemory(m.Store, m.Memory, resultPtr.(int32))
	if err != nil {
		return nil, err
	}
	defer func() {
		err := freeMemory(m.Store, m.KclFree, resultPtr.(int32), resultLen)
		if err != nil {
			fmt.Println("Failed to free result memory:", err)
		}
	}()

	return result, nil
}
