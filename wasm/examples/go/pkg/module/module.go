package module

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/bytecodealliance/wasmtime-go/v22"
)

type RunOptions struct {
	Filename string
	Source   string
}

type FmtOptions struct {
	Source string
}

type KCLModule struct {
	Instance  *wasmtime.Instance
	Store     *wasmtime.Store
	Memory    *wasmtime.Memory
	KclMalloc *wasmtime.Func
	KclFree   *wasmtime.Func
	KclRun    *wasmtime.Func
	KclFmt    *wasmtime.Func
}

func New(path string) (*KCLModule, error) {
	dir, err := os.MkdirTemp("", "out")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(dir)
	stdoutPath := filepath.Join(dir, "stdout")
	engine := wasmtime.NewEngine()
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
	fmt := instance.GetFunc(store, "kcl_fmt")
	return &KCLModule{
		Instance:  instance,
		Store:     store,
		Memory:    memory,
		KclMalloc: malloc,
		KclFree:   free,
		KclRun:    run,
		KclFmt:    fmt,
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
