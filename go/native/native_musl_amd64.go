//go:build musl && amd64
// +build musl,amd64

package native

/*
#cgo LDFLAGS: -L${SRCDIR}/../lib/linux-musl-amd64 -lkcl -static
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
			cSvc := C.KclServiceHandle(svc)
			cMethod := C.CString(method)
			defer C.free(unsafe.Pointer(cMethod))
			cArgs := C.CString(args)
			defer C.free(unsafe.Pointer(cArgs))
			cArgsLen := C.uint32_t(argsLen)
			cOutSize := (*C.uint32_t)(unsafe.Pointer(outSize))

			var cResultPtr *C.uint8_t
			cResultPtr = C.kcl_service_call_with_length(cSvc, cMethod, cArgs, cArgsLen, cOutSize)
			return uintptr(unsafe.Pointer(cResultPtr))
		}
		free = func(ptr uintptr, len uint) {
			cPtr := (*C.uint8_t)(unsafe.Pointer(ptr))
			cLen := C.uint32_t(len)
			C.kcl_free(cPtr, cLen)
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
