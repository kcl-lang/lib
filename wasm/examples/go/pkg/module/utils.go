package module

import "github.com/bytecodealliance/wasmtime-go/v39"

func copyStringToWasmMemory(
	store *wasmtime.Store,
	malloc *wasmtime.Func,
	memory *wasmtime.Memory,
	str string,
) (int32, int32, error) {
	bytes := []byte(str)
	length := len(bytes)
	// C str '\0'
	ptr, err := malloc.Call(store, int32(length)+1)
	if err != nil {
		return 0, 0, err
	}
	data := memory.UnsafeData(store)
	idx := ptr.(int32)
	copy(data[idx:(int(idx)+length)], bytes)
	// C str '\0'
	data[int(idx)+length] = 0
	return idx, int32(length), nil
}

func copyCStrFromWasmMemory(
	store *wasmtime.Store,
	memory *wasmtime.Memory,
	ptr int32,
) (string, int32, error) {
	data := memory.UnsafeData(store)
	end := ptr
	for data[end] != 0 {
		end++
	}
	result := string(data[ptr:end])
	return result, end + 1 - ptr, nil
}

// copyBytesToWasmMemory copies raw bytes into wasm memory followed by a NUL
// terminator (the allocation is one byte larger than the content). The
// returned length is the allocation length, suitable for kcl_free.
func copyBytesToWasmMemory(
	store *wasmtime.Store,
	malloc *wasmtime.Func,
	memory *wasmtime.Memory,
	content []byte,
) (int32, int32, error) {
	length := len(content)
	ptr, err := malloc.Call(store, int32(length)+1)
	if err != nil {
		return 0, 0, err
	}
	idx := ptr.(int32)
	data := memory.UnsafeData(store)
	copy(data[idx:(int(idx)+length)], content)
	data[int(idx)+length] = 0
	return idx, int32(length) + 1, nil
}

// copyBytesFromWasmMemory reads a NUL-terminated byte string from wasm
// memory. The returned length includes the NUL terminator, suitable for
// kcl_free.
func copyBytesFromWasmMemory(
	store *wasmtime.Store,
	memory *wasmtime.Memory,
	ptr int32,
) ([]byte, int32, error) {
	data := memory.UnsafeData(store)
	end := ptr
	for data[end] != 0 {
		end++
	}
	result := make([]byte, end-ptr)
	copy(result, data[ptr:end])
	return result, end + 1 - ptr, nil
}

func freeMemory(
	store *wasmtime.Store,
	free *wasmtime.Func,
	ptr int32,
	length int32,
) error {
	_, err := free.Call(store, ptr, length)
	return err
}
