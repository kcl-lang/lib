//go:build windows
// +build windows

package native

import "syscall"

func openLibrary(name string) (uintptr, error) {
	// Use [syscall.LoadLibrary] here to avoid external dependencies (#270).
	// For actual use cases, [golang.org/x/sys/windows.NewLazySystemDLL] is recommended.
	handle, err := syscall.LoadLibrary(name)
	return uintptr(handle), err
}

func closeLibrary(handle uintptr) error {
	return syscall.Close(syscall.Handle(handle))
}
