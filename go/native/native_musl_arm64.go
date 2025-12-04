//go:build musl && arm64
// +build musl,arm64

package native

/*
#cgo LDFLAGS: -L${SRCDIR}/../lib/linux-musl-arm64 -lkcl -static
#include <stdlib.h>
#include "../include/kcl.h"
*/
import "C"
import (
	"runtime"
	"sync"
	"unsafe"

	"kcl-lang.io/lib/go/api"
	"kcl-lang.io/lib/go/plugin"
)

var libInit sync.Once

var (
	client        *NativeServiceClient
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
		serviceNew = func(agent uint64) uintptr {
			return uintptr(C.kcl_service_new(C.uint64_t(agent)))
		}
		serviceDelete = func(svc uintptr) {
			C.kcl_service_delete(C.uintptr_t(svc))
		}
		serviceCall = func(svc uintptr, method, args string, argsLen uint, outSize *uint) uintptr {
			cSvc := C.uintptr_t(svc)
			cMethod := C.CString(method)
			defer C.free(unsafe.Pointer(cMethod))
			cArgs := C.CString(args)
			defer C.free(unsafe.Pointer(cArgs))
			cArgsLen := C.uint(argsLen)
			cOutSize := (*C.uint)(unsafe.Pointer(outSize))
			return uintptr(C.kcl_service_call_with_length(cSvc, cMethod, cArgs, cArgsLen, cOutSize))
		}
		free = func(ptr uintptr, len uint) {
			C.kcl_free(C.uintptr_t(ptr), C.uint(len))
		}
		client = &NativeServiceClient{
			svc: serviceNew(pluginAgent),
		}
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
}
