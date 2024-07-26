//go:build !windows && cgo
// +build !windows,cgo

package native

// #cgo CFLAGS:-I${SRCDIR}/../include
// #cgo !windows LDFLAGS:-lkclvm_cli_cdylib -lm -ldl -pthread
// #cgo windows LDFLAGS:-lkclvm_cli_cdylib -lmsvcrt -luserenv -lole32 -lntdll -lws2_32 -lkernel32 -lbcrypt
// #cgo linux,amd64 LDFLAGS:-L${SRCDIR}/../lib/linux-amd64 -Wl,-rpath,${SRCDIR}/../lib/linux-amd64
// #cgo linux,arm64 LDFLAGS:-L${SRCDIR}/../lib/linux-arm64 -Wl,-rpath,${SRCDIR}/../lib/linux-arm64
// #cgo darwin,amd64 LDFLAGS:-L${SRCDIR}/../lib/darwin-amd64 -Wl,-rpath,${SRCDIR}/../lib/darwin-amd64
// #cgo darwin,arm64 LDFLAGS:-L${SRCDIR}/../lib/darwin-arm64 -Wl,-rpath,${SRCDIR}/../lib/darwin-arm64
// #cgo windows,amd64 LDFLAGS:-L${SRCDIR}/../lib/windows-amd64 -Wl,-rpath,${SRCDIR}/../lib/windows-amd64
// #include <kclvm_cli_cdylib.h>
import "C"

// NewKclvmService takes a pluginAgent and returns a pointer of capi kclvm_service.
// pluginAgent is the address of C function pointer with type :const char * (*)(const char *method,const char *args,const char *kwargs),
// in which "method" is the fully qualified name of plugin method,
// and "args" ,"kwargs"  and return value of pluginAgent are JSON string
func NewKclvmService(pluginAgent C.uint64_t) *C.kclvm_service {
	return C.kclvm_service_new(pluginAgent)
}

// NewKclvmService releases the memory of kclvm_service
func DeleteKclvmService(serv *C.kclvm_service) {
	C.kclvm_service_delete(serv)
}

// KclvmServiceFreeString releases the memory of  the return value of KclvmServiceCall
func KclvmServiceFreeString(str *C.char) {
	C.kclvm_service_free_string(str)
}

// KclvmServiceCall calls kclvm service by c api
// args should be serialized as protobuf byte stream
func KclvmServiceCall(serv *C.kclvm_service, method *C.char, args *C.char, args_len C.size_t) (*C.char, C.size_t) {
	var size C.size_t = 0
	buf := C.kclvm_service_call_with_length(serv, method, args, args_len, &size)
	return buf, size
}
