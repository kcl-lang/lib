//go:build !musl && (darwin || freebsd || linux || windows)
// +build !musl
// +build darwin freebsd linux windows

package native

import (
	"runtime"
	"sync"

	"github.com/ebitengine/purego"
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

type NativeServiceClient struct {
	svc uintptr
}

func initClient(pluginAgent uint64) {
	libInit.Do(func() {
		var err error
		lib, err = loadServiceNativeLib()
		if err != nil {
			panic(err)
		}
		purego.RegisterLibFunc(&serviceNew, lib, "kcl_service_new")
		purego.RegisterLibFunc(&serviceDelete, lib, "kcl_service_delete")
		purego.RegisterLibFunc(&serviceCall, lib, "kcl_service_call_with_length")
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
	if x.svc != 0 {
		serviceDelete(x.svc)
		x.svc = 0
	}
	closeLibrary(lib)
	lib = 0
}
